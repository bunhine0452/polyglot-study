import LLMKit
import Testing

@Suite("지수 백오프 정책")
struct RetryPolicyTests {
    /// 흔들림을 끈 정책. 지연 시간표를 그대로 못 박는다.
    private let steady = RetryPolicy(
        baseDelay: .milliseconds(500),
        maxDelay: .seconds(30),
        jitterFraction: 0
    )

    @Test("시도마다 2배로 늘고 상한에서 멈춘다")
    func exponential() {
        #expect(steady.delay(afterAttempt: 1, retryAfter: nil, jitterUnit: 0.5) == .milliseconds(500))
        #expect(steady.delay(afterAttempt: 2, retryAfter: nil, jitterUnit: 0.5) == .seconds(1))
        #expect(steady.delay(afterAttempt: 3, retryAfter: nil, jitterUnit: 0.5) == .seconds(2))
        #expect(steady.delay(afterAttempt: 4, retryAfter: nil, jitterUnit: 0.5) == .seconds(4))
        #expect(steady.delay(afterAttempt: 10, retryAfter: nil, jitterUnit: 0.5) == .seconds(30))
        // 지수가 아무리 커져도 오버플로하지 않는다.
        #expect(steady.delay(afterAttempt: 1000, retryAfter: nil, jitterUnit: 0.5) == .seconds(30))
    }

    @Test("서버가 준 retry-after 가 지수 백오프를 이긴다")
    func retryAfterWins() {
        #expect(steady.delay(afterAttempt: 1, retryAfter: .seconds(9), jitterUnit: 0.5) == .seconds(9))
        // 첫 시도의 지수값(0.5초)보다 작아도 서버 말을 따른다.
        #expect(steady.delay(afterAttempt: 3, retryAfter: .milliseconds(100), jitterUnit: 0.5) == .milliseconds(100))
    }

    @Test("터무니없이 큰 retry-after 는 상한에서 잘린다")
    func retryAfterClamped() {
        let policy = RetryPolicy(maxRetryAfter: .seconds(120), jitterFraction: 0)
        #expect(policy.delay(afterAttempt: 1, retryAfter: .seconds(3600), jitterUnit: 0.5) == .seconds(120))
    }

    @Test("흔들림이 ±25% 안에 들어온다")
    func jitterBounds() {
        let policy = RetryPolicy(baseDelay: .seconds(4), jitterFraction: 0.25)
        #expect(policy.delay(afterAttempt: 1, retryAfter: nil, jitterUnit: 0.0) == .seconds(3))
        #expect(policy.delay(afterAttempt: 1, retryAfter: nil, jitterUnit: 0.5) == .seconds(4))
        #expect(policy.delay(afterAttempt: 1, retryAfter: nil, jitterUnit: 1.0) == .seconds(5))
    }

    @Test("범위 밖 난수가 들어와도 음수 지연이 나오지 않는다")
    func jitterClamped() {
        let policy = RetryPolicy(baseDelay: .seconds(1), jitterFraction: 0.25)
        #expect(policy.delay(afterAttempt: 1, retryAfter: nil, jitterUnit: -5) >= .zero)
        #expect(policy.delay(afterAttempt: 1, retryAfter: nil, jitterUnit: 5) == .milliseconds(1250))
    }
}
