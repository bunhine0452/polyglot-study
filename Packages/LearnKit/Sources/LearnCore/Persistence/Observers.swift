/// 페이크 스토어들이 공유하는 아주 작은 브로드캐스터.
///
/// GRDB 구현은 `ValueObservation` 이 이 역할을 하므로 이 타입을 쓰지 않는다. 여기 있는 것은
/// **테스트가 GRDB 없이도 같은 관찰 계약을 검증**할 수 있게 하기 위한 것이다.
///
/// 값이 실제로 바뀔 때만 흘린다 — GRDB 쪽 `removeDuplicates()` 와 같은 규약이다.
/// 이게 없으면 관계없는 쓰기 하나가 UI 를 깨우고, 두 구현의 발화 횟수가 달라진다.
struct ContinuationRegistry<Value: Sendable & Equatable> {
    private var continuations: [AsyncThrowingStream<Value, any Error>.Continuation] = []
    private var lastValue: Value?

    /// 구독을 등록하고 현재 값을 즉시 한 번 흘린다 — `ValueObservation` 의 초기값 전달과 같은 규약.
    mutating func add(
        _ continuation: AsyncThrowingStream<Value, any Error>.Continuation,
        current: Value
    ) {
        continuations.append(continuation)
        lastValue = current
        continuation.yield(current)
    }

    /// 값이 달라졌을 때만 흘리고, 이미 끝난 구독은 그 자리에서 걷어낸다.
    mutating func broadcast(_ value: Value) {
        guard lastValue != value else { return }
        lastValue = value
        continuations.removeAll { continuation in
            if case .terminated = continuation.yield(value) { return true }
            return false
        }
    }

    mutating func finish() {
        for continuation in continuations { continuation.finish() }
        continuations.removeAll()
    }
}
