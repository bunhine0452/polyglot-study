public import Foundation
public import LanguageKit
internal import LearnCore
internal import Subprocess
internal import System
internal import Darwin

/// 서브프로세스 백엔드 설정.
public struct SubprocessRunnerConfiguration: Sendable {
    /// `learn-launcher` 절대경로. nil 이면 `LauncherLocator` 가 찾는다.
    public var launcherPath: String?
    /// 워크스페이스 상위 디렉터리. 테스트가 잔여물을 세려고 주입한다.
    public var workspaceContainer: URL?
    /// 자식에게 물려줄 기본 환경. **상속하지 않는다** — 앱 환경이 그대로 새면
    /// 사용자 코드가 앱의 토큰·캐시 경로를 보게 된다.
    public var environment: [String: String]
    /// 메모리 폴링 주기.
    public var memoryPollInterval: Duration
    /// 취소 teardown 에서 SIGTERM 과 SIGKILL 사이의 유예.
    public var teardownGrace: Duration
    /// 실행 후 프로세스 그룹이 사라지기를 기다리는 상한.
    public var reapTimeout: Duration
    /// 런처가 `SPAWNED` 로 알려 온 자식 프로세스 그룹을 실행 중에 넘겨준다.
    ///
    /// 그룹 번호는 계약에 없는 값이라 이벤트로 내보내지 않는다. 하지만 "실행이 끝난 뒤
    /// 잔존 프로세스 0" 을 재려면 어떤 그룹을 봐야 하는지 알아야 한다 —
    /// 누수 회귀 테스트를 위한 통로다(`SQLRunnerConfiguration.cloneObserver` 와 같은 자리).
    public var processGroupObserver: (@Sendable (Int32) -> Void)?

    public init(
        launcherPath: String? = nil,
        workspaceContainer: URL? = nil,
        environment: [String: String] = SubprocessRunnerConfiguration.defaultEnvironment,
        memoryPollInterval: Duration = .milliseconds(50),
        teardownGrace: Duration = .milliseconds(150),
        reapTimeout: Duration = .seconds(2),
        processGroupObserver: (@Sendable (Int32) -> Void)? = nil
    ) {
        self.launcherPath = launcherPath
        self.workspaceContainer = workspaceContainer
        self.environment = environment
        self.memoryPollInterval = memoryPollInterval
        self.teardownGrace = teardownGrace
        self.reapTimeout = reapTimeout
        self.processGroupObserver = processGroupObserver
    }

    /// 최소 환경. `HOME` 과 `TMPDIR` 은 실행마다 워크스페이스로 덮어쓴다.
    ///
    /// `PYTHON*` 계열이 없는 것은 실수가 아니다 — 있으면 사용자 site-packages 가
    /// 딸려 들어온다. Python 어댑터는 `-I` 로 한 번 더 막지만, 환경을 안 물려주는
    /// 것이 첫 번째 방어다.
    public static let defaultEnvironment: [String: String] = [
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "LANG": "en_US.UTF-8",
        "LC_ALL": "en_US.UTF-8",
    ]
}

/// `learn-launcher` 를 통해 사용자 코드를 별도 프로세스로 실행하는 백엔드.
///
/// 격리는 다섯 겹이다.
///   1. 실행마다 새 `RunWorkspace` — 절대경로·상위 참조는 스폰 전에 거부된다.
///   2. 런처가 `setsid` 후 `RLIMIT_CPU`/`NPROC`/`FSIZE` 를 걸고 `execv`.
///   3. 벽시계 초과는 런처가 프로세스 그룹째 `killpg`.
///   4. 메모리는 부모가 `proc_pid_rusage` 로 그룹을 폴링해 `killpg` — macOS 에는
///      `RLIMIT_AS` 가 없다.
///   5. 취소는 `teardownSequence` 로 런처를 때리고, 런처가 그룹을 데려간다.
public struct SubprocessRunner: CodeRunner {
    public var program: any SubprocessProgram
    public var configuration: SubprocessRunnerConfiguration

    public init(
        program: any SubprocessProgram,
        configuration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration()
    ) {
        self.program = program
        self.configuration = configuration
    }

    public var capabilities: RunnerCapabilities { program.capabilities }

    /// 여섯 축 전부를 실제로 막는다. 이 백엔드가 존재하는 이유가 그것이다.
    public var enforcedLimits: EnforcedLimits { .all }

    // MARK: - CodeRunner

    public func run(_ request: RunRequest) -> AsyncThrowingStream<RunEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task { await execute(request, into: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func execute(
        _ request: RunRequest,
        into continuation: AsyncThrowingStream<RunEvent, any Error>.Continuation
    ) async {
        do {
            continuation.yield(.phase(.preparing))
            let launcherPath = try resolveLauncherPath()
            let termination = try await RunWorkspace.withWorkspace(
                files: request.files,
                container: configuration.workspaceContainer
            ) { workspace in
                let preparation = try await program.prepare(
                    request: request,
                    workspace: workspace,
                    emit: { continuation.yield($0) }
                )
                // 준비 단계에서 끝났다면 `.running` 은 오면 안 된다 — 돌지 않은 것을
                // 돌았다고 보고하면 제출 이력의 duration 이 거짓이 된다.
                guard case .run(let invocation) = preparation else {
                    if case .finished(let termination) = preparation { return termination }
                    throw RunFailure.backend("준비 단계가 결론을 내지 않았다")
                }
                // 컴파일 단계가 있었다면 `.compiling` 은 이미 지나갔다.
                // `.running` 은 항상 그 뒤다 — 순서가 뒤집히면 UI 가 진행 표시를 되감는다.
                continuation.yield(.phase(.running))
                return try await launch(
                    invocation: invocation,
                    launcherPath: launcherPath,
                    request: request,
                    workspace: workspace,
                    continuation: continuation
                )
            }
            continuation.yield(.finished(termination))
            continuation.finish()
        } catch let failure as RunFailure {
            continuation.finish(throwing: failure)
        } catch let error as WorkspaceError {
            continuation.finish(throwing: RunFailure.backend(error.description))
        } catch is CancellationError {
            continuation.finish(throwing: RunFailure.cancelled)
        } catch {
            continuation.finish(throwing: RunFailure.backend("\(error)"))
        }
    }

    func resolveLauncherPath() throws -> String {
        if let launcherPath = configuration.launcherPath {
            guard FileManager.default.isExecutableFile(atPath: launcherPath) else {
                throw RunFailure.toolchainMissing(hint: "learn-launcher 가 \(launcherPath) 에 없다.")
            }
            return launcherPath
        }
        return try LauncherLocator.locate().path
    }

    // MARK: - 실행

    private func launch(
        invocation: SubprocessInvocation,
        launcherPath: String,
        request: RunRequest,
        workspace: RunWorkspace,
        continuation: AsyncThrowingStream<RunEvent, any Error>.Continuation
    ) async throws -> RunTermination {
        let channel = try LauncherStatusChannel()
        let groupBox = ProcessGroupBox()
        defer {
            channel.shutdown()
            // 런처가 SIGKILL 을 맞았다면 스스로 그룹을 정리할 기회가 없었다.
            // 성공·실패·타임아웃·취소 네 경로 전부가 이 한 줄을 지난다.
            if let group = groupBox.value {
                ProcessGroupReaper.reap(processGroup: group, within: configuration.reapTimeout)
            }
        }

        let workingDirectory = invocation.workingDirectory ?? workspace.root.path
        let launcherInvocation = LauncherInvocation(
            launcherPath: launcherPath,
            executablePath: invocation.executablePath,
            arguments: invocation.arguments,
            workingDirectory: workingDirectory,
            limits: request.limits,
            statusFileDescriptor: channel.childFileDescriptor
        )

        let budget = OutputBudget(limit: request.limits.outputBytes)
        let clock = ContinuousClock()
        let started = clock.now
        var outcome = SubprocessRunOutcome(launcher: LauncherOutcome())

        do {
            let result = try await withTaskCancellationHandler {
                try await Subprocess.run(
                    .path(FilePath(launcherPath)),
                    arguments: Arguments(launcherInvocation.argumentVector),
                    environment: .custom(childEnvironment(invocation, workspace: workspace)),
                    workingDirectory: FilePath(workingDirectory),
                    platformOptions: platformOptions(channel: channel),
                    // stdin 은 항상 파이프다. 입력이 없어도 EOF 를 즉시 보여주는 것이
                    // 터미널을 물려주는 것보다 안전하다.
                    input: .inputWriter,
                    output: .sequence,
                    error: .sequence
                ) { execution in
                    // 스폰이 끝났다. 부모 쪽 쓰기 끝을 닫아야 status 읽기가 EOF 를 본다.
                    channel.closeWriteEnd()
                    // 그룹 기록을 **드레인 시작 전에** 걸어 둔다. 아래 watcher 는 출력
                    // 드레인이 끝나면 취소되는데, 즉시 끝나는 프로그램에서는 그 취소가
                    // SPAWNED 파싱을 앞지를 수 있다. 그때 groupBox 가 비면 회수 defer 도
                    // onCancel 킬러도 때릴 그룹을 모른다 — 손자가 그대로 남는다.
                    let observer = configuration.processGroupObserver
                    channel.onSpawn { _, group in
                        groupBox.set(group)
                        observer?(group)
                    }
                    channel.startDraining()

                    // 그룹 기록은 위 onSpawn 이 이미 했다. 이 Task 가 남은 이유는
                    // 메모리 상한 감시뿐이고, 그래서 취소돼도 안전하다.
                    let watcher = Task { () -> Bool in
                        guard request.limits.memoryMegabytes > 0 else { return false }
                        guard let spawned = await channel.awaitSpawn(within: .seconds(5)) else {
                            return false
                        }
                        return await MemoryLimitEnforcer(
                            megabytes: request.limits.memoryMegabytes,
                            interval: configuration.memoryPollInterval
                        ).watch(processGroup: spawned.processGroup)
                    }
                    let nudge = Task {
                        await Self.nudgeLauncher(
                            channel: channel,
                            launcherProcessIdentifier: execution.processIdentifier.value,
                            interval: configuration.memoryPollInterval
                        )
                    }

                    // stdout·stderr·stdin 세 갈래를 **동시에** 돌린다. 하나라도 순서를
                    // 세우면 64KB 파이프 버퍼에서 교착한다 — 자식이 stdout 에 매달려
                    // stdin 을 안 읽고, 우리는 stdin 을 쓰느라 stdout 을 안 비운다.
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await Self.feedStandardInput(execution, request.standardInput)
                        }
                        group.addTask {
                            await Self.drain(
                                execution.standardOutput,
                                budget: budget,
                                isError: false,
                                continuation: continuation
                            )
                        }
                        group.addTask {
                            await Self.drain(
                                execution.standardError,
                                budget: budget,
                                isError: true,
                                continuation: continuation
                            )
                        }
                    }

                    // 두 감시자 모두 **본문이 끝나기 전에** 반드시 멈춰야 한다.
                    // 런처 pid 는 `Subprocess.run` 이 거두기 전까지만 재사용되지 않으므로,
                    // 이 지점을 넘겨 살아 있으면 남의 프로세스에 시그널을 보낼 수 있다.
                    nudge.cancel()
                    await nudge.value
                    watcher.cancel()
                    return await watcher.value
                }
            } onCancel: {
                // teardown 은 런처를 향한다. 손자까지 확실히 데려가려면 우리가 아는
                // 그룹도 직접 때린다 — 런처가 SIGKILL 을 먼저 맞으면 정리를 못 한다.
                if let group = groupBox.value { ProcessGroupReaper.kill(processGroup: group) }
            }

            outcome.memoryKilled = result.closureResult
            outcome.launcherTermination = result.terminationStatus
        } catch {
            if Task.isCancelled || error is CancellationError { throw RunFailure.cancelled }
            throw RunFailure.fromBackend(error, executablePath: invocation.executablePath)
        }

        // 런처가 죽었으니 status 파이프도 곧 EOF 다. 마지막 `EXIT`/`SIGNAL` 줄이
        // 도착할 시간을 짧게 준다 — 이 줄이 없으면 사인이 한 단계 흐려진다.
        await channel.waitForDrain(within: .milliseconds(500))

        outcome.launcher = channel.outcome
        outcome.cancelled = Task.isCancelled
        outcome.durationMilliseconds = Int(started.duration(to: clock.now).milliseconds)
        return try outcome.resolve(limits: request.limits, executablePath: invocation.executablePath)
    }

    private func platformOptions(channel: LauncherStatusChannel) -> PlatformOptions {
        var options = PlatformOptions()
        // 런처를 **자기만의 프로세스 그룹**에 둔다. 이게 없으면 그룹 대상 teardown 이
        // 우리 자신(앱)까지 때린다 — swift-subprocess 문서가 경고하는 바로 그 함정이다.
        options.processGroupID = 0
        options.teardownSequence = [
            .send(
                signal: .terminate,
                toProcessGroup: true,
                allowedDurationToNextStep: configuration.teardownGrace
            )
        ]
        let statusWriteEnd = channel.inheritableWriteEnd
        let statusTarget = channel.childFileDescriptor
        options.preSpawnProcessConfigurator = { _, fileActions in
            // `Foundation.Process` 로는 여기까지 올 수 없다 — 0·1·2 밖의 fd 를 물려줄
            // 방법이 없기 때문이다. `POSIX_SPAWN_CLOEXEC_DEFAULT` 아래에서도 file
            // actions 에 적힌 fd 는 살아남고, dup2 사본은 CLOEXEC 가 지워진다.
            let result = posix_spawn_file_actions_adddup2(&fileActions, statusWriteEnd, statusTarget)
            guard result == 0 else {
                throw RunFailure.backend("status fd 배선 실패: errno \(result)")
            }
        }
        return options
    }

    private func childEnvironment(
        _ invocation: SubprocessInvocation,
        workspace: RunWorkspace
    ) -> [Environment.Key: String] {
        var environment = configuration.environment
        // 홈과 임시 디렉터리를 워크스페이스로 돌린다. 워크스페이스는 실행이 끝나면
        // 통째로 사라지므로 사용자 코드가 남길 수 있는 흔적이 한 곳에 모인다.
        environment["HOME"] = workspace.root.path
        environment["TMPDIR"] = workspace.root.path
        for (key, value) in invocation.environmentOverrides {
            if let value {
                environment[key] = value
            } else {
                environment.removeValue(forKey: key)
            }
        }
        return Dictionary(
            uniqueKeysWithValues: environment.map { (Environment.Key(stringLiteral: $0.key), $0.value) }
        )
    }

    // MARK: - 세 갈래 소비

    /// 런처가 자식의 종료를 **놓쳤을 때** 깨워 준다.
    ///
    /// 실측(2026-09-06): 8개를 동시에 돌리면 실행당 3% 안팎으로 런처가 자식의 종료를
    /// 즉시 알아채지 못하고 `--wall` 데드라인까지 통째로 잠든다. 깨어난 뒤에는
    /// `waitpid` 로 정상 회수하므로 **종료 코드와 status 라인은 정확하다** — 생기는
    /// 것은 오직 지연이다(30ms 짜리 프로그램이 30초로 관측된다).
    ///
    /// 방아쇠는 이쪽의 메모리 폴러다. `proc_listpids`/`proc_pid_rusage` 로 자식을
    /// 들여다보는 동안 런처의 `EVFILT_PROC`/`NOTE_EXIT` 가 도착하지 않는 경우가 있다
    /// (폴러를 끄면 192회 연속 재현되지 않고, 켜면 다시 나온다). 폴러는 macOS 에서
    /// 메모리 상한을 거는 **유일한 수단**이라 뺄 수 없다.
    ///
    /// 근본 수정은 런처 쪽이다 — `main.c` 의 `kevent` 대기를 `remaining` 전체가 아니라
    /// 짧은 상한(예: 100ms)으로 잘라 매 주기 `waitpid` 를 다시 하면 이 클래스의 문제가
    /// 통째로 사라진다. 그 파일은 이 세션 소관이 아니므로 여기서는 부모가 깨운다.
    ///
    /// SIGTERM 이 안전한 이유: 런처는 그 시그널을 받으면 루프 맨 위에서 `waitpid` 로
    /// 자식을 회수하고 **원래 종료 상태 그대로** 보고한다. 뒤따르는 `killpg` 는 이미
    /// 빈 그룹으로 가므로 무해하고, 자식이 좀비인 동안에는 런처 pid 가 재사용되지
    /// 않으므로 엉뚱한 프로세스를 때릴 수 없다.
    private static func nudgeLauncher(
        channel: LauncherStatusChannel,
        launcherProcessIdentifier: pid_t,
        interval: Duration
    ) async {
        guard let spawned = await channel.awaitSpawn(within: .seconds(5)) else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard ChildProcessState.hasExited(spawned.processIdentifier) else { continue }
            // 한 번으로 끝나지 않을 수 있다 — 시그널이 `kevent` 진입 **직전**에
            // 도착하면 대기는 그대로 잠든다. 좀비인 동안 반복 전송은 무해하다.
            kill(launcherProcessIdentifier, SIGTERM)
        }
    }

    private static func feedStandardInput(
        _ execution: Execution<CustomWriteInput, SequenceOutput, SequenceOutput>,
        _ input: Data?
    ) async {
        let writer = execution.standardInputWriter
        if let input, !input.isEmpty {
            _ = try? await writer.write(input)
        }
        // 안 닫으면 `input()` 을 쓰는 프로그램이 EOF 를 못 보고 영영 기다린다.
        try? await writer.finish()
    }

    private static func drain(
        _ sequence: SubprocessOutputSequence,
        budget: OutputBudget,
        isError: Bool,
        continuation: AsyncThrowingStream<RunEvent, any Error>.Continuation
    ) async {
        do {
            // `SubprocessOutputSequence` 는 단일 패스다 — `makeAsyncIterator()` 를 두 번
            // 부르면 trap 이므로 스트림 하나당 이 루프는 정확히 한 번만 돈다.
            for try await buffer in sequence {
                guard buffer.count > 0 else { continue }
                let (allowed, didTruncate) = budget.take(buffer.count)
                if allowed > 0 {
                    let data = buffer.withUnsafeBytes { Data($0.prefix(allowed)) }
                    continuation.yield(isError ? .standardError(data) : .standardOutput(data))
                }
                if didTruncate { continuation.yield(.truncated) }
                // 상한을 넘겨도 루프를 빠져나가지 않는다. 파이프를 안 비우면 자식이
                // `write(2)` 에 매달리고, 그건 가짜 벽시계 초과로 관측된다.
            }
        } catch {
            // 프로세스가 죽으면서 파이프가 끊기는 것은 정상 종료 경로다.
            // 종료 사인은 status fd 와 종료 상태가 알려 준다.
        }
    }
}

extension Duration {
    /// 밀리초 정수. `components` 는 (초, 아토초) 라 나눗셈이 두 번 필요하다.
    var milliseconds: Int64 {
        let parts = components
        return parts.seconds * 1_000 + parts.attoseconds / 1_000_000_000_000_000
    }
}

extension LauncherStatusChannel {
    /// 배수 스레드가 EOF 를 볼 때까지 짧게 기다린다.
    func waitForDrain(within limit: Duration) async {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if isDrainFinished { return }
            do {
                try await Task.sleep(for: .milliseconds(2))
            } catch {
                return
            }
        }
    }
}
