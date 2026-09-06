import Testing
import Foundation
import Darwin
import LanguageKit
@testable import RunnerKit

/// 프로세스를 띄우지 않는 계약 테스트 — 인자 규약과 status fd 문법.
@Suite("런처 ABI")
struct ToolchainLauncherContractTests {
    @Test("argv 는 규약 순서를 지키고 -- 뒤부터가 자식 인자다")
    func argumentVector() {
        let invocation = LauncherInvocation(
            launcherPath: "/helpers/learn-launcher",
            executablePath: "/usr/bin/python3",
            arguments: ["main.py", "--flag"],
            workingDirectory: "/tmp/run-1",
            limits: ResourceLimits(
                wallClockSeconds: 10,
                cpuSeconds: 5,
                memoryMegabytes: 512,
                maxProcesses: 16
            ),
            statusFileDescriptor: 3,
            fileSizeBytes: 1024
        )

        #expect(invocation.argumentVector == [
            "--cpu", "5",
            "--nproc", "16",
            "--fsize", "1024",
            "--wall", "10",
            "--status-fd", "3",
            "--cwd", "/tmp/run-1",
            "--",
            "/usr/bin/python3", "main.py", "--flag",
        ])
        #expect(invocation.commandLine.first == "/helpers/learn-launcher")
    }

    @Test("--cwd 는 지정하지 않으면 argv 에 나타나지 않는다")
    func argumentVectorWithoutWorkingDirectory() {
        let invocation = LauncherInvocation(
            launcherPath: "/l",
            executablePath: "/bin/echo",
            limits: ResourceLimits(wallClockSeconds: 1, cpuSeconds: 1, memoryMegabytes: 1, maxProcesses: 1)
        )
        #expect(!invocation.argumentVector.contains("--cwd"))
    }

    @Test("메모리 상한은 런처 인자로 나가지 않는다 — macOS 는 RLIMIT_AS 를 지원하지 않는다")
    func memoryIsNotAnRlimit() {
        let invocation = LauncherInvocation(
            launcherPath: "/l",
            executablePath: "/bin/echo",
            limits: ResourceLimits(memoryMegabytes: 512)
        )
        #expect(!invocation.argumentVector.contains { $0.contains("mem") })
    }

    @Test("status 라인 5종을 해석한다")
    func statusParsing() {
        #expect(LauncherStatus.parse(line: "SPAWNED 4242 4242") == .spawned(processIdentifier: 4242, processGroup: 4242))
        #expect(LauncherStatus.parse(line: "TIMEOUT") == .timeout)
        #expect(LauncherStatus.parse(line: "EXIT 7") == .exited(code: 7))
        #expect(LauncherStatus.parse(line: "SIGNAL 24") == .signalled(number: 24))
        #expect(LauncherStatus.parse(line: "ERR exec 2") == .launcherError(stage: "exec", errorNumber: 2))
    }

    @Test("망가진 줄과 부분 수신은 조용히 버린다")
    func statusParsingRejectsGarbage() {
        #expect(LauncherStatus.parse(line: "") == nil)
        #expect(LauncherStatus.parse(line: "SPAWNED") == nil)
        #expect(LauncherStatus.parse(line: "EXIT abc") == nil)
        #expect(LauncherStatus.parse(line: "HELLO 1") == nil)

        let statuses = LauncherStatus.parse(stream: "SPAWNED 10 10\nTIMEOUT\nSIG")
        #expect(statuses == [.spawned(processIdentifier: 10, processGroup: 10), .timeout])
    }

    @Test("TIMEOUT 이 벽시계 초과와 사용자 코드의 자체 SIGKILL 을 가른다")
    func timeoutDistinguishesSelfKill() {
        let limits = ResourceLimits(wallClockSeconds: 2, cpuSeconds: 1, memoryMegabytes: 64, maxProcesses: 4)

        let timedOut = LauncherOutcome(statuses: LauncherStatus.parse(stream: """
        SPAWNED 100 100
        TIMEOUT
        SIGNAL 9
        """))
        #expect(timedOut.wallClockExceeded)
        #expect(matches(timedOut.failure(limits: limits), .wallClockExceeded(seconds: 2)))

        let selfKilled = LauncherOutcome(statuses: LauncherStatus.parse(stream: """
        SPAWNED 100 100
        SIGNAL 9
        """))
        #expect(!selfKilled.wallClockExceeded)
        // 사용자가 스스로 죽인 것은 실패가 아니다 — 종료 상태로만 보고한다.
        #expect(matches(selfKilled.failure(limits: limits), nil))
    }

    @Test("SIGXCPU 는 wallClockExceeded 가 아니라 cpuExceeded 로 매핑된다")
    func cpuExceededMapping() {
        let limits = ResourceLimits(wallClockSeconds: 10, cpuSeconds: 5, memoryMegabytes: 64, maxProcesses: 4)
        let outcome = LauncherOutcome(statuses: LauncherStatus.parse(stream: "SPAWNED 1 1\nSIGNAL \(SIGXCPU)"))
        #expect(outcome.cpuExceeded)
        #expect(!outcome.wallClockExceeded)
        #expect(matches(outcome.failure(limits: limits), .cpuExceeded(seconds: 5)))
    }

    @Test("메모리 폴러가 죽였다면 SIGNAL 9 는 memoryExceeded 다")
    func memoryKilledMapping() {
        let limits = ResourceLimits(memoryMegabytes: 256)
        let outcome = LauncherOutcome(statuses: LauncherStatus.parse(stream: "SPAWNED 1 1\nSIGNAL 9"))
        #expect(matches(outcome.failure(limits: limits, memoryKilled: true), .memoryExceeded(megabytes: 256)))
    }

    @Test("ERR 은 런처 자신의 실패이므로 backend 오류로 올라간다")
    func launcherErrorMapping() {
        let outcome = LauncherOutcome(statuses: LauncherStatus.parse(stream: "ERR exec 2"))
        #expect(outcome.launcherFailure == LauncherFailureReport(stage: "exec", errorNumber: 2))
        guard case .backend? = outcome.failure(limits: .lesson) else {
            Issue.record("ERR 은 RunFailure.backend 여야 한다")
            return
        }
    }
}

/// `RunFailure` 는 계약상 `Equatable` 이 아니다 (연관값 비교가 의미 없는 케이스가 있다).
/// 테스트에서만 쓰는 비교자를 따로 둔다 — 계약을 테스트 편의로 넓히지 않는다.
func matches(_ lhs: RunFailure?, _ rhs: RunFailure?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): return true
    case let (.toolchainMissing(a)?, .toolchainMissing(b)?): return a == b
    case let (.wallClockExceeded(a)?, .wallClockExceeded(b)?): return a == b
    case let (.cpuExceeded(a)?, .cpuExceeded(b)?): return a == b
    case let (.memoryExceeded(a)?, .memoryExceeded(b)?): return a == b
    case (.cancelled?, .cancelled?): return true
    case let (.backend(a)?, .backend(b)?): return a == b
    default: return false
    }
}
