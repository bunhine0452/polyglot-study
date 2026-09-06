internal import Foundation
internal import Darwin

/// 짧게 도는 **신뢰 가능한** 명령 하나를 시간 상한 안에 돌리고 출력을 모은다.
///
/// 사용자 코드용이 아니다 — 그쪽은 `learn-launcher` + `SubprocessRunner` 를 쓴다.
/// 여기 오는 건 `foo --version`, `xcode-select -p`, `zsh -lic` 처럼 툴체인 감지에
/// 필요한 호출뿐이고, 요구사항은 "절대 매달리지 않을 것" 하나다.
public struct BoundedCommandResult: Sendable, Hashable {
    public var exitCode: Int32
    public var terminatingSignal: Int32?
    public var timedOut: Bool
    /// 실행 자체가 실패했다 (파일 없음, 권한 없음 등).
    public var launchFailure: String?
    public var standardOutput: String
    public var standardError: String

    public var succeeded: Bool {
        launchFailure == nil && !timedOut && terminatingSignal == nil && exitCode == 0
    }

    /// 버전 문자열은 도구마다 stdout / stderr 로 제각각 나온다 (`java -version` 은 stderr).
    /// 판정에는 항상 합친 것을 쓴다.
    public var combinedOutput: String {
        if standardError.isEmpty { return standardOutput }
        if standardOutput.isEmpty { return standardError }
        return standardOutput + "\n" + standardError
    }

    public init(
        exitCode: Int32 = -1,
        terminatingSignal: Int32? = nil,
        timedOut: Bool = false,
        launchFailure: String? = nil,
        standardOutput: String = "",
        standardError: String = ""
    ) {
        self.exitCode = exitCode
        self.terminatingSignal = terminatingSignal
        self.timedOut = timedOut
        self.launchFailure = launchFailure
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum BoundedCommand {
    private static let queue = DispatchQueue(
        label: "com.learnkit.runnerkit.bounded-command",
        attributes: .concurrent
    )

    /// - Parameters:
    ///   - executable: 절대경로.
    ///   - timeout: 초과하면 SIGTERM → 200ms → SIGKILL 순으로 끝낸다.
    ///   - environment: `nil` 이면 현재 프로세스 환경을 그대로 물려준다.
    public static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        workingDirectory: String? = nil,
        timeout: Duration
    ) async -> BoundedCommandResult {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(
                    returning: runBlocking(
                        executable: executable,
                        arguments: arguments,
                        environment: environment,
                        workingDirectory: workingDirectory,
                        timeout: timeout
                    )
                )
            }
        }
    }

    static func runBlocking(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: String?,
        timeout: Duration
    ) -> BoundedCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        // 툴이 stdin 을 읽으려 들 때 터미널을 물지 않도록.
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return BoundedCommandResult(launchFailure: "\(error)")
        }

        // 파이프 버퍼(64KB)가 차면 자식이 write 에서 멈춘다 — 두 스트림을 동시에 빨아낸다.
        let outputSink = ByteSink()
        let errorSink = ByteSink()
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        let drain = DispatchGroup()
        queue.async(group: drain) { outputSink.append(outputHandle.readDataToEndOfFile()) }
        queue.async(group: drain) { errorSink.append(errorHandle.readDataToEndOfFile()) }

        var timedOut = false
        let deadline = ContinuousClock.now + timeout
        while process.isRunning {
            if ContinuousClock.now >= deadline {
                timedOut = true
                break
            }
            Thread.sleep(forTimeInterval: 0.005)
        }

        if timedOut {
            process.terminate()
            let graceDeadline = ContinuousClock.now + .milliseconds(200)
            while process.isRunning && ContinuousClock.now < graceDeadline {
                Thread.sleep(forTimeInterval: 0.005)
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }

        process.waitUntilExit()
        drain.wait()

        let terminatedBySignal = process.terminationReason == .uncaughtSignal
        return BoundedCommandResult(
            exitCode: process.terminationStatus,
            terminatingSignal: terminatedBySignal ? process.terminationStatus : nil,
            timedOut: timedOut,
            launchFailure: nil,
            standardOutput: outputSink.text,
            standardError: errorSink.text
        )
    }
}

/// 두 배경 스레드가 쓰는 바이트 버퍼. 락 하나면 충분하다.
private final class ByteSink: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        // 툴 출력은 대개 UTF-8 이지만 아닌 경우도 있으므로 손실 디코딩으로 떨어뜨린다.
        return String(decoding: storage, as: UTF8.self)
    }
}
