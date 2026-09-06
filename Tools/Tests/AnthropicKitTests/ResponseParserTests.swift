import AnthropicKit
import Foundation
import TestSupport
import Testing

@Suite("응답 해석과 에러 매핑")
struct ResponseParserTests {
    @Test("200 은 응답으로 해석된다")
    func success() throws {
        let result = ResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.messagesResponseJSON(text: "안녕", cacheReadInputTokens: 4096)
        )
        let response = try result.get()
        #expect(response.id == "msg_01TEST")
        #expect(response.text == "안녕")
        #expect(response.stopReason == .endTurn)
        #expect(response.stopDetails == nil)
        #expect(response.usage.inputTokens == 1234)
        #expect(response.usage.outputTokens == 567)
        // {#lessongen-prompt-caching} 의 검증 지점.
        #expect(response.usage.cacheReadInputTokens == 4096)
    }

    @Test(
        "상태 코드가 각각 다른 오류로 갈린다",
        arguments: [
            (400, "invalid_request_error", false),
            (401, "authentication_error", false),
            (403, "permission_error", false),
            (404, "not_found_error", false),
            (413, "request_too_large", false),
            (429, "rate_limit_error", true),
            (500, "api_error", true),
            (503, "api_error", true),
            (529, "overloaded_error", true),
        ]
    )
    func statusMapping(status: Int, type: String, retryable: Bool) throws {
        let error = ResponseParser.error(
            status: status,
            headers: [:],
            data: Fixtures.errorJSON(type: type, message: "테스트")
        )
        #expect(error.isRetryable == retryable, "\(status) 의 재시도 판정이 다릅니다: \(error)")

        switch (status, error) {
        case (400, .invalidRequest), (401, .authentication), (403, .permission),
             (404, .notFound), (413, .requestTooLarge), (429, .rateLimited),
             (529, .overloaded), (500, .server), (503, .server):
            break
        default:
            Issue.record("\(status) 가 예상 밖의 케이스로 갔습니다: \(error)")
        }
    }

    @Test("각 상태 코드가 서로 다른 케이스로 간다")
    func mappingsAreDistinct() {
        let statuses = [400, 401, 403, 404, 413, 429, 500, 529]
        let errors = statuses.map {
            ResponseParser.error(status: $0, headers: [:], data: Fixtures.errorJSON(type: "t", message: "m"))
        }
        #expect(Set(errors).count == statuses.count)
    }

    @Test("retry-after 는 대소문자와 무관하게 읽힌다")
    func retryAfterHeader() {
        #expect(ResponseParser.retryAfter(from: ["Retry-After": "7"]) == .seconds(7))
        #expect(ResponseParser.retryAfter(from: ["retry-after": " 2.5 "]) == .milliseconds(2500))
        #expect(ResponseParser.retryAfter(from: [:]) == nil)
        // HTTP-date 형태는 해석하지 않고 지수 백오프로 넘긴다.
        #expect(ResponseParser.retryAfter(from: ["retry-after": "Wed, 21 Oct 2026 07:28:00 GMT"]) == nil)
    }

    @Test("429 는 retry-after 를 오류에 실어 나른다")
    func rateLimitCarriesRetryAfter() throws {
        let error = ResponseParser.error(
            status: 429,
            headers: ["retry-after": "12"],
            data: Fixtures.errorJSON(type: "rate_limit_error", message: "느려")
        )
        #expect(error.retryAfter == .seconds(12))
    }

    @Test("오류 본문이 JSON 이 아니면 unexpectedStatus 로 떨어진다")
    func nonJSONErrorBody() {
        let error = ResponseParser.error(status: 502, headers: [:], data: Data("<html>bad gateway</html>".utf8))
        guard case .unexpectedStatus(let status, let body) = error else {
            Issue.record("unexpectedStatus 가 아닙니다: \(error)")
            return
        }
        #expect(status == 502)
        #expect(body.contains("bad gateway"))
        // 상태 코드를 못 읽었으니 재시도하지 않는다.
        #expect(!error.isRetryable)
    }

    @Test("200 인데 본문이 깨졌으면 malformedResponse")
    func malformedSuccess() {
        let result = ResponseParser.parse(status: 200, headers: [:], data: Data("{\"nope\":1}".utf8))
        guard case .failure(let error) = result, case .malformedResponse = error else {
            Issue.record("malformedResponse 가 아닙니다: \(result)")
            return
        }
    }

    @Test("모르는 stop_reason 이 와도 디코딩이 깨지지 않는다")
    func unknownStopReason() throws {
        let result = ResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.messagesResponseJSON(text: "x", stopReason: "some_future_reason")
        )
        let response = try result.get()
        #expect(response.stopReason == StopReason("some_future_reason"))
    }
}
