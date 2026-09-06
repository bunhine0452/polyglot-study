internal import Foundation

/// stdout·stderr 합계에 거는 출력 상한.
///
/// swift-subprocess 의 `.string(limit:)` / `.bytes(limit:)` 를 쓰지 않는 이유가 있다 —
/// 그 API 들은 상한을 넘기면 **잘라내는 게 아니라 `outputLimitExceeded` 를 던지고 수집한
/// 것을 통째로 버린다**. 학습자에게는 "출력이 너무 많아 아무것도 못 보여준다"가 되고,
/// 계약의 `.truncated` 는 영영 오지 않는다. `.strings()` 도 기본 `BufferingPolicy` 가
/// `.maxLineLength(128KB)` 라 개행 없는 긴 한 줄에서 똑같이 throw 한다.
///
/// 그래서 `SubprocessOutputSequence.Buffer` 를 직접 세고, **상한을 넘긴 뒤에도 파이프는
/// 계속 비운다**. 비우지 않으면 64KB 파이프 버퍼가 차서 자식이 `write(2)` 에 매달리고,
/// 그건 벽시계 초과로 관측돼 가짜 타임아웃이 된다.
final class OutputBudget: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: Int
    private var announced = false

    init(limit: Int) {
        remaining = max(0, limit)
    }

    /// - Returns: `allowed` 는 실제로 흘려보낼 바이트 수, `didTruncate` 는 **이번 호출에서
    ///   처음** 상한을 넘겼는지. 두 번째부터는 false 라 `.truncated` 는 정확히 한 번 나간다.
    func take(_ count: Int) -> (allowed: Int, didTruncate: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard count > 0 else { return (0, false) }
        if remaining >= count {
            remaining -= count
            return (count, false)
        }
        let allowed = remaining
        remaining = 0
        let didTruncate = !announced
        announced = true
        return (allowed, didTruncate)
    }

    var didTruncate: Bool {
        lock.lock()
        defer { lock.unlock() }
        return announced
    }
}

/// 여러 태스크가 공유하는 프로세스 그룹 번호 한 칸.
///
/// 취소 핸들러는 동기 컨텍스트라 `await` 로 값을 꺼낼 수 없다. 그래서 락 하나짜리
/// 상자로 둔다 — 취소가 걸린 순간 그룹을 아직 모를 수도 있고(스폰 직후), 그때는
/// 런처를 향한 teardown 이 대신 막아준다.
final class ProcessGroupBox: @unchecked Sendable {
    private let lock = NSLock()
    private var group: Int32?

    var value: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return group
    }

    func set(_ newValue: Int32) {
        lock.lock()
        group = newValue
        lock.unlock()
    }
}
