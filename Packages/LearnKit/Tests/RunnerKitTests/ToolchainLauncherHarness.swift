import Foundation
import Darwin
import LanguageKit
@testable import RunnerKit

/// `learn-launcher` 를 진짜로 띄우고 status fd(3) 까지 읽어 오는 테스트 하네스.
///
/// `Foundation.Process` 는 0·1·2 밖의 fd 를 자식에게 물려줄 수 없어 status fd 규약을
/// 검증할 수 없다. 그래서 `posix_spawn` + `file_actions` 로 직접 연결한다 —
/// 실제 `SubprocessRunner` 도 같은 방식이어야 한다.
struct LaunchedProcess {
    var launcherExitCode: Int32
    var launcherSignal: Int32?
    var standardOutput: String
    var standardError: String
    var statusText: String
    var statuses: [LauncherStatus]
    var outcome: LauncherOutcome
    var elapsed: Duration

    var childProcessGroup: Int32? { outcome.processGroup }
}

enum LauncherHarnessError: Error, CustomStringConvertible {
    case launcherNotBuilt(searched: [String])
    case spawnFailed(Int32)

    var description: String {
        switch self {
        case let .launcherNotBuilt(searched):
            return "learn-launcher 빌드 산출물을 찾지 못했다. 확인한 경로: \(searched.joined(separator: ", "))"
        case let .spawnFailed(code):
            return "posix_spawn 실패: \(code)"
        }
    }
}

enum ToolchainLauncherHarness {
    /// 패키지 루트 (`Packages/LearnKit`).
    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // RunnerKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // LearnKit
    }

    static func locateLauncher() throws -> String {
        if let override = ProcessInfo.processInfo.environment[LauncherLocator.environmentKey],
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        let build = packageRoot.appendingPathComponent(".build")
        var searched: [String] = []
        var candidates: [String] = [
            build.appendingPathComponent("debug/learn-launcher").path,
            build.appendingPathComponent("release/learn-launcher").path,
        ]
        // `.build/debug` 심링크가 없는 배치(`arm64-apple-macosx/debug`)도 훑는다.
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: build.path) {
            for entry in entries.sorted() {
                candidates.append(build.appendingPathComponent("\(entry)/debug/learn-launcher").path)
                candidates.append(build.appendingPathComponent("\(entry)/release/learn-launcher").path)
            }
        }
        for candidate in candidates {
            searched.append(candidate)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        throw LauncherHarnessError.launcherNotBuilt(searched: searched)
    }

    static func invocation(
        program: String,
        arguments: [String] = [],
        cpuSeconds: Int = 0,
        wallClockSeconds: Int = 0,
        maxProcesses: Int = 0,
        memoryMegabytes: Int = 0,
        fileSizeBytes: Int = 0,
        workingDirectory: String? = nil,
        statusFileDescriptor: Int32 = 3
    ) throws -> LauncherInvocation {
        LauncherInvocation(
            launcherPath: try locateLauncher(),
            executablePath: program,
            arguments: arguments,
            workingDirectory: workingDirectory,
            limits: ResourceLimits(
                wallClockSeconds: wallClockSeconds,
                cpuSeconds: cpuSeconds,
                memoryMegabytes: memoryMegabytes,
                fileSizeBytes: fileSizeBytes,
                maxProcesses: maxProcesses
            ),
            statusFileDescriptor: statusFileDescriptor
        )
    }

    /// 런처를 띄우고 끝까지 기다린다.
    ///
    /// - Parameter observe: `SPAWNED` 로 확인된 pgid 를 실행 중에 넘겨준다.
    ///   메모리 폴러처럼 살아 있는 그룹을 봐야 하는 테스트가 쓴다.
    @discardableResult
    static func run(
        _ invocation: LauncherInvocation,
        observe: (@Sendable (Int32) -> Void)? = nil
    ) throws -> LaunchedProcess {
        let outPipe = try PipePair()
        let errPipe = try PipePair()
        let statusPipe = try PipePair()

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, outPipe.writeEnd, 1)
        posix_spawn_file_actions_adddup2(&actions, errPipe.writeEnd, 2)
        posix_spawn_file_actions_adddup2(&actions, statusPipe.writeEnd, invocation.statusFileDescriptor)

        let argv = invocation.commandLine
        var cArguments: [UnsafeMutablePointer<CChar>?] = argv.map { strdup($0) }
        cArguments.append(nil)
        defer { for pointer in cArguments where pointer != nil { free(pointer) } }

        var pid: pid_t = 0
        let clock = ContinuousClock()
        let start = clock.now
        let spawnResult = posix_spawn(&pid, invocation.launcherPath, &actions, nil, &cArguments, environ)
        guard spawnResult == 0 else { throw LauncherHarnessError.spawnFailed(spawnResult) }

        // 부모 쪽 쓰기 끝을 닫아야 읽기가 EOF 를 본다.
        outPipe.closeWrite()
        errPipe.closeWrite()
        statusPipe.closeWrite()

        let queue = DispatchQueue(label: "launcher-harness", attributes: .concurrent)
        let group = DispatchGroup()
        let outSink = TextSink()
        let errSink = TextSink()
        let statusSink = TextSink()
        let outFD = outPipe.readEnd
        let errFD = errPipe.readEnd
        let statusFD = statusPipe.readEnd
        queue.async(group: group) { outSink.drain(fileDescriptor: outFD) }
        queue.async(group: group) { errSink.drain(fileDescriptor: errFD) }
        queue.async(group: group) { statusSink.drain(fileDescriptor: statusFD) }

        if let observe {
            queue.async(group: group) {
                // SPAWNED 는 첫 줄이므로 곧 도착한다. 그룹이 살아 있는 동안만 알려준다.
                let deadline = ContinuousClock.now + .seconds(5)
                while ContinuousClock.now < deadline {
                    let statuses = LauncherStatus.parse(stream: statusSink.text)
                    if let group = LauncherOutcome(statuses: statuses).processGroup {
                        observe(group)
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.005)
                }
            }
        }

        var waitStatus: Int32 = 0
        while waitpid(pid, &waitStatus, 0) < 0 && errno == EINTR { }
        group.wait()
        let elapsed = start.duration(to: clock.now)

        outPipe.closeRead()
        errPipe.closeRead()
        statusPipe.closeRead()

        let exited = (waitStatus & 0x7F) == 0
        let statusText = statusSink.text
        let statuses = LauncherStatus.parse(stream: statusText)
        return LaunchedProcess(
            launcherExitCode: exited ? (waitStatus >> 8) & 0xFF : -1,
            launcherSignal: exited ? nil : (waitStatus & 0x7F),
            standardOutput: outSink.text,
            standardError: errSink.text,
            statusText: statusText,
            statuses: statuses,
            outcome: LauncherOutcome(statuses: statuses),
            elapsed: elapsed
        )
    }

    /// 프로세스 그룹이 사라질 때까지 짧게 기다린다. SIGKILL 회수에는 약간의 지연이 있다.
    static func waitForProcessGroupToVanish(_ group: Int32, within limit: Duration = .seconds(3)) -> Bool {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if ProcessGroupMemory.members(ofProcessGroup: group).isEmpty { return true }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return ProcessGroupMemory.members(ofProcessGroup: group).isEmpty
    }

    static func processExists(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}

private struct PipePair {
    var readEnd: Int32
    var writeEnd: Int32
    private let closed = ClosedFlags()

    init() throws {
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else { throw LauncherHarnessError.spawnFailed(errno) }
        readEnd = descriptors[0]
        writeEnd = descriptors[1]
        // 자식은 dup2 된 사본만 쓰면 된다. 원본은 exec 에서 닫는다.
        _ = fcntl(readEnd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeEnd, F_SETFD, FD_CLOEXEC)
    }

    func closeWrite() { closed.closeOnce(writeEnd, isRead: false) }
    func closeRead() { closed.closeOnce(readEnd, isRead: true) }
}

private final class ClosedFlags: @unchecked Sendable {
    private let lock = NSLock()
    private var readClosed = false
    private var writeClosed = false

    func closeOnce(_ descriptor: Int32, isRead: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if isRead {
            guard !readClosed else { return }
            readClosed = true
        } else {
            guard !writeClosed else { return }
            writeClosed = true
        }
        close(descriptor)
    }
}

private final class TextSink: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func drain(fileDescriptor: Int32) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = buffer.withUnsafeMutableBytes { pointer in
                read(fileDescriptor, pointer.baseAddress, pointer.count)
            }
            if count > 0 {
                lock.lock()
                storage.append(contentsOf: buffer[0..<count])
                lock.unlock()
                continue
            }
            if count < 0 && errno == EINTR { continue }
            return
        }
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: storage, as: UTF8.self)
    }
}
