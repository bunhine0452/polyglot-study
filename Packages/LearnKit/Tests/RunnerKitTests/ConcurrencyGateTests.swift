import Foundation
import Testing

@testable import RunnerKit

/// 문을 지나는 동안의 최고 동시 수를 센다. 잠금 없이 세면 그 카운터 자체가 경쟁한다.
private final class PeakCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private(set) var peak = 0

    func enter() {
        lock.lock()
        current += 1
        peak = max(peak, current)
        lock.unlock()
    }

    func leave() {
        lock.lock()
        current -= 1
        lock.unlock()
    }
}

@Suite("동시 실행 상한 — ConcurrencyGate")
struct ConcurrencyGateTests {

    @Test("상한을 넘겨 동시에 들어가지 못한다", arguments: [1, 2, 4])
    func neverExceedsLimit(limit: Int) async {
        let gate = ConcurrencyGate(limit: limit)
        let counter = PeakCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    await gate.withSlot {
                        counter.enter()
                        // 겹칠 기회를 준다. 즉시 반환하면 상한을 못 넘겨도 우연일 수 있다.
                        try? await Task.sleep(for: .milliseconds(5))
                        counter.leave()
                    }
                }
            }
        }

        #expect(counter.peak <= limit)
        // 상한이 1보다 크면 실제로 겹쳐야 한다 — 아무도 안 겹쳤으면 이 테스트는 아무것도
        // 재지 않은 것이다. **정확히 상한만큼**은 단언하지 않는다: 겹치는 정도는 스케줄러가
        // 정하고, 부하가 걸린 러너에서 흔들린다.
        #expect(counter.peak > 1 || limit == 1)
        // 전부 반납됐다.
        #expect(gate.activeCount == 0)
        #expect(gate.waitingCount == 0)
    }

    @Test("본문이 던져도 자리는 반납된다")
    func slotIsReturnedOnThrow() async {
        struct Boom: Error {}
        let gate = ConcurrencyGate(limit: 1)

        await #expect(throws: Boom.self) {
            try await gate.withSlot { throw Boom() }
        }
        #expect(gate.activeCount == 0)

        // 문이 잠긴 채 남았다면 이 호출이 영영 돌아오지 않는다.
        var entered = false
        await gate.withSlot { entered = true }
        #expect(entered)
    }

    @Test("대기는 도착 순서대로 풀린다 — 대기열이 굶지 않는다")
    func waitersAreServedInOrder() async {
        let gate = ConcurrencyGate(limit: 1)
        let order = OrderLog()
        let hold = Latch()

        // 문을 잡은 채 기다리는 쪽을 **별도 Task 로** 띄운다. 잡은 자리 안에서 다시
        // `withSlot` 을 기다리면 그 자체가 교착이다(상한 1짜리 문에서 자기 자신을 기다린다).
        let holder = Task {
            await gate.withSlot {
                await hold.wait()
                order.append(0)
            }
        }
        while gate.activeCount < 1 { await Task.yield() }

        var waiters: [Task<Void, Never>] = []
        for index in 1...4 {
            waiters.append(Task { await gate.withSlot { order.append(index) } })
            // 도착 순서를 결정적으로 만든다. 이게 없으면 줄 서는 순서 자체가 비결정적이라
            // FIFO 를 단언할 수 없다.
            while gate.waitingCount < index { await Task.yield() }
        }

        hold.open()
        await holder.value
        for waiter in waiters { await waiter.value }

        #expect(order.values == [0, 1, 2, 3, 4])
        #expect(gate.activeCount == 0)
    }

    @Test("0 이하 상한은 1 로 올라간다 — 아무도 못 지나가는 문은 문이 아니다")
    func limitIsAtLeastOne() {
        #expect(ConcurrencyGate(limit: 0).limit == 1)
        #expect(ConcurrencyGate(limit: -3).limit == 1)
    }

    // MARK: - 실행 상한이 실제로 배선돼 있는가

    @Test("기본 스폰 상한은 packtool 의 검증 동시성과 같은 식이다")
    func defaultSpawnLimitMatchesValidator() {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        #expect(ExecutionLimits.defaultSpawnLimit == max(2, cores / 2))
        #expect(ExecutionLimits.spawns.limit == ExecutionLimits.defaultSpawnLimit)
    }

    @Test("SubprocessRunner 는 기본으로 전역 문을 쓴다")
    func subprocessRunnerUsesGlobalGate() {
        #expect(SubprocessRunnerConfiguration().spawnGate === ExecutionLimits.spawns)
    }

    @Test("같은 템플릿 디렉터리는 언제나 같은 문을, 다른 디렉터리는 다른 문을 받는다")
    func templateGatesAreKeyedByPath() {
        let a = URL(fileURLWithPath: "/tmp/learnkit-template-a")
        let b = URL(fileURLWithPath: "/tmp/learnkit-template-b")
        // 끝에 슬래시가 붙어도 같은 디렉터리다 — 표준화하지 않으면 상호 배제가 갈린다.
        let aAgain = URL(fileURLWithPath: "/tmp/learnkit-template-a", isDirectory: true)

        #expect(ExecutionLimits.swiftTemplateGate(for: a) === ExecutionLimits.swiftTemplateGate(for: aAgain))
        #expect(ExecutionLimits.swiftTemplateGate(for: a) !== ExecutionLimits.swiftTemplateGate(for: b))
        #expect(ExecutionLimits.swiftTemplateGate(for: a).limit == 1)
    }
}

/// 한 번 열리면 계속 열려 있는 걸쇠. 문을 잡은 쪽을 붙잡아 두는 데만 쓴다.
private final class Latch: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false

    func open() {
        lock.lock()
        isOpen = true
        lock.unlock()
    }

    /// `NSLock.lock()` 은 async 컨텍스트에서 직접 부를 수 없다 — 읽기를 동기 프로퍼티로 뺀다.
    private var opened: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isOpen
    }

    func wait() async {
        while !opened { await Task.yield() }
    }
}

/// 잠금으로 지키는 순서 기록. 테스트 안에서만 쓴다.
private final class OrderLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int] = []

    func append(_ value: Int) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var values: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
