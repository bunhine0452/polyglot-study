import AnthropicKit
import Foundation
import TestSupport
import Testing

/// 진짜 소켓 위 왕복.
///
/// 스텁 전송은 ``HTTPTransport`` 위쪽만 본다. 여기서는 `URLSession` 이 실제로 연결을
/// 열고, 우리가 조립한 헤더가 전선을 그대로 타고, HTTP 프레이밍으로 돌아온 상태 코드와
/// `retry-after` 가 재시도 루프를 움직이는지를 확인한다.
///
/// **실제 Anthropic 엔드포인트 왕복은 아니다** — 이 환경에 `ANTHROPIC_API_KEY` 가 없다.
@Suite("루프백 HTTP 왕복", .serialized)
struct LoopbackRoundTripTests {
    private func makeClient(
        baseURL: URL,
        sleeper: any Sleeper = RecordingSleeper(),
        log: any ClientLogSink = DiscardLog()
    ) throws -> AnthropicClient {
        try AnthropicClient(
            apiKey: APIKey(rawValue: Fixtures.fakeAPIKeyString),
            configuration: .init(
                baseURL: baseURL,
                retry: RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(10), jitterFraction: 0),
                requestTimeout: .seconds(10)
            ),
            transport: URLSessionTransport(timeout: .seconds(10)),
            sleeper: sleeper,
            jitter: { 0.5 },
            log: log
        )
    }

    @Test("URLSession 으로 왕복 1회가 성공하고 헤더가 전선에 그대로 실린다")
    func realRoundTrip() async throws {
        let server = LoopbackHTTPServer(replies: [
            .init(status: 200, body: Fixtures.messagesResponseJSON(text: "루프백 결과"))
        ])
        try server.start()
        defer { server.stop() }

        let client = try makeClient(baseURL: server.baseURL)
        let response = try await client.send(
            MessagesRequest(model: .opus5, maxTokens: 1000, messages: [.user("안녕")])
        )

        #expect(response.text == "루프백 결과")
        #expect(response.usage.inputTokens == 1234)

        let received = try #require(server.requests.first)
        #expect(received.method == "POST")
        #expect(received.path == "/v1/messages")
        #expect(received.headers["x-api-key"] == Fixtures.fakeAPIKeyString)
        #expect(received.headers["anthropic-version"] == "2023-06-01")
        #expect(received.headers["content-type"] == "application/json")
        #expect(received.headers["anthropic-beta"] == "server-side-fallback-2026-07-01")

        let body = try #require(try JSONSerialization.jsonObject(with: received.body) as? [String: Any])
        #expect(body["model"] as? String == "claude-opus-5")
        #expect(body["max_tokens"] as? Int == 1000)
    }

    @Test("진짜 429 → 529 → 200 을 지수 백오프로 넘긴다")
    func retriesOverRealHTTP() async throws {
        let server = LoopbackHTTPServer(replies: [
            .init(
                status: 429,
                headers: ["retry-after": "2"],
                body: Fixtures.errorJSON(type: "rate_limit_error", message: "느려")
            ),
            .init(status: 529, body: Fixtures.errorJSON(type: "overloaded_error", message: "과부하")),
            .init(status: 200, body: Fixtures.messagesResponseJSON(text: "세 번째에 성공")),
        ])
        try server.start()
        defer { server.stop() }

        let sleeper = RecordingSleeper()
        let log = CapturingLog()
        let client = try makeClient(baseURL: server.baseURL, sleeper: sleeper, log: log)

        let response = try await client.send(
            MessagesRequest(model: .opus5, maxTokens: 1000, messages: [.user("안녕")])
        )

        #expect(response.text == "세 번째에 성공")
        #expect(server.requests.count == 3)
        // 429 는 서버가 준 retry-after 를, 529 는 지수 백오프(baseDelay 10ms × 2)를 따랐다.
        #expect(sleeper.durations == [.seconds(2), .milliseconds(20)])
        // 진짜 왕복에서 나온 로그에도 키는 없다.
        #expect(!log.joined.contains(Fixtures.fakeAPIKeyString))
        #expect(!log.joined.contains("sk-ant-"))
    }

    @Test("연결을 못 하면 전송 오류로 떨어진다")
    func connectionRefused() async throws {
        // 포트를 잡았다 바로 닫아 확실히 비어 있는 포트를 얻는다.
        let server = LoopbackHTTPServer(replies: [])
        try server.start()
        let deadURL = server.baseURL
        server.stop()

        let client = try makeClient(baseURL: deadURL)
        await #expect(throws: AnthropicError.self) {
            try await client.send(MessagesRequest(model: .opus5, maxTokens: 10, messages: [.user("x")]))
        }
    }
}
