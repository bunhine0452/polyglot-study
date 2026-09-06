import Foundation
import LLMKit
import OpenRouterKit
import TestSupport
import Testing

/// 진짜 소켓 위 왕복.
///
/// 스텁 전송은 ``HTTPTransport`` 위쪽만 본다. 여기서는 `URLSession` 이 실제로 연결을
/// 열고, 우리가 조립한 헤더가 전선을 그대로 타고, HTTP 프레이밍으로 돌아온 상태 코드와
/// `retry-after` 가 재시도 루프를 움직이는지를 확인한다.
///
/// **실제 OpenRouter 엔드포인트 왕복은 아니다.** 실왕복은 크레딧을 쓰므로 한 번만
/// 태우고, 반복 검증(재시도·백오프·연결 거부)은 계속 여기서 한다.
@Suite("루프백 HTTP 왕복", .serialized)
struct LoopbackRoundTripTests {
    private func makeProvider(
        baseURL: URL,
        sleeper: any Sleeper = RecordingSleeper(),
        log: any ClientLogSink = DiscardLog()
    ) throws -> OpenRouterProvider {
        OpenRouterProvider(
            apiKey: try APIKey(rawValue: Fixtures.fakeAPIKeyString),
            model: ModelID(Fixtures.testModel),
            configuration: .init(
                baseURL: baseURL,
                retry: RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(10), jitterFraction: 0),
                requestTimeout: .seconds(10),
                sessionID: "loopback-suite"
            ),
            transport: URLSessionTransport(timeout: .seconds(10)),
            sleeper: sleeper,
            jitter: { 0.5 },
            log: log
        )
    }

    private var structuredRequest: CompletionRequest {
        CompletionRequest(
            system: [PromptSegment(text: "고정 시스템", cacheHint: .default)],
            messages: [.user("안녕")],
            maxOutputTokens: 1000,
            responseFormat: .jsonSchema(name: "probe", schema: ["type": "object"]),
            reasoningEffort: .low
        )
    }

    @Test("URLSession 으로 왕복 1회가 성공하고 헤더가 전선에 그대로 실린다")
    func realRoundTrip() async throws {
        let server = LoopbackHTTPServer(replies: [
            .init(status: 200, body: Fixtures.chatCompletionJSON(text: "루프백 결과"))
        ])
        try server.start()
        defer { server.stop() }

        let provider = try makeProvider(baseURL: server.baseURL)
        let response = try await provider.complete(structuredRequest)

        #expect(response.text == "루프백 결과")
        #expect(response.usage.inputTokens == 1234)
        #expect(response.upstreamProvider == "TestUpstream")

        let received = try #require(server.requests.first)
        #expect(received.method == "POST")
        #expect(received.path == "/chat/completions")
        #expect(received.headers["authorization"] == "Bearer \(Fixtures.fakeAPIKeyString)")
        #expect(received.headers["content-type"] == "application/json")
        #expect(received.headers["x-openrouter-title"] == "Polyglot Study lessongen")
        #expect(received.headers["http-referer"] != nil)

        let body = try #require(try JSONSerialization.jsonObject(with: received.body) as? [String: Any])
        #expect(body["model"] as? String == Fixtures.testModel)
        #expect(body["max_tokens"] as? Int == 1000)
        #expect(body["session_id"] as? String == "loopback-suite")
        // 라우팅 좁히기가 진짜 전선에도 실린다.
        #expect((body["provider"] as? [String: Any])?["require_parameters"] as? Bool == true)
        #expect((body["response_format"] as? [String: Any])?["type"] as? String == "json_schema")
    }

    @Test("진짜 429 → 503 → 200 을 지수 백오프로 넘긴다")
    func retriesOverRealHTTP() async throws {
        let server = LoopbackHTTPServer(replies: [
            .init(
                status: 429,
                headers: ["retry-after": "2"],
                body: Fixtures.errorJSON(code: 429, message: "느려")
            ),
            .init(status: 503, body: Fixtures.errorJSON(code: 503, message: "가용 업스트림 없음")),
            .init(status: 200, body: Fixtures.chatCompletionJSON(text: "세 번째에 성공")),
        ])
        try server.start()
        defer { server.stop() }

        let sleeper = RecordingSleeper()
        let log = CapturingLog()
        let provider = try makeProvider(baseURL: server.baseURL, sleeper: sleeper, log: log)

        let response = try await provider.complete(structuredRequest)

        #expect(response.text == "세 번째에 성공")
        #expect(server.requests.count == 3)
        // 429 는 서버가 준 retry-after 를, 503 은 지수 백오프(baseDelay 10ms × 2)를 따랐다.
        #expect(sleeper.durations == [.seconds(2), .milliseconds(20)])
        // 진짜 왕복에서 나온 로그에도 키는 없다.
        #expect(!log.joined.contains(Fixtures.fakeAPIKeyString))
        #expect(!log.joined.contains("sk-or-"))
    }

    /// 상태 코드는 200 인데 본문이 오류인 경로를 **진짜 HTTP 프레이밍으로** 태운다.
    /// 스텁으로는 이 조합이 진짜 소켓에서도 같은지 알 수 없다.
    @Test("진짜 200 응답 안의 오류도 재시도 루프를 움직인다")
    func inlineErrorOverRealHTTP() async throws {
        let server = LoopbackHTTPServer(replies: [
            .init(status: 200, body: Fixtures.inlineErrorJSON(code: 502, message: "업스트림 끊김")),
            .init(status: 200, body: Fixtures.chatCompletionJSON(text: "두 번째에 성공")),
        ])
        try server.start()
        defer { server.stop() }

        let provider = try makeProvider(baseURL: server.baseURL)
        let response = try await provider.complete(structuredRequest)
        #expect(response.text == "두 번째에 성공")
        #expect(server.requests.count == 2)
    }

    @Test("연결을 못 하면 전송 오류로 떨어진다")
    func connectionRefused() async throws {
        // 포트를 잡았다 바로 닫아 확실히 비어 있는 포트를 얻는다.
        let server = LoopbackHTTPServer(replies: [])
        try server.start()
        let deadURL = server.baseURL
        server.stop()

        let provider = try makeProvider(baseURL: deadURL)
        await #expect(throws: LLMError.self) {
            try await provider.complete(CompletionRequest(messages: [.user("x")], maxOutputTokens: 10))
        }
    }
}
