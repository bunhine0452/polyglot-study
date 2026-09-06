import Testing
import Foundation
import Darwin
import LanguageKit
@testable import RunnerKit

/// macOS 에서 메모리 상한을 거는 **유일한** 길의 실측.
/// `RLIMIT_AS` / `RLIMIT_DATA` 는 EINVAL 이라 rlimit 경로가 없다.
@Suite("프로세스 그룹 메모리", .serialized)
struct ToolchainMemoryTests {
    @Test("RLIMIT_AS 와 RLIMIT_DATA 는 macOS 에서 걸리지 않는다")
    func addressSpaceLimitsAreUnsupported() {
        // 이 전제가 깨지면 폴러 전체가 불필요해진다 — 그때 알아채야 한다.
        var current = rlimit()
        #expect(getrlimit(RLIMIT_AS, &current) == 0)
        var attempt = rlimit(rlim_cur: 256 << 20, rlim_max: 256 << 20)
        let result = setrlimit(RLIMIT_AS, &attempt)
        #expect(result != 0, "RLIMIT_AS 가 설정됐다 — macOS 동작이 바뀌었다")
        #expect(errno == EINVAL)
    }

    @Test("자기 프로세스 그룹을 열거하고 실제 사용량을 잰다")
    func measuresOwnProcessGroup() {
        let group = getpgrp()
        let members = ProcessGroupMemory.members(ofProcessGroup: group)
        #expect(members.contains(getpid()))

        let own = ProcessGroupMemory.physicalFootprintBytes(ofProcess: getpid())
        #expect((own ?? 0) > 0)

        let total = ProcessGroupMemory.physicalFootprintBytes(ofProcessGroup: group)
        #expect(total >= (own ?? 0), "그룹 합계가 자기 자신보다 작을 수 없다")
    }

    @Test("존재하지 않는 그룹은 빈 목록")
    func unknownGroupIsEmpty() {
        #expect(ProcessGroupMemory.members(ofProcessGroup: 0).isEmpty)
        #expect(ProcessGroupMemory.members(ofProcessGroup: -1).isEmpty)
        #expect(ProcessGroupMemory.physicalFootprintBytes(ofProcessGroup: 999_999) == 0)
    }

    @Test("죽은 pid 의 사용량은 nil")
    func deadProcessHasNoFootprint() {
        #expect(ProcessGroupMemory.physicalFootprintBytes(ofProcess: 999_999) == nil)
    }

    @Test("상한 0 이면 감시하지 않는다")
    func zeroLimitDoesNothing() async {
        let enforcer = MemoryLimitEnforcer(megabytes: 0)
        #expect(await enforcer.watch(processGroup: getpgrp()) == false)
    }

    @Test("그룹이 상한을 넘으면 killpg 한다", .timeLimit(.minutes(1)))
    func killsProcessGroupOverLimit() async throws {
        let python = "/usr/bin/python3"
        try #require(FileManager.default.isExecutableFile(atPath: python))

        // 256MB 를 채우고 60초 붙잡고 있는다.
        let program = """
        import time
        blocks = []
        for _ in range(32):
            blocks.append(bytearray(8 * 1024 * 1024))
        time.sleep(60)
        """
        let invocation = try ToolchainLauncherHarness.invocation(
            program: python,
            arguments: ["-I", "-B", "-c", program],
            wallClockSeconds: 30
        )

        let observed = ObservedGroup()
        let runner = Task.detached {
            try ToolchainLauncherHarness.run(invocation) { group in
                observed.set(group)
            }
        }

        // SPAWNED 를 볼 때까지 기다린다.
        var group: Int32?
        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if let value = observed.value { group = value; break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let processGroup = try #require(group, "SPAWNED 라인을 받지 못했다")

        let enforcer = MemoryLimitEnforcer(megabytes: 64, interval: .milliseconds(50))
        let killed = await enforcer.watch(processGroup: processGroup)
        #expect(killed, "256MB 를 쓰는 그룹이 64MB 상한에 걸리지 않았다")

        let run = try await runner.value
        #expect(run.outcome.termination == .signalled(number: SIGKILL))
        // 폴러가 죽였음을 아는 것은 호출자뿐 — 런처는 TIMEOUT 을 쓰지 않았다.
        #expect(!run.outcome.wallClockExceeded)
        #expect(matches(
            run.outcome.failure(limits: ResourceLimits(memoryMegabytes: 64), memoryKilled: true),
            .memoryExceeded(megabytes: 64)
        ))
        #expect(ToolchainLauncherHarness.waitForProcessGroupToVanish(processGroup))
    }

    @Test("상한 아래로만 쓰는 그룹은 죽이지 않는다", .timeLimit(.minutes(1)))
    func leavesWellBehavedGroupAlone() async throws {
        let invocation = try ToolchainLauncherHarness.invocation(
            program: "/bin/sleep",
            arguments: ["2"],
            wallClockSeconds: 20
        )
        let observed = ObservedGroup()
        let runner = Task.detached {
            try ToolchainLauncherHarness.run(invocation) { group in
                observed.set(group)
            }
        }
        var group: Int32?
        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if let value = observed.value { group = value; break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let processGroup = try #require(group)

        let enforcer = MemoryLimitEnforcer(megabytes: 512, interval: .milliseconds(50))
        // 그룹이 스스로 끝나면 false 를 돌려주고 빠져나온다.
        #expect(await enforcer.watch(processGroup: processGroup) == false)

        let run = try await runner.value
        #expect(run.outcome.termination == .exited(code: 0))
    }
}

final class ObservedGroup: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Int32?

    var value: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ group: Int32) {
        lock.lock()
        storage = group
        lock.unlock()
    }
}
