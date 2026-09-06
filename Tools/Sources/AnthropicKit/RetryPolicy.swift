/// 지수 백오프 정책.
///
/// ``delay(afterAttempt:retryAfter:jitterUnit:)`` 는 **순수 함수다** — 시계도 난수도
/// 안 건드리므로 지연 시간표를 테스트로 못 박을 수 있다. 난수와 수면은 클라이언트가
/// 주입한다.
public struct RetryPolicy: Sendable, Hashable {
    /// 최초 시도를 포함한 총 시도 횟수.
    public var maxAttempts: Int
    /// 첫 재시도 대기 시간. 이후 시도마다 2배.
    public var baseDelay: Duration
    /// 지수 백오프의 상한. 서버가 준 `retry-after` 는 이 상한을 넘을 수 있다.
    public var maxDelay: Duration
    /// `retry-after` 를 그대로 따르는 상한. 이보다 크면 잘라 낸다.
    public var maxRetryAfter: Duration
    /// 흔들림 폭. 0.25 면 ±25%.
    public var jitterFraction: Double

    public init(
        maxAttempts: Int = 4,
        baseDelay: Duration = .milliseconds(500),
        maxDelay: Duration = .seconds(30),
        maxRetryAfter: Duration = .seconds(120),
        jitterFraction: Double = 0.25
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.maxRetryAfter = maxRetryAfter
        self.jitterFraction = jitterFraction
    }

    /// 재시도 없이 한 번만 시도한다.
    public static let none = RetryPolicy(maxAttempts: 1)

    /// `attempt` 번째 시도가 실패한 뒤 얼마나 기다릴지.
    ///
    /// - Parameters:
    ///   - attempt: 1부터 센다.
    ///   - retryAfter: 서버가 준 값. 있으면 지수 백오프보다 우선한다.
    ///   - jitterUnit: `[0, 1)` 의 난수. 주입받아 테스트에서 결정적으로 만든다.
    public func delay(afterAttempt attempt: Int, retryAfter: Duration?, jitterUnit: Double) -> Duration {
        let target: Duration
        if let retryAfter {
            target = min(retryAfter, maxRetryAfter)
        } else {
            // 2^(attempt-1) 배. Duration 곱셈 오버플로를 피하려고 지수를 먼저 자른다.
            let exponent = min(max(attempt - 1, 0), 20)
            target = min(baseDelay * (1 << exponent), maxDelay)
        }
        guard jitterFraction > 0 else { return target }
        let scale = 1 + jitterFraction * (jitterUnit.clamped(to: 0...1) * 2 - 1)
        return max(.zero, target * scale)
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// 대기. 테스트에서는 실제로 자지 않는 구현을 끼운다.
public protocol Sleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct TaskSleeper: Sleeper {
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
