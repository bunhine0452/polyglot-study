import Foundation
import LLMKit
import OpenRouterKit
import TestSupport
import Testing

@Suite("OpenRouter 응답 해석과 에러 매핑")
struct OpenRouterResponseParserTests {
    @Test("200 은 응답으로 해석되고 실제로 답한 모델·업스트림이 실린다")
    func success() throws {
        let result = OpenRouterResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.chatCompletionJSON(text: "안녕", model: "vendor/actual", upstreamProvider: "Fireworks", cachedTokens: 4096)
        )
        let response = try result.get()
        #expect(response.id == "gen-01TEST")
        #expect(response.text == "안녕")
        // 라우터가 갈아탈 수 있으므로 요청값이 아니라 응답값을 남긴다.
        #expect(response.model == "vendor/actual")
        #expect(response.upstreamProvider == "Fireworks")
        #expect(response.finishReason == .stop)
        #expect(response.usage.inputTokens == 1234)
        #expect(response.usage.outputTokens == 567)
        #expect(response.usage.reasoningTokens == 42)
        #expect(response.usage.costUSD == 0.000123)
        // {#lessongen-prompt-caching} 의 검증 지점.
        #expect(response.usage.cachedInputTokens == 4096)
    }

    /// "0 토큰" 과 "모른다" 는 다른 사실이다. 0 으로 채우면 비용 가드가 조용히 틀린
    /// 합계를 낸다 (`{#lessongen-runlog}`).
    @Test("usage 가 없으면 0 이 아니라 '모른다' 로 남는다")
    func missingUsageIsUnknown() throws {
        let payload: [String: Any] = [
            "id": "gen-x",
            "model": "m",
            "choices": [["index": 0, "finish_reason": "stop", "message": ["content": "hi"]]],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let response = try OpenRouterResponseParser.parse(status: 200, headers: [:], data: data).get()
        #expect(response.usage == .unknown)
        #expect(response.usage.inputTokens == nil)
        #expect(response.usage.logLine == "in=? out=? cached=?")
    }

    @Test(
        "상태 코드가 각각 다른 오류로 갈린다",
        arguments: [
            (400, false), (401, false), (402, false), (403, false), (404, false),
            (408, true), (413, false), (429, true), (500, true), (502, true), (503, true),
        ]
    )
    func statusMapping(status: Int, retryable: Bool) throws {
        let error = OpenRouterResponseParser.error(
            status: status,
            headers: [:],
            data: Fixtures.errorJSON(code: status, message: "테스트")
        )
        #expect(error.isRetryable == retryable, "\(status) 의 재시도 판정이 다릅니다: \(error)")

        switch (status, error) {
        case (400, .invalidRequest), (401, .authentication), (402, .insufficientCredits),
             (403, .permission), (404, .notFound), (408, .overloaded), (413, .requestTooLarge),
             (429, .rateLimited), (500, .server), (502, .overloaded), (503, .overloaded):
            break
        default:
            Issue.record("\(status) 가 예상 밖의 케이스로 갔습니다: \(error)")
        }
    }

    @Test("크레딧 부족은 재시도하지 않는다 — 다시 걸어도 지갑은 그대로다")
    func creditsAreNotRetried() {
        let error = OpenRouterResponseParser.error(
            status: 402, headers: [:], data: Fixtures.errorJSON(code: 402, message: "크레딧 부족")
        )
        guard case .insufficientCredits = error else {
            Issue.record("insufficientCredits 가 아닙니다: \(error)")
            return
        }
        #expect(!error.isRetryable)
    }

    @Test("오류에 실패한 업스트림 이름이 실린다 — 어디가 죽었는지 알아야 한다")
    func errorNamesUpstream() {
        let error = OpenRouterResponseParser.error(
            status: 502,
            headers: [:],
            data: Fixtures.errorJSON(code: 502, message: "업스트림 실패", providerName: "SomeUpstream")
        )
        #expect(String(describing: error).contains("SomeUpstream"))
    }

    /// OpenRouter 는 성공 상태와 함께 본문에 오류를 실어 보낼 수 있다. 상태 코드만
    /// 보면 "choices 가 없다" 는 엉뚱한 메시지로 실패한다.
    @Test("HTTP 200 인데 본문에 오류가 있으면 그 오류로 떨어진다")
    func inlineErrorOn200() {
        let result = OpenRouterResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.inlineErrorJSON(code: 429, message: "업스트림 레이트 리밋")
        )
        guard case .failure(let error) = result else {
            Issue.record("실패했어야 합니다: \(result)")
            return
        }
        guard case .rateLimited = error else {
            Issue.record("rateLimited 가 아닙니다: \(error)")
            return
        }
        #expect(error.isRetryable)
    }

    @Test("refusal 필드가 있으면 거절이고 재시도하지 않는다")
    func refusal() {
        let result = OpenRouterResponseParser.parse(
            status: 200, headers: [:], data: Fixtures.refusalJSON(reason: "정책상 거절")
        )
        guard case .failure(let error) = result, case .refused(let reason) = error else {
            Issue.record("refused 가 아닙니다: \(result)")
            return
        }
        #expect(reason == "정책상 거절")
        #expect(!error.isRetryable)
    }

    @Test("content_filter 로 끝난 것은 빈 응답이 아니라 거절이다")
    func contentFilterIsRefusal() {
        let result = OpenRouterResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.chatCompletionJSON(text: "", finishReason: "content_filter")
        )
        guard case .failure(let error) = result, case .refused = error else {
            Issue.record("refused 가 아닙니다: \(result)")
            return
        }
    }

    @Test("잘린 응답은 finishReason 으로 드러난다")
    func truncation() throws {
        let response = try OpenRouterResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.chatCompletionJSON(text: "{\"a\":", finishReason: "length")
        ).get()
        #expect(response.finishReason == .length)
    }

    @Test("retry-after 는 대소문자와 무관하게 읽힌다")
    func retryAfterHeader() {
        #expect(OpenRouterResponseParser.retryAfter(from: ["Retry-After": "7"]) == .seconds(7))
        #expect(OpenRouterResponseParser.retryAfter(from: ["retry-after": " 2.5 "]) == .milliseconds(2500))
        #expect(OpenRouterResponseParser.retryAfter(from: [:]) == nil)
        // HTTP-date 형태는 해석하지 않고 지수 백오프로 넘긴다.
        #expect(OpenRouterResponseParser.retryAfter(from: ["retry-after": "Wed, 21 Oct 2026 07:28:00 GMT"]) == nil)
    }

    @Test("429 는 retry-after 를 오류에 실어 나른다")
    func rateLimitCarriesRetryAfter() {
        let error = OpenRouterResponseParser.error(
            status: 429,
            headers: ["retry-after": "12"],
            data: Fixtures.errorJSON(code: 429, message: "느려")
        )
        #expect(error.retryAfter == .seconds(12))
    }

    @Test("오류 본문이 JSON 이 아니면 undecodableError 로 떨어진다")
    func nonJSONErrorBody() {
        let error = OpenRouterResponseParser.error(
            status: 520, headers: [:], data: Data("<html>cloudflare</html>".utf8)
        )
        guard case .undecodableError(let status, let body) = error else {
            Issue.record("undecodableError 가 아닙니다: \(error)")
            return
        }
        #expect(status == 520)
        #expect(body.contains("cloudflare"))
        // 상태를 못 읽었으니 재시도하지 않는다.
        #expect(!error.isRetryable)
    }

    @Test("200 인데 choices 가 없으면 malformedResponse")
    func malformedSuccess() {
        let result = OpenRouterResponseParser.parse(status: 200, headers: [:], data: Data("{\"id\":\"x\"}".utf8))
        guard case .failure(let error) = result, case .malformedResponse = error else {
            Issue.record("malformedResponse 가 아닙니다: \(result)")
            return
        }
    }

    @Test("모르는 finish_reason 이 와도 디코딩이 깨지지 않는다")
    func unknownFinishReason() throws {
        let response = try OpenRouterResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.chatCompletionJSON(text: "x", finishReason: "some_future_reason")
        ).get()
        #expect(response.finishReason == FinishReason("some_future_reason"))
    }

    /// OpenRouter 는 업스트림이 요청을 받아들인 뒤의 실패를 HTTP 200 에 실어 보낸다.
    /// 그 경우 상태 코드는 아무것도 말해 주지 않으므로 `error_type` 이 유일한 신호다.
    @Test(
        "error_type 이 상태 코드보다 먼저 분류를 정한다",
        arguments: [
            ("rate_limit_exceeded", true),
            ("provider_overloaded", true),
            ("provider_unavailable", true),
            ("timeout", true),
            ("server", true),
            ("payment_required", false),
            ("context_length_exceeded", false),
            ("content_policy_violation", false),
            ("authentication", false),
        ]
    )
    func errorTypeDrivesClassification(errorType: String, retryable: Bool) throws {
        // 상태 코드는 200 이다 — error_type 이 없으면 재시도 판정을 못 한다.
        let payload: [String: Any] = [
            "id": "gen-x",
            "error": [
                "code": 200,
                "message": "업스트림 실패",
                "metadata": ["error_type": errorType, "provider_name": "SomeUpstream"],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = OpenRouterResponseParser.parse(status: 200, headers: [:], data: data)
        guard case .failure(let error) = result else {
            Issue.record("실패했어야 합니다: \(result)")
            return
        }
        #expect(error.isRetryable == retryable, "\(errorType) 의 재시도 판정이 다릅니다: \(error)")
        // 분류 이름이 사람이 읽는 설명에 남는다.
        #expect(String(describing: error).contains(errorType))
    }

    @Test("모르는 error_type 은 상태 코드 경로로 넘어간다")
    func unknownErrorTypeFallsBack() throws {
        let payload: [String: Any] = [
            "error": ["code": 429, "message": "m", "metadata": ["error_type": "some_future_type"]]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let error = OpenRouterResponseParser.error(status: 429, headers: ["retry-after": "5"], data: data)
        guard case .rateLimited = error else {
            Issue.record("rateLimited 가 아닙니다: \(error)")
            return
        }
        #expect(error.retryAfter == .seconds(5))
    }

    @Test("각 상태 코드가 서로 다른 오류 값이 된다")
    func mappingsAreDistinct() {
        let statuses = [400, 401, 402, 403, 404, 413, 429, 500]
        let errors = statuses.map {
            OpenRouterResponseParser.error(status: $0, headers: [:], data: Fixtures.errorJSON(code: $0, message: "m"))
        }
        #expect(Set(errors).count == statuses.count)
    }
}
