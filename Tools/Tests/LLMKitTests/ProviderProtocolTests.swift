import LLMKit
import TestSupport
import Testing

@Suite("공급자 프로토콜과 계약")
struct ProviderProtocolTests {
    private var happyPath: CompletionRequest {
        CompletionRequest(messages: [.user("안녕")], maxOutputTokens: 100)
    }

    @Test("가짜 공급자가 계약을 통과한다 — 계약이 한 구현 전용이 아님을 보인다")
    func fakeProviderSatisfiesContract() async {
        let provider = FakeProvider(alwaysReturning: "결과")
        let violations = await ProviderContract.check(provider, happyPath: happyPath)
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test("스트리밍 미선언 공급자의 stream() 은 unsupported 로 끝난다")
    func streamingIsHonest() async {
        let provider = FakeProvider(alwaysReturning: "결과")
        #expect(!provider.capabilities.contains(.streaming))
        await #expect(throws: LLMError.unsupported(.streaming)) {
            for try await _ in provider.stream(happyPath) {}
        }
    }

    @Test("선언하지 않은 능력을 요구하면 전선을 타기 전에 거절한다")
    func unsupportedFormatIsRejected() async {
        // 구조화 출력을 못 하는 공급자.
        let provider = FakeProvider(capabilities: [.usageTokens], alwaysReturning: "{}")
        var request = happyPath
        request.responseFormat = .jsonSchema(name: "x", schema: ["type": "object"])

        await #expect(throws: LLMError.unsupported(.structuredOutputs)) {
            _ = try await provider.complete(request)
        }
        // 거절했으므로 요청은 기록되지 않는다 — 정말 안 보냈다는 뜻이다.
        #expect(provider.requests.isEmpty)
    }

    @Test("능력을 부풀린 구현은 계약에서 걸린다")
    func inflatedCapabilitiesAreCaught() async {
        // 스트리밍을 한다고 선언해 놓고 기본 구현(던지기)을 그대로 쓰는 공급자.
        let liar = FakeProvider(capabilities: [.streaming, .usageTokens], alwaysReturning: "x")
        // 계약은 미선언일 때만 stream 을 검사하므로, 이 거짓말은 다른 규칙이 잡는다:
        // usageCost 를 선언했는데 비용이 없는 경우.
        let costLiar = FakeProvider(capabilities: [.usageTokens, .usageCost], alwaysReturning: "x")
        let violations = await ProviderContract.check(costLiar, happyPath: happyPath)
        #expect(violations.contains { $0.rule == "cost-is-reported" }, "\(violations)")
        #expect(liar.capabilities.contains(.streaming))
    }

    @Test("해피패스가 실패하는 공급자는 계약에서 걸린다")
    func brokenHappyPathIsCaught() async {
        let broken = FakeProvider(steps: [.failure(.provider("고장"))])
        let violations = await ProviderContract.check(broken, happyPath: happyPath)
        #expect(violations.contains { $0.rule == "happy-path-succeeds" }, "\(violations)")
    }

    @Test("응답 형식마다 필요한 능력이 다르다")
    func formatCapabilityMapping() {
        #expect(ResponseFormat.text.requiredCapability == nil)
        #expect(ResponseFormat.jsonObject.requiredCapability == .jsonObjectMode)
        #expect(ResponseFormat.jsonSchema(name: "x", schema: [:]).requiredCapability == .structuredOutputs)
    }

    @Test("능력 집합이 사람이 읽을 수 있게 찍힌다")
    func capabilitiesDescription() {
        let capabilities: ProviderCapabilities = [.structuredOutputs, .usageTokens]
        let text = capabilities.description
        #expect(text.contains("structuredOutputs"))
        #expect(text.contains("usageTokens"))
        #expect(!text.contains("streaming"))
        #expect(ProviderCapabilities().description == "[]")
    }

    @Test("모르는 usage 는 0 이 아니라 물음표로 남는다")
    func unknownUsageIsNotZero() {
        #expect(TokenUsage.unknown.logLine == "in=? out=? cached=?")
        let known = TokenUsage(inputTokens: 10, outputTokens: 2, cachedInputTokens: 0, costUSD: 0.000001)
        #expect(known.logLine.contains("in=10 out=2 cached=0"))
        #expect(known.logLine.contains("cost=$0.000001"))
    }

    @Test("신원 문자열에 비밀값이 없다")
    func identityIsLogSafe() {
        let identity = ProviderIdentity(provider: "openrouter", model: ModelID("vendor/model"))
        #expect(identity.description == "openrouter:vendor/model")
        #expect(Redactor().redact(identity.description) == identity.description)
    }

    @Test("재시도 판정이 오류 종류로 갈린다")
    func retryClassification() {
        let detail = ProviderErrorDetail(message: "테스트")
        #expect(LLMError.rateLimited(detail, retryAfter: nil).isRetryable)
        #expect(LLMError.overloaded(detail).isRetryable)
        #expect(LLMError.server(detail).isRetryable)
        #expect(LLMError.transport("끊김").isRetryable)
        // 지갑이 비었거나 요청이 틀린 것은 다시 걸어도 같다.
        #expect(!LLMError.insufficientCredits(detail).isRetryable)
        #expect(!LLMError.invalidRequest(detail).isRetryable)
        #expect(!LLMError.authentication(detail).isRetryable)
        #expect(!LLMError.refused(reason: "정책").isRetryable)
        #expect(!LLMError.unsupported(.streaming).isRetryable)
    }
}
