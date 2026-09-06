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
                fileSizeBytes: 1024,
                maxProcesses: 16
            ),
            statusFileDescriptor: 3
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

    @Test("--fsize 는 ResourceLimits 에서 온다 — 런처가 임의 기본값을 만들지 않는다")
    func fileSizeComesFromLimits() {
        let invocation = LauncherInvocation(
            launcherPath: "/l",
            executablePath: "/bin/echo",
            limits: ResourceLimits(fileSizeBytes: 7 << 20)
        )
        let argv = invocation.argumentVector
        let index = try! #require(argv.firstIndex(of: "--fsize"))
        #expect(argv[index + 1] == String(7 << 20))

        // 기본값도 계약에서 온다 — 64MiB.
        let defaulted = LauncherInvocation(launcherPath: "/l", executablePath: "/bin/echo")
        let defaultIndex = try! #require(defaulted.argumentVector.firstIndex(of: "--fsize"))
        #expect(defaulted.argumentVector[defaultIndex + 1] == String(64 << 20))
    }

    @Test("SIGXFSZ 는 fileSizeExceeded 로 매핑된다 — 멈춘 코드가 아니라 큰 출력이다")
    func fileSizeExceededMapping() {
        let limits = ResourceLimits(wallClockSeconds: 10, fileSizeBytes: 4096)
        let outcome = LauncherOutcome(statuses: LauncherStatus.parse(stream: "SPAWNED 1 1\nSIGNAL \(SIGXFSZ)"))
        #expect(outcome.fileSizeExceeded)
        #expect(!outcome.wallClockExceeded)
        #expect(!outcome.cpuExceeded)
        #expect(outcome.failure(limits: limits) == .fileSizeExceeded(bytes: 4096))
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
        #expect(timedOut.failure(limits: limits) == .wallClockExceeded(seconds: 2))

        let selfKilled = LauncherOutcome(statuses: LauncherStatus.parse(stream: """
        SPAWNED 100 100
        SIGNAL 9
        """))
        #expect(!selfKilled.wallClockExceeded)
        // 사용자가 스스로 죽인 것은 실패가 아니다 — 종료 상태로만 보고한다.
        #expect(selfKilled.failure(limits: limits) == nil)
    }

    @Test("SIGXCPU 는 wallClockExceeded 가 아니라 cpuExceeded 로 매핑된다")
    func cpuExceededMapping() {
        let limits = ResourceLimits(wallClockSeconds: 10, cpuSeconds: 5, memoryMegabytes: 64, maxProcesses: 4)
        let outcome = LauncherOutcome(statuses: LauncherStatus.parse(stream: "SPAWNED 1 1\nSIGNAL \(SIGXCPU)"))
        #expect(outcome.cpuExceeded)
        #expect(!outcome.wallClockExceeded)
        #expect(outcome.failure(limits: limits) == .cpuExceeded(seconds: 5))
    }

    @Test("메모리 폴러가 죽였다면 SIGNAL 9 는 memoryExceeded 다")
    func memoryKilledMapping() {
        let limits = ResourceLimits(memoryMegabytes: 256)
        let outcome = LauncherOutcome(statuses: LauncherStatus.parse(stream: "SPAWNED 1 1\nSIGNAL 9"))
        #expect(outcome.failure(limits: limits, memoryKilled: true) == .memoryExceeded(megabytes: 256))
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

@Suite("RunFailure 동일성")
struct RunFailureEqualityTests {
    @Test("계약이 Equatable 을 제공한다 — 테스트마다 비교자를 다시 쓰지 않는다")
    func equatable() {
        #expect(RunFailure.wallClockExceeded(seconds: 2) == .wallClockExceeded(seconds: 2))
        #expect(RunFailure.wallClockExceeded(seconds: 2) != .wallClockExceeded(seconds: 3))
        // 멈춘 코드와 느린 코드는 초가 같아도 다른 실패다.
        #expect(RunFailure.wallClockExceeded(seconds: 2) != .cpuExceeded(seconds: 2))
        #expect(RunFailure.fileSizeExceeded(bytes: 4096) == .fileSizeExceeded(bytes: 4096))
        #expect(RunFailure.fileSizeExceeded(bytes: 4096) != .memoryExceeded(megabytes: 4096))
        #expect(RunFailure.cancelled == .cancelled)
        #expect(RunFailure.backend("a") != .backend("b"))
        #expect(RunFailure.toolchainMissing(hint: "brew") == .toolchainMissing(hint: "brew"))
    }
}
