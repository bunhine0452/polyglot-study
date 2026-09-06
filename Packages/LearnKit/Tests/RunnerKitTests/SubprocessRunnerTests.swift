import Testing
import Foundation
import Darwin
import LanguageKit
import LearnCore
@testable import RunnerKit

/// `learn-launcher` 를 실제로 띄우는 서브프로세스 백엔드 검증.
@Suite("서브프로세스 러너 실측", .serialized)
struct SubprocessRunnerTests {

    private func shellRunner(
        _ script: String,
        workspaceContainer: URL? = nil
    ) throws -> (SubprocessRunner, RunRequest) {
        let runner = try SubprocessTestSupport.runner(
            program: DirectProgram(executablePath: "/bin/sh", arguments: ["-c", script]),
            workspaceContainer: workspaceContainer
        )
        return (runner, RunRequest(files: []))
    }

    @Test("stdout·stderr·종료 코드가 그대로 전달된다")
    func passesThroughStreamsAndExitCode() async throws {
        let (runner, _) = try shellRunner("printf 'out'; printf 'err' >&2; exit 3")
        let observation = await SubprocessTestSupport.observe(runner, RunRequest(files: []))

        #expect(observation.failure == nil)
        #expect(observation.stdoutText == "out")
        #expect(observation.stderrText == "err")
        #expect(observation.termination?.status == .failed(code: 3))
        // 준비 → 실행 순서는 UI 진행 표시의 전제다.
        #expect(observation.phases == [.preparing, .running])
    }

    @Test("status fd 는 posix_spawn file actions 로 자식에게 도달한다")
    func statusFileDescriptorReachesChild() async throws {
        // 런처가 fd 3 을 못 열면 STAGE_STATUS_FD 로 125 를 내며 죽는다.
        // 성공 종료가 곧 fd 3 배선이 살아 있다는 증거다.
        let (runner, _) = try shellRunner("exit 0")
        let observation = await SubprocessTestSupport.observe(runner, RunRequest(files: []))
        #expect(observation.termination?.succeeded == true)
        #expect(observation.failure == nil)
    }

    @Test("stdin 이 프로그램에 연결된다")
    func standardInputIsConnected() async throws {
        let (runner, _) = try shellRunner("tr 'a-z' 'A-Z'")
        let request = RunRequest(files: [], standardInput: Data("hello\n".utf8))
        let observation = await SubprocessTestSupport.observe(runner, request)
        #expect(observation.stdoutText.contains("HELLO"))
        #expect(observation.termination?.succeeded == true)
    }

    @Test("입력이 없으면 stdin 은 즉시 EOF 다 — 매달리지 않는다")
    func emptyStandardInputClosesImmediately() async throws {
        let (runner, _) = try shellRunner("cat; echo done")
        let observation = await SubprocessTestSupport.observe(runner, RunRequest(files: []))
        #expect(observation.stdoutText.contains("done"))
        #expect(observation.termination?.succeeded == true)
    }

    @Test("stdout·stderr 동시 폭주에도 교착하지 않는다")
    func concurrentStreamsDoNotDeadlock() async throws {
        // 파이프 버퍼는 64KB 다. 한쪽만 읽으면 반대쪽에서 자식이 write 에 매달린다.
        let script = """
            i=0
            while [ $i -lt 200 ]; do
              printf '%01024d\\n' $i
              printf '%01024d\\n' $i >&2
              i=$((i+1))
            done
            """
        let (runner, _) = try shellRunner(script)
        let request = RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 30, outputBytes: 8 << 20))
        let observation = await SubprocessTestSupport.observe(runner, request)

        #expect(observation.failure == nil)
        #expect(observation.termination?.succeeded == true)
        #expect(observation.stdout.count > 200 * 1024)
        #expect(observation.stderr.count > 200 * 1024)
        #expect(!observation.truncated)
    }

    @Test("출력 상한을 넘으면 잘리고 truncated 는 정확히 한 번 온다")
    func outputIsCappedOnce() async throws {
        let (runner, _) = try shellRunner("i=0; while [ $i -lt 4000 ]; do printf '%01024d\\n' $i; i=$((i+1)); done")
        let request = RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 30, outputBytes: 64 * 1024))
        let observation = await SubprocessTestSupport.observe(runner, request)

        #expect(observation.truncated)
        #expect(observation.truncatedCount == 1)
        #expect(observation.stdout.count <= 64 * 1024)
        // 상한 초과 뒤에도 파이프를 계속 비웠으므로 자식은 매달리지 않고 정상 종료한다.
        #expect(observation.termination?.succeeded == true)
        #expect(observation.failure == nil)
    }

    @Test("개행 없는 거대 단일행을 잃지 않는다")
    func hugeSingleLineSurvives() async throws {
        // `.strings()` 의 기본 BufferingPolicy 는 128KB 단일행에서 throw 한다.
        // Buffer 를 직접 세는 경로는 그렇지 않아야 한다.
        let (runner, _) = try shellRunner("i=0; while [ $i -lt 400 ]; do printf '%01024d' $i; i=$((i+1)); done")
        let request = RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 30, outputBytes: 4 << 20))
        let observation = await SubprocessTestSupport.observe(runner, request)

        #expect(observation.longestLineBytes >= 400 * 1024)
        #expect(!observation.truncated)
    }

    @Test("비UTF8 바이트를 손대지 않고 전달한다")
    func nonUTF8BytesSurvive() async throws {
        let (runner, _) = try shellRunner("printf '\\377\\376\\303'")
        let observation = await SubprocessTestSupport.observe(runner, RunRequest(files: []))
        #expect(Array(observation.stdout) == [0xFF, 0xFE, 0xC3])
        #expect(String(data: observation.stdout, encoding: .utf8) == nil)
    }

    @Test("벽시계 초과는 wallClockExceeded 다 — 같은 SIGKILL 이어도 CPU 초과와 구별된다")
    func wallClockExceededIsDistinct() async throws {
        let (runner, _) = try shellRunner("sleep 60")
        let request = RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 1, cpuSeconds: 30))
        let observation = await SubprocessTestSupport.observe(runner, request)
        #expect(observation.failure == .wallClockExceeded(seconds: 1))
        #expect(observation.elapsed < .seconds(8))
    }

    @Test("CPU 초과는 cpuExceeded 다 — 벽시계는 넉넉해도 걸린다")
    func cpuExceededIsDistinct() async throws {
        let (runner, _) = try shellRunner("while :; do :; done")
        let request = RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 60, cpuSeconds: 1))
        let observation = await SubprocessTestSupport.observe(runner, request)
        #expect(observation.failure == .cpuExceeded(seconds: 1))
        #expect(observation.elapsed < .seconds(20))
    }

    @Test("파일 크기 초과는 fileSizeExceeded 다")
    func fileSizeExceeded() async throws {
        // 셸을 끼우면 안 된다 — `sh` 는 SIGXFSZ 로 죽은 자식을 종료코드 153 으로
        // 접어서 보고하고, 런처가 보는 것은 그 153 뿐이라 사인이 한 겹 사라진다.
        // 실제 레슨에서는 사용자 프로그램이 직계 자식이므로 이 경로가 맞다.
        let runner = try SubprocessTestSupport.runner(
            program: DirectProgram(
                executablePath: "/bin/dd",
                arguments: ["if=/dev/zero", "of=big.bin", "bs=65536", "count=1000"]
            )
        )
        let request = RunRequest(
            files: [],
            limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30, fileSizeBytes: 1 << 20)
        )
        let observation = await SubprocessTestSupport.observe(runner, request)
        #expect(observation.failure == .fileSizeExceeded(bytes: 1 << 20))
    }

    @Test("메모리 초과는 memoryExceeded 다 — 폴러만이 이 사인을 안다")
    func memoryExceeded() async throws {
        let python = try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.python)
        let runner = try SubprocessTestSupport.runner(
            program: DirectProgram(
                executablePath: python,
                arguments: ["-I", "-B", "-c", "b=[]\nwhile True:\n    b.append(bytearray(8*1024*1024))\n"]
            )
        )
        let request = RunRequest(
            files: [],
            limits: ResourceLimits(wallClockSeconds: 30, cpuSeconds: 30, memoryMegabytes: 64)
        )
        let observation = await SubprocessTestSupport.observe(runner, request)
        #expect(observation.failure == .memoryExceeded(megabytes: 64))
    }

    @Test("스트림 소비자를 취소하면 1초 안에 프로세스 그룹이 사라진다")
    func cancellationReapsProcessGroupWithinOneSecond() async throws {
        let groups = ObservedProcessGroups()
        var configuration = try SubprocessTestSupport.configuration()
        configuration.processGroupObserver = { groups.record($0) }
        let runner = SubprocessRunner(
            program: DirectProgram(
                executablePath: "/bin/sh",
                arguments: ["-c", "sh -c 'sleep 300' & sleep 300"]
            ),
            configuration: configuration
        )
        let request = RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 120, cpuSeconds: 120))

        let consumer = Task {
            for try await event in runner.run(request) { _ = event }
        }
        // 손자까지 뜨고 나서 취소해야 회수를 재는 의미가 있다.
        let group = try #require(await groups.wait(for: 2, within: .seconds(5)))

        let clock = ContinuousClock()
        let cancelledAt = clock.now
        consumer.cancel()
        _ = try? await consumer.value
        let reacted = cancelledAt.duration(to: clock.now)

        #expect(reacted < .seconds(1), "취소 반응이 \(reacted)")
        #expect(ProcessGroupReaper.waitForVanish(processGroup: group, within: .seconds(1)))
    }

    @Test("손자 프로세스는 그룹째 회수된다 — 잔존 0")
    func grandchildIsReaped() async throws {
        let groups = ObservedProcessGroups()
        var configuration = try SubprocessTestSupport.configuration()
        configuration.processGroupObserver = { groups.record($0) }
        let runner = SubprocessRunner(
            program: DirectProgram(
                executablePath: "/bin/sh",
                arguments: ["-c", "sh -c 'sleep 300' & echo spawned"]
            ),
            configuration: configuration
        )
        let request = RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 5, cpuSeconds: 5))
        let observation = await SubprocessTestSupport.observe(runner, request)

        #expect(observation.stdoutText.contains("spawned"))
        let group = try #require(groups.first)
        // 스트림이 끝난 시점에는 이미 그룹이 비어 있어야 한다. 시그널 회수에는 약간의
        // 지연이 있으므로 단언은 원자적이지 않다는 전제로 짧게 기다린다.
        #expect(ProcessGroupReaper.waitForVanish(processGroup: group, within: .seconds(2)),
                "잔존: \(ProcessGroupMemory.members(ofProcessGroup: group))")
        #expect(observation.elapsed < .seconds(20))
    }

    @Test("실행 디렉터리는 성공·실패 어느 경로로도 남지 않는다")
    func workspacesAreRemoved() async throws {
        let container = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("learnkit-subprocess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: container) }

        for _ in 0..<5 {
            let (ok, _) = try shellRunner("echo hi", workspaceContainer: container)
            _ = await SubprocessTestSupport.observe(ok, RunRequest(files: []))
            let (bad, _) = try shellRunner("sleep 30", workspaceContainer: container)
            _ = await SubprocessTestSupport.observe(
                bad,
                RunRequest(files: [], limits: ResourceLimits(wallClockSeconds: 1))
            )
        }
        #expect(RunWorkspace.residentWorkspaceCount(in: container) == 0)
    }

    @Test("워크스페이스 밖을 가리키는 소스 경로는 스폰 전에 거부된다")
    func escapingSourcePathIsRejected() async throws {
        let (runner, _) = try shellRunner("echo hi")
        let request = RunRequest(files: [SourceFile(path: "../escape.txt", contents: "x")])
        let observation = await SubprocessTestSupport.observe(runner, request)
        guard case .backend = observation.failure else {
            Issue.record("경로 거부가 backend 실패로 오지 않았다: \(String(describing: observation.failure))")
            return
        }
    }

    @Test("8 개를 동시에 돌려도 서로 간섭하지 않는다")
    func parallelRunsDoNotInterfere() async throws {
        let results = await withTaskGroup(of: (Int, String).self) { group in
            for index in 0..<8 {
                group.addTask {
                    guard let runner = try? SubprocessTestSupport.runner(
                        program: DirectProgram(
                            executablePath: "/bin/sh",
                            arguments: ["-c", "printf 'run-\(index)'; exit \(index)"]
                        )
                    ) else { return (index, "<러너 생성 실패>") }
                    let observation = await SubprocessTestSupport.observe(runner, RunRequest(files: []))
                    let code = observation.termination?.exitCode.map(String.init) ?? "nil"
                    return (index, "\(observation.stdoutText)/\(code)")
                }
            }
            var collected: [(Int, String)] = []
            for await value in group { collected.append(value) }
            return collected
        }

        for (index, text) in results {
            let expected = index == 0 ? "run-0/0" : "run-\(index)/\(index)"
            #expect(text == expected, "\(index) 번 실행이 다른 실행의 출력을 봤다: \(text)")
        }
    }
}

/// 러너가 알려 온 자식 프로세스 그룹을 모은다.
///
/// 그룹 번호는 계약이 내보내는 값이 아니라 `SubprocessRunnerConfiguration` 의
/// 관측 훅으로만 온다 — 누수 검사를 위한 통로다.
final class ObservedProcessGroups: @unchecked Sendable {
    private let lock = NSLock()
    private var groups: [Int32] = []

    func record(_ group: Int32) {
        lock.lock()
        if !groups.contains(group) { groups.append(group) }
        lock.unlock()
    }

    var all: [Int32] {
        lock.lock()
        defer { lock.unlock() }
        return groups
    }

    var first: Int32? { all.first }

    /// 그룹이 관측되고, 그 안의 프로세스가 `members` 개 이상이 될 때까지 기다린다.
    func wait(for members: Int, within limit: Duration) async -> Int32? {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if let group = first,
               ProcessGroupMemory.members(ofProcessGroup: group).count >= members {
                return group
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return first
    }
}
