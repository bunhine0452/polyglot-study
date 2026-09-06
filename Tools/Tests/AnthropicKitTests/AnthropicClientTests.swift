import AnthropicKit
import Foundation
import TestSupport
import Testing

@Suite("클라이언트 왕복과 재시도")
struct AnthropicClientTests {
    private func makeKey() throws -> APIKey {
        try APIKey(rawValue: Fixtures.fakeAPIKeyString)
    }

    private var request: MessagesRequest {
        MessagesRequest(model: .opus5, maxTokens: 1000, messages: [.user("안녕")])
    }

    private func makeClient(
        transport: any HTTPTransport,
        sleeper: any Sleeper = RecordingSleeper(),
        log: any ClientLogSink = DiscardLog(),
        retry: RetryPolicy = RetryPolicy(baseDelay: .milliseconds(500), jitterFraction: 0)
    ) throws -> AnthropicClient {
        try AnthropicClient(
            apiKey: makeKey(),
            configuration: .init(retry: retry),
            transport: transport,
            sleeper: sleeper,
            jitter: { 0.5 },
            log: log
        )
    }

    @Test("한 번에 성공하면 한 번만 호출한다")
    func singleRoundTrip() async throws {
        let transport = StubTransport(status: 200, body: Fixtures.messagesResponseJSON(text: "결과"))
        let client = try makeClient(transport: transport)
        let response = try await client.send(request)
        #expect(response.text == "결과")
        #expect(transport.requests.count == 1)
    }

    @Test("429 뒤에 성공하면 지수 백오프로 한 번 기다렸다 다시 건다")
    func retriesOnRateLimit() async throws {
        let transport = StubTransport([
            .response(
                HTTPResponse(
                    status: 429,
                    headers: ["Retry-After": "3"],
                    body: Fixtures.errorJSON(type: "rate_limit_error", message: "느려")
                )
            ),
            .response(HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: "결과"))),
        ])
        let sleeper = RecordingSleeper()
        let client = try makeClient(transport: transport, sleeper: sleeper)

        let response = try await client.send(request)
        #expect(response.text == "결과")
        #expect(transport.requests.count == 2)
        // retry-after 를 그대로 따랐다.
        #expect(sleeper.durations == [.seconds(3)])
    }

    @Test("529 는 재시도하고 지연이 2배씩 늘어난다")
    func retriesOnOverloaded() async throws {
        let overloaded = HTTPResponse(
            status: 529,
            body: Fixtures.errorJSON(type: "overloaded_error", message: "과부하")
        )
        let transport = StubTransport([
            .response(overloaded),
            .response(overloaded),
            .response(HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: "결과"))),
        ])
        let sleeper = RecordingSleeper()
        let client = try makeClient(transport: transport, sleeper: sleeper)

        _ = try await client.send(request)
        #expect(transport.requests.count == 3)
        #expect(sleeper.durations == [.milliseconds(500), .seconds(1)])
    }

    @Test("전송 오류도 재시도 대상이다")
    func retriesOnTransportFailure() async throws {
        let transport = StubTransport([
            .failure(.transport("연결이 끊겼습니다")),
            .response(HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: "결과"))),
        ])
        let client = try makeClient(transport: transport)
        _ = try await client.send(request)
        #expect(transport.requests.count == 2)
    }

    @Test("400 은 즉시 포기한다 — 다시 걸어도 같은 결과다")
    func doesNotRetryBadRequest() async throws {
        let transport = StubTransport(
            status: 400,
            body: Fixtures.errorJSON(type: "invalid_request_error", message: "max_tokens 누락")
        )
        let sleeper = RecordingSleeper()
        let client = try makeClient(transport: transport, sleeper: sleeper)

        await #expect(throws: AnthropicError.self) { try await client.send(request) }
        #expect(transport.requests.count == 1)
        #expect(sleeper.durations.isEmpty)
    }

    @Test("재시도를 다 쓰면 retriesExhausted 로 끝나고 마지막 오류를 물고 있다")
    func exhaustsRetries() async throws {
        let overloaded = HTTPResponse(
            status: 529,
            body: Fixtures.errorJSON(type: "overloaded_error", message: "과부하")
        )
        let transport = StubTransport([
            .response(overloaded), .response(overloaded), .response(overloaded),
        ])
        let client = try makeClient(
            transport: transport,
            retry: RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(10), jitterFraction: 0)
        )

        do {
            _ = try await client.send(request)
            Issue.record("던졌어야 합니다.")
        } catch let error as AnthropicError {
            guard case .retriesExhausted(let attempts, let last) = error else {
                Issue.record("retriesExhausted 가 아닙니다: \(error)")
                return
            }
            #expect(attempts == 3)
            guard case .overloaded = last else {
                Issue.record("마지막 오류가 overloaded 가 아닙니다: \(last)")
                return
            }
        }
        #expect(transport.requests.count == 3)
    }

    @Test("HTTP 200 이어도 stop_reason 이 refusal 이면 던진다")
    func refusalIsAnError() async throws {
        let transport = StubTransport(status: 200, body: Fixtures.refusalResponseJSON(category: "cyber"))
        let client = try makeClient(transport: transport)

        do {
            _ = try await client.send(request)
            Issue.record("던졌어야 합니다.")
        } catch let error as AnthropicError {
            guard case .refused(let category, _) = error else {
                Issue.record("refused 가 아닙니다: \(error)")
                return
            }
            #expect(category == "cyber")
            // 서버가 이미 대체 모델까지 태운 결과이므로 재시도하지 않는다.
            #expect(!error.isRetryable)
        }
        #expect(transport.requests.count == 1)
    }

    @Test("fallbacks 를 끄면 베타 헤더도 사라진다")
    func fallbacksCanBeDisabled() throws {
        let withFallbacks = try AnthropicClient(apiKey: makeKey())
        #expect(withFallbacks.betas == ["server-side-fallback-2026-07-01"])

        let without = try AnthropicClient(apiKey: makeKey(), configuration: .init(fallbacks: nil))
        #expect(without.betas.isEmpty)
        let body = try without.makeURLRequest(for: request).httpBody ?? Data()
        #expect(!String(decoding: body, as: UTF8.self).contains("fallbacks"))
    }
}
