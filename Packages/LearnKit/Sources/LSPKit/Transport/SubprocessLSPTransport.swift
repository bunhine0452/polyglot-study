internal import Foundation
internal import Subprocess
internal import System

/// 진짜 `sourcekit-lsp` 프로세스로 가는 통로.
///
/// ## 왜 `SubprocessRunner` 를 재사용하지 않는가
///
/// `RunnerKit` 의 러너들은 **단발성**이다. 워크스페이스를 만들고 `learn-launcher` 를
/// 통해 rlimit·샌드박스를 건 뒤 프로세스가 끝나기를 기다린다. 언어 서버는 그 반대다 —
/// 몇 분씩 살아 있고, 양방향이고, 샌드박스를 씌우면 SDK·모듈 캐시·인덱스를 못 읽어
/// 아무 일도 못 한다. 격리 장치를 그대로 얹으면 서버가 죽는다.
///
/// 신뢰 경계도 다르다. 러너가 돌리는 것은 **학습자가 쓴 코드**고, 여기서 돌리는 것은
/// **Xcode 에 동봉된 애플 바이너리**다. 후자에 rlimit 을 거는 것은 보호가 아니라 고장이다.
///
/// 공유하는 것은 `swift-subprocess` 라는 수단뿐이다.
public actor SubprocessLSPTransport: LSPTransport {
    private let installation: SourceKitLSPInstallation
    private let arguments: [String]
    /// `close()` 가 서버의 자발적 종료를 기다리는 상한.
    private let closeTimeout: Duration

    private var stdinQueue: AsyncStream<[UInt8]>.Continuation?
    private var processTask: Task<Void, Never>?
    private var isOpened = false
    private var isClosed = false

    public init(
        installation: SourceKitLSPInstallation,
        arguments: [String] = [],
        closeTimeout: Duration = .seconds(3)
    ) {
        self.installation = installation
        self.arguments = arguments
        self.closeTimeout = closeTimeout
    }

    /// `xcrun` 으로 찾아서 만든다.
    public static func locating() async throws -> SubprocessLSPTransport {
        SubprocessLSPTransport(installation: try await SourceKitLSPLocator.locate())
    }

    // MARK: - LSPTransport

    public func open() async throws -> AsyncThrowingStream<[UInt8], any Error> {
        guard !isOpened else { throw LSPTransportError.alreadyOpened }
        isOpened = true

        let (stdinStream, stdinQueue) = AsyncStream<[UInt8]>.makeStream(bufferingPolicy: .unbounded)
        self.stdinQueue = stdinQueue

        let (stdoutStream, stdoutSink) = AsyncThrowingStream<[UInt8], any Error>.makeStream()

        let executable = installation.executablePath
        let arguments = self.arguments
        let environment = childEnvironment()

        processTask = Task {
            do {
                // 종료 상태는 쓰지 않는다. 서버가 죽었다는 사실은 stdout 스트림이
                // 끝나는 것으로 이미 세션에 전달된다.
                _ = try await Subprocess.run(
                    .path(FilePath(executable)),
                    arguments: Arguments(arguments),
                    environment: .custom(
                        Dictionary(uniqueKeysWithValues: environment.map {
                            (Environment.Key(stringLiteral: $0.key), $0.value)
                        })
                    ),
                    platformOptions: Self.platformOptions(),
                    // stdin 은 우리가 계속 쓴다. `.inputWriter` 가 아니면 프로세스가
                    // 즉시 EOF 를 보고 종료한다.
                    input: .inputWriter,
                    output: .sequence,
                    error: .sequence
                ) { execution in
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            // 유일한 작성자. 큐가 끝나면 stdin 을 닫아 서버에 EOF 를 보인다.
                            let writer = execution.standardInputWriter
                            for await bytes in stdinStream {
                                guard (try? await writer.write(bytes)) != nil else { break }
                            }
                            try? await writer.finish()
                        }
                        group.addTask {
                            do {
                                for try await buffer in execution.standardOutput {
                                    guard buffer.count > 0 else { continue }
                                    stdoutSink.yield(buffer.withUnsafeBytes { [UInt8]($0) })
                                }
                            } catch {
                                // 프로세스가 죽으며 파이프가 끊긴 것이다. 아래에서 닫는다.
                            }
                            // 서버가 stdout 을 닫았다 = 세션 끝. 작성자도 풀어 줘야
                            // 태스크 그룹이 끝나고 `run` 이 프로세스를 거둘 수 있다.
                            stdinQueue.finish()
                        }
                        group.addTask {
                            // **반드시 빨아내야 한다.** sourcekit-lsp 는 stderr 로 로그를
                            // 흘리고, 64KB 파이프가 차면 서버가 write(2) 에 매달려
                            // 통째로 멈춘다 — stdout 은 조용한데 응답만 안 오는 모습이 된다.
                            do {
                                for try await _ in execution.standardError {}
                            } catch {
                                // 파이프가 끊긴 것뿐이다. 종료 사인은 stdout 쪽이 알려 준다.
                            }
                        }
                    }
                }
                stdoutSink.finish()
            } catch {
                stdoutSink.finish(throwing: LSPTransportError.launchFailed("\(error)"))
            }
        }

        return stdoutStream
    }

    public func write(_ bytes: [UInt8]) async throws {
        guard !isClosed, let stdinQueue else { throw LSPTransportError.closed }
        stdinQueue.yield(bytes)
    }

    public func close() async {
        guard !isClosed else { return }
        isClosed = true
        // stdin 을 닫으면 서버가 EOF 를 보고 스스로 끝난다. `exit` 알림을 이미
        // 받았다면 그쪽이 먼저다.
        stdinQueue?.finish()

        guard let processTask else { return }
        self.processTask = nil
        // **무한정 기다리지 않는다.** 서버가 EOF 를 무시하면 여기서 매달리고, 그러면
        // 화면을 닫는 동작이 통째로 멈춘다 — 이 저장소가 러너 회수에서 이미 겪은
        // 모양이다. 상한을 넘기면 태스크를 취소하고, `Subprocess` 의 teardown 이
        // SIGTERM → SIGKILL 로 프로세스를 데려간다.
        let deadline = Task {
            try? await Task.sleep(for: closeTimeout)
            processTask.cancel()
        }
        await processTask.value
        deadline.cancel()
    }

    /// 취소됐을 때 프로세스를 데려가는 순서.
    ///
    /// `swift-subprocess` 는 이 목록 **끝에 항상 `.kill` 을 붙인다.** 비워 두면 곧장
    /// SIGKILL 이 가는데, 그러면 서버가 모듈·인덱스 캐시를 정리하지 못한다 — 다음
    /// 세션의 첫 완성이 그만큼 느려진다. 먼저 SIGTERM 을 주고 짧게 기다린다.
    ///
    /// 프로세스 그룹을 때리지 **않는다**. 러너와 달리 여기서는 손자 프로세스가 사용자
    /// 코드가 아니라 서버의 일부(`swift-frontend`)라, 그룹째 죽이는 것과 서버에게
    /// 정리할 기회를 주는 것 중 후자가 맞다.
    private static func platformOptions() -> PlatformOptions {
        var options = PlatformOptions()
        options.teardownSequence = [
            .send(signal: .terminate, toProcessGroup: false, allowedDurationToNextStep: .milliseconds(500))
        ]
        return options
    }

    // MARK: - 환경

    /// 서버에게 물려줄 환경.
    ///
    /// `SubprocessRunnerConfiguration.defaultEnvironment` 를 쓰지 않는다. 그 값은
    /// **사용자 코드**용 최소 환경이고, 언어 서버는 SDK·툴체인·모듈 캐시를 찾아야 한다.
    /// 그래도 앱 환경을 통째로 상속하지는 않는다 — 필요한 것만 짚어 넘긴다.
    func childEnvironment() -> [String: String] {
        var environment: [String: String] = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "LANG": "en_US.UTF-8",
        ]
        if let sdkRoot = installation.sdkRoot { environment["SDKROOT"] = sdkRoot }
        if let developer = installation.developerDirectory { environment["DEVELOPER_DIR"] = developer }
        // HOME 은 진짜 홈이다. 서버가 `~/Library/Caches` 에 모듈·인덱스 캐시를 쌓고,
        // 그게 다음 세션의 첫 완성 응답 시간을 좌우한다. 워크스페이스로 돌리면
        // 매번 차가운 캐시로 시작한다.
        if let home = ProcessInfo.processInfo.environment["HOME"] { environment["HOME"] = home }
        if let tmp = ProcessInfo.processInfo.environment["TMPDIR"] { environment["TMPDIR"] = tmp }
        return environment
    }
}
