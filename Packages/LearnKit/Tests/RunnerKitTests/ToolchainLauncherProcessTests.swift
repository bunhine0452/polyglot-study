import Testing
import Foundation
import Darwin
import LanguageKit
@testable import RunnerKit

/// 런처를 **실제로 돌려서** 격리가 동작하는지 확인한다.
/// 여기 있는 것 중 모킹으로 대체 가능한 건 하나도 없다 — rlimit·setsid·killpg 는
/// 커널이 하는 일이라 커널에게 물어보는 수밖에 없다.
@Suite("런처 실측", .serialized)
struct ToolchainLauncherProcessTests {
    @Test("자식의 정상 종료코드를 그대로 전달한다")
    func propagatesExitCode() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(program: "/bin/sh", arguments: ["-c", "exit 7"])
        )
        #expect(run.outcome.termination == .exited(code: 7))
        #expect(run.launcherExitCode == 7)
        #expect(run.launcherSignal == nil)
        #expect(!run.outcome.wallClockExceeded)
    }

    @Test("stdout 이 그대로 흐르고 status fd 는 오염시키지 않는다")
    func passesThroughOutput() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(program: "/bin/echo", arguments: ["hello", "learner"])
        )
        #expect(run.standardOutput == "hello learner\n")
        #expect(run.statusText.contains("SPAWNED "))
        #expect(run.statusText.contains("EXIT 0"))
        #expect(!run.standardOutput.contains("SPAWNED"))
    }

    @Test("자식은 새 세션의 프로세스 그룹 리더가 된다")
    func childLeadsItsOwnGroup() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(program: "/bin/echo", arguments: ["x"])
        )
        // setsid 가 성공하면 pgid == pid. 이게 깨지면 killpg 가 앱 자신을 때린다.
        #expect(run.outcome.processIdentifier != nil)
        #expect(run.outcome.processGroup == run.outcome.processIdentifier)
        #expect(run.outcome.processGroup != getpgrp())
    }

    @Test("무한 루프는 --cpu 상한에서 SIGXCPU 로 죽는다")
    func cpuLimitKillsBusyLoop() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(
                program: "/bin/sh",
                arguments: ["-c", "while :; do :; done"],
                cpuSeconds: 1,
                wallClockSeconds: 30
            )
        )
        #expect(run.outcome.termination == .signalled(number: SIGXCPU))
        #expect(run.outcome.cpuExceeded)
        // 벽시계가 아니라 CPU 로 죽은 것이어야 한다.
        #expect(!run.outcome.wallClockExceeded)
        #expect(run.outcome.failure(limits: ResourceLimits(cpuSeconds: 1)) == .cpuExceeded(seconds: 1))
        #expect(run.elapsed < .seconds(10))
    }

    @Test("sleep 60 은 --wall 2 에 프로세스 그룹째 사라진다")
    func wallClockKillsProcessGroup() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(program: "/bin/sleep", arguments: ["60"], wallClockSeconds: 2)
        )
        #expect(run.outcome.wallClockExceeded)
        #expect(run.outcome.termination == .signalled(number: SIGKILL))
        #expect(run.elapsed < .seconds(5))
        #expect(run.elapsed > .milliseconds(1500))

        let group = try #require(run.outcome.processGroup)
        #expect(ToolchainLauncherHarness.waitForProcessGroupToVanish(group))
    }

    @Test("손자 프로세스도 그룹째 정리된다 — 벽시계 초과 경로")
    func killsGrandchildrenOnTimeout() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(
                program: "/bin/sh",
                arguments: ["-c", "sleep 120 & echo $!; sleep 120"],
                wallClockSeconds: 2
            )
        )
        #expect(run.outcome.wallClockExceeded)
        let grandchild = try #require(Int32(run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)))
        let group = try #require(run.outcome.processGroup)
        #expect(ToolchainLauncherHarness.waitForProcessGroupToVanish(group))
        #expect(!ToolchainLauncherHarness.processExists(grandchild))
    }

    @Test("자식이 정상 종료해도 남은 손자는 그룹째 정리된다")
    func killsOrphanedGrandchildrenOnNormalExit() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(
                program: "/bin/sh",
                arguments: ["-c", "sleep 120 & echo $!"],
                wallClockSeconds: 30
            )
        )
        #expect(run.outcome.termination == .exited(code: 0))
        let orphan = try #require(Int32(run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)))
        let group = try #require(run.outcome.processGroup)
        #expect(ToolchainLauncherHarness.waitForProcessGroupToVanish(group))
        #expect(!ToolchainLauncherHarness.processExists(orphan))
    }

    @Test("fork bomb 은 --nproc 헤드룸에서 막힌다")
    func forkBombIsCapped() throws {
        let python = "/usr/bin/python3"
        try #require(FileManager.default.isExecutableFile(atPath: python))

        let program = """
        import os, sys, time
        made = 0
        try:
            while made < 400:
                if os.fork() == 0:
                    time.sleep(20)
                    os._exit(0)
                made += 1
        except OSError:
            pass
        sys.stdout.write(str(made))
        sys.stdout.flush()
        os._exit(0)
        """
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(
                program: python,
                arguments: ["-I", "-B", "-c", program],
                wallClockSeconds: 30,
                maxProcesses: 8
            )
        )
        let made = try #require(Int(run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)))
        // 커널 회계와 우리 집계가 몇 개 어긋나므로 정확히 8 은 아니다. 400 이 아니면 된다.
        #expect(made < 64, "fork 가 \(made) 번 성공했다 — RLIMIT_NPROC 이 걸리지 않았다")
        #expect(made > 0)

        let group = try #require(run.outcome.processGroup)
        #expect(ToolchainLauncherHarness.waitForProcessGroupToVanish(group))
    }

    @Test("--fsize 초과는 SIGXFSZ")
    func fileSizeLimit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("learnkit-fsize-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(
                program: "/bin/dd",
                arguments: ["if=/dev/zero", "of=big.bin", "bs=1024", "count=1000"],
                wallClockSeconds: 20,
                fileSizeBytes: 4096,
                workingDirectory: directory.path
            )
        )
        #expect(run.outcome.termination == .signalled(number: SIGXFSZ))
        #expect(run.outcome.fileSizeExceeded)
        #expect(
            run.outcome.failure(limits: ResourceLimits(fileSizeBytes: 4096))
                == .fileSizeExceeded(bytes: 4096)
        )

        let written = try FileManager.default.attributesOfItem(
            atPath: directory.appendingPathComponent("big.bin").path
        )[.size] as? Int
        #expect(written == 4096)
    }

    @Test("--cwd 가 자식의 작업 디렉터리를 바꾼다")
    func changesWorkingDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("learnkit-cwd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(program: "/bin/pwd", workingDirectory: directory.path)
        )
        let reported = run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        // `/var` 와 `/private/var` 처럼 표기가 갈리므로 경로 문자열이 아니라 신원으로 비교한다.
        #expect(FileIdentity.of(path: reported) == FileIdentity.of(path: directory.path))
        #expect(reported.hasSuffix(directory.lastPathComponent))
    }

    @Test("런처 자신의 실패만 ERR 과 종료코드 125 로 보고된다")
    func launcherOwnFailureIsDistinct() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(program: "/nonexistent/learnkit/binary")
        )
        #expect(run.launcherExitCode == 125)
        #expect(run.outcome.launcherFailure?.stage == "exec")
        #expect(run.outcome.launcherFailure?.errorNumber == ENOENT)
        // 사용자 코드가 시작조차 못 했으므로 종료 상태는 없다.
        #expect(run.outcome.termination == nil)
        #expect(run.outcome.processIdentifier == nil)
    }

    @Test("잘못된 작업 디렉터리는 exec 전 단계 실패로 보고된다")
    func badWorkingDirectoryIsReported() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(
                program: "/bin/echo",
                workingDirectory: "/nonexistent/learnkit/dir"
            )
        )
        #expect(run.launcherExitCode == 125)
        #expect(run.outcome.launcherFailure?.stage == "chdir")
        #expect(run.outcome.launcherFailure?.errorNumber == ENOENT)
    }

    @Test("자식은 status fd 를 볼 수 없다 — 위조 불가")
    func statusFileDescriptorIsNotInherited() throws {
        // fd 3 에 쓰려 시도하고 실패하면 0, 성공하면 1 을 남긴다.
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(
                program: "/bin/sh",
                arguments: ["-c", "echo 'SPAWNED 1 1' >&3 2>/dev/null && echo forged || echo blocked"],
                wallClockSeconds: 10
            )
        )
        #expect(run.standardOutput.contains("blocked"))
        #expect(!run.statusText.contains("SPAWNED 1 1"))
    }

    @Test("상한을 전부 0 으로 두면 무제한으로 동작한다")
    func zeroMeansUnlimited() throws {
        let run = try ToolchainLauncherHarness.run(
            ToolchainLauncherHarness.invocation(program: "/bin/sleep", arguments: ["1"])
        )
        #expect(run.outcome.termination == .exited(code: 0))
        #expect(!run.outcome.wallClockExceeded)
    }
}
