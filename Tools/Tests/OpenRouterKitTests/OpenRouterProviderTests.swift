import Foundation
import LLMKit
import OpenRouterKit
import TestSupport
import Testing

@Suite("OpenRouter 공급자 — 왕복·재시도·능력")
struct OpenRouterProviderTests {
    private func makeKey() throws -> APIKey {
        try APIKey(rawValue: Fixtures.fakeAPIKeyString)
    }

    private var request: CompletionRequest {
        CompletionRequest(messages: [.user("안녕")], maxOutputTokens: 1000)
    }

    private func makeProvider(
        transport: any HTTPTransport,
        sleeper: any Sleeper = RecordingSleeper(),
        log: any ClientLogSink = DiscardLog(),
        retry: RetryPolicy = RetryPolicy(baseDelay: .milliseconds(500), jitterFraction: 0),
        configure: (inout OpenRouterProvider.Configuration) -> Void = { _ in }
    ) throws -> OpenRouterProvider {
        var configuration = OpenRouterProvider.Configuration(retry: retry)
        configure(&configuration)
        return OpenRouterProvider(
            apiKey: try makeKey(),
            model: ModelID(Fixtures.testModel),
            configuration: configuration,
            transport: transport,
            sleeper: sleeper,
            jitter: { 0.5 },
            log: log
        )
    }

    @Test("한 번에 성공하면 한 번만 호출한다")
    func singleRoundTrip() async throws {
        let transport = StubTransport(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))
        let provider = try makeProvider(transport: transport)
        let response = try await provider.complete(request)
        #expect(response.text == "결과")
        #expect(transport.requests.count == 1)
    }

    @Test("429 뒤에 성공하면 서버가 준 retry-after 를 따른다")
    func retriesOnRateLimit() async throws {
        let transport = StubTransport([
            .response(
                HTTPResponse(
                    status: 429,
                    headers: ["Retry-After": "3"],
                    body: Fixtures.errorJSON(code: 429, message: "느려")
                )
            ),
            .response(HTTPResponse(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))),
        ])
        let sleeper = RecordingSleeper()
        let provider = try makeProvider(transport: transport, sleeper: sleeper)

        let response = try await provider.complete(request)
        #expect(response.text == "결과")
        #expect(transport.requests.count == 2)
        #expect(sleeper.durations == [.seconds(3)])
    }

    @Test("502·503 은 재시도하고 지연이 2배씩 늘어난다")
    func retriesOnUpstreamFailure() async throws {
        let transport = StubTransport([
            .response(HTTPResponse(status: 502, body: Fixtures.errorJSON(code: 502, message: "업스트림 실패"))),
            .response(HTTPResponse(status: 503, body: Fixtures.errorJSON(code: 503, message: "가용 업스트림 없음"))),
            .response(HTTPResponse(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))),
        ])
        let sleeper = RecordingSleeper()
        let provider = try makeProvider(transport: transport, sleeper: sleeper)

        _ = try await provider.complete(request)
        #expect(transport.requests.count == 3)
        #expect(sleeper.durations == [.milliseconds(500), .seconds(1)])
    }

    @Test("전송 오류도 재시도 대상이다")
    func retriesOnTransportFailure() async throws {
        let transport = StubTransport([
            .failure(.transport("연결이 끊겼습니다")),
            .response(HTTPResponse(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))),
        ])
        let provider = try makeProvider(transport: transport)
        _ = try await provider.complete(request)
        #expect(transport.requests.count == 2)
    }

    @Test("400 은 즉시 포기한다 — 다시 걸어도 같은 결과다")
    func doesNotRetryBadRequest() async throws {
        let transport = StubTransport(
            status: 400, body: Fixtures.errorJSON(code: 400, message: "max_tokens 누락")
        )
        let sleeper = RecordingSleeper()
        let provider = try makeProvider(transport: transport, sleeper: sleeper)

        await #expect(throws: LLMError.self) { try await provider.complete(request) }
        #expect(transport.requests.count == 1)
        #expect(sleeper.durations.isEmpty)
    }

    @Test("402 크레딧 부족도 즉시 포기한다")
    func doesNotRetryOutOfCredits() async throws {
        let transport = StubTransport(status: 402, body: Fixtures.errorJSON(code: 402, message: "크레딧 부족"))
        let provider = try makeProvider(transport: transport)
        await #expect(throws: LLMError.self) { try await provider.complete(request) }
        #expect(transport.requests.count == 1)
    }

    @Test("재시도를 다 쓰면 retriesExhausted 로 끝나고 마지막 오류를 물고 있다")
    func exhaustsRetries() async throws {
        let overloaded = HTTPResponse(status: 503, body: Fixtures.errorJSON(code: 503, message: "가용 업스트림 없음"))
        let transport = StubTransport([.response(overloaded), .response(overloaded), .response(overloaded)])
        let provider = try makeProvider(
            transport: transport,
            retry: RetryPolicy(maxAttempts: 3, baseDelay: .milliseconds(10), jitterFraction: 0)
        )

        do {
            _ = try await provider.complete(request)
            Issue.record("던졌어야 합니다.")
        } catch let error as LLMError {
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

    @Test("HTTP 200 이어도 본문에 오류가 있으면 던진다")
    func inlineErrorIsAnError() async throws {
        let transport = StubTransport(
            status: 200, body: Fixtures.inlineErrorJSON(code: 403, message: "모더레이션")
        )
        let provider = try makeProvider(transport: transport)
        do {
            _ = try await provider.complete(request)
            Issue.record("던졌어야 합니다.")
        } catch let error as LLMError {
            guard case .permission = error else {
                Issue.record("permission 이 아닙니다: \(error)")
                return
            }
            #expect(!error.isRetryable)
        }
        #expect(transport.requests.count == 1)
    }

    // MARK: - 능력 선언

    /// `CodeRunner.enforcedLimits` 와 같은 규율 — 능력은 이 구현이 실제로 하는 것이지
    /// 모델의 이론적 상한이 아니다.
    @Test("라우팅을 좁히지 않으면 구조화 출력 능력을 선언하지 않는다")
    func capabilitiesFollowConfiguration() throws {
        let transport = StubTransport(status: 200, body: Fixtures.chatCompletionJSON(text: "x"))
        let strict = try makeProvider(transport: transport)
        #expect(strict.capabilities.contains(.structuredOutputs))
        #expect(strict.capabilities.contains(.usageCost))
        #expect(strict.capabilities.contains(.automaticPromptCaching))
        // 이 구현은 스트리밍을 하지 않는다 — OpenRouter 가 못 해서가 아니다.
        #expect(!strict.capabilities.contains(.streaming))

        let loose = try makeProvider(transport: transport) { configuration in
            configuration.requireParameters = false
            configuration.promptCaching = .explicitBreakpoints
        }
        #expect(!loose.capabilities.contains(.structuredOutputs))
        #expect(loose.capabilities.contains(.explicitPromptCaching))
        // 사용량·비용은 끌 수 없다 — 응답에 항상 실린다.
        #expect(loose.capabilities.contains(.usageCost))
    }

    @Test("선언하지 않은 구조화 출력을 요구하면 전선을 타기 전에 거절한다")
    func rejectsUnsupportedFormatWithoutCallingOut() async throws {
        let transport = StubTransport(status: 200, body: Fixtures.chatCompletionJSON(text: "산문"))
        let provider = try makeProvider(transport: transport) { $0.requireParameters = false }
        var structured = request
        structured.responseFormat = .jsonSchema(name: "x", schema: ["type": "object"])

        await #expect(throws: LLMError.unsupported(.structuredOutputs)) {
            _ = try await provider.complete(structured)
        }
        // 정말 안 보냈다.
        #expect(transport.requests.isEmpty)
    }

    @Test("공급자가 계약을 통과한다")
    func satisfiesProviderContract() async throws {
        let transport = StubTransport([
            .response(HTTPResponse(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))),
            .response(HTTPResponse(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))),
            .response(HTTPResponse(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))),
        ])
        let provider = try makeProvider(transport: transport)
        let violations = await ProviderContract.check(provider, happyPath: request)
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test("스트리밍은 선언하지 않았으므로 unsupported 로 끝난다")
    func streamingIsUnsupported() async throws {
        let transport = StubTransport(status: 200, body: Fixtures.chatCompletionJSON(text: "x"))
        let provider = try makeProvider(transport: transport)
        await #expect(throws: LLMError.unsupported(.streaming)) {
            for try await _ in provider.stream(request) {}
        }
    }

    // MARK: - 로그 전수 검사

    @Test("공급자가 뱉은 로그 전수에 키가 0건이다")
    func logsNeverLeakTheKey() async throws {
        let log = CapturingLog()
        let transport = StubTransport([
            .response(
                HTTPResponse(
                    status: 429,
                    headers: ["retry-after": "1"],
                    body: Fixtures.errorJSON(code: 429, message: "느려")
                )
            ),
            .response(HTTPResponse(status: 503, body: Fixtures.errorJSON(code: 503, message: "과부하"))),
            .response(HTTPResponse(status: 200, body: Fixtures.chatCompletionJSON(text: "결과"))),
        ])
        let provider = try makeProvider(transport: transport, log: log)
        _ = try await provider.complete(request)

        // 성공·재시도·오류 세 종류가 다 찍혔는지 먼저 확인한다 — 로그가 비어 있어서
        // "0건" 인 것은 증명이 아니다.
        #expect(log.lines.count >= 5)
        #expect(log.joined.contains("재시도"))
        #expect(log.joined.contains("성공"))
        // 모델과 업스트림은 반대로 남아야 한다 — 재현에 필요하다.
        #expect(log.joined.contains(Fixtures.testModel))
        #expect(log.joined.contains("upstream=TestUpstream"))

        for line in log.lines {
            #expect(!line.contains(Fixtures.fakeAPIKeyString), "로그에 키가 실렸습니다: \(line)")
            #expect(!line.contains("sk-or-"), "로그에 키처럼 생긴 토큰이 있습니다: \(line)")
        }
    }

    @Test("누가 일부러 키를 로그에 넣어도 지워진다")
    func sinkCannotBeBypassed() async throws {
        let log = CapturingLog()
        let transport = StubTransport(
            status: 401,
            // 서버가 키를 되돌려주는 최악의 경우를 흉내 낸다.
            body: Fixtures.errorJSON(code: 401, message: "invalid key: \(Fixtures.fakeAPIKeyString)")
        )
        let provider = try makeProvider(transport: transport, log: log)

        await #expect(throws: LLMError.self) { try await provider.complete(request) }
        #expect(!log.joined.isEmpty)
        #expect(!log.joined.contains(Fixtures.fakeAPIKeyString))
        #expect(log.joined.contains(APIKey.placeholder))
    }

    @Test("에러 설명을 그대로 찍어도 Redactor 를 거치면 키가 없다")
    func errorDescriptionsAreRedactable() throws {
        let key = Fixtures.fakeAPIKeyString
        let redactor = Redactor(apiKey: try makeKey())
        let errors: [LLMError] = [
            .authentication(ProviderErrorDetail(code: "401", message: "bad key \(key)")),
            .transport("connection failed for \(key)"),
            .undecodableError(status: 520, body: "gateway saw \(key)"),
            .malformedResponse("payload had \(key)"),
            .retriesExhausted(attempts: 3, last: .transport("last saw \(key)")),
        ]
        for error in errors {
            let redacted = redactor.redact(String(describing: error))
            #expect(!redacted.contains(key), "\(error)")
            #expect(redacted.contains(APIKey.placeholder))
        }
    }
}
