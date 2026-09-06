import Foundation
import LessonGenKit
import Testing

/// 동시에 몇 개가 떠 있었는지 세는 계수기.
private final class PeakCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private(set) var peak = 0

    func enter() {
        lock.withLock {
            current += 1
            peak = max(peak, current)
        }
    }

    func leave() {
        lock.withLock { current -= 1 }
    }
}

private struct Boom: Error, Sendable {}

@Suite("동시성 제한 팬아웃 — Batch 대신 쓰는 것")
struct BoundedFanoutTests {
    @Test("결과는 입력 순서를 지킨다")
    func preservesOrder() async {
        let outcomes = await BoundedFanout.run(Array(0..<20), limit: 5) { _, value in
            try await Task.sleep(for: .milliseconds(value % 3))
            return value * 2
        }
        #expect(outcomes.map(\.index) == Array(0..<20))
        #expect(outcomes.compactMap(\.value) == (0..<20).map { $0 * 2 })
    }

    @Test("동시에 뜨는 작업이 제한을 넘지 않는다")
    func respectsLimit() async {
        let counter = PeakCounter()
        _ = await BoundedFanout.run(Array(0..<24), limit: 3) { _, _ in
            counter.enter()
            defer { counter.leave() }
            try await Task.sleep(for: .milliseconds(5))
            return true
        }
        #expect(counter.peak <= 3, "동시 실행 최대 \(counter.peak)개")
        #expect(counter.peak > 1, "제한이 있어도 병렬이어야 한다 — 최대 \(counter.peak)개")
    }

    @Test("한 건이 실패해도 나머지는 끝까지 간다")
    func failureIsIsolated() async {
        let outcomes = await BoundedFanout.run(Array(0..<6), limit: 2) { _, value in
            if value == 2 { throw Boom() }
            return value
        }
        #expect(outcomes.filter { $0.error != nil }.count == 1)
        #expect(outcomes.compactMap(\.value).count == 5)
    }

    @Test("정지 조건에 걸리면 새 작업을 더 띄우지 않는다 — 비용 가드가 정지선인 이유")
    func stopsOnBudget() async {
        let started = PeakCounter()
        let outcomes = await BoundedFanout.run(
            Array(0..<20),
            limit: 1,
            shouldStop: { $0 is RunLogError }
        ) { index, _ in
            started.enter()
            defer { started.leave() }
            if index == 1 {
                throw RunLogError.budgetExceeded(spentUSD: 1, budgetUSD: 1)
            }
            return index
        }
        #expect(outcomes.count == 20)
        let notStarted = outcomes.filter { $0.error is FanoutStopped }
        #expect(notStarted.count == 18, "시작하지 않은 작업 \(notStarted.count)개")
        #expect(started.peak == 1)
    }

    @Test("빈 입력은 빈 결과다")
    func empty() async {
        let outcomes = await BoundedFanout.run([Int](), limit: 4) { _, value in value }
        #expect(outcomes.isEmpty)
    }
}
