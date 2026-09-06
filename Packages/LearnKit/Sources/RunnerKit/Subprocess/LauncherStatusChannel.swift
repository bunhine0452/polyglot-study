internal import Foundation
internal import Darwin
internal import LanguageKit

/// `learn-launcher` 의 `--status-fd` 를 부모가 읽기 위한 파이프 한 쌍.
///
/// `Foundation.Process` 로는 이 채널을 만들 수 없다 — 자식에게 물려줄 수 있는 fd 가
/// 0·1·2 뿐이라 fd 3 규약을 검증할 수단이 없다. 유일한 길은 `posix_spawn` 의
/// `posix_spawn_file_actions_adddup2` 이고, `SubprocessRunner` 는 그것을
/// `PlatformOptions.preSpawnProcessConfigurator` 로 얻는다.
///
/// - Important: 쓰기 끝은 **스폰 직후** 부모에서 닫아야 한다. 안 닫으면 런처가 죽어도
///   파이프에 쓰는 쪽이 남아 있어 읽기가 영영 EOF 를 못 본다.
final class LauncherStatusChannel: @unchecked Sendable {
    /// 자식이 볼 fd 번호. 런처 ABI 가 3 을 기본으로 쓴다.
    let childFileDescriptor: Int32

    private let readEnd: Int32
    private let writeEnd: Int32
    private let lock = NSLock()
    private var storage = Data()
    private var readClosed = false
    private var writeClosed = false
    private var drainStarted = false
    private var drainFinished = false

    init(childFileDescriptor: Int32 = 3) throws {
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else {
            throw RunFailure.backend("status 파이프 생성 실패: errno \(errno)")
        }
        readEnd = descriptors[0]
        writeEnd = descriptors[1]
        self.childFileDescriptor = childFileDescriptor
        // 자식은 dup2 된 사본만 본다. 원본이 다른 스폰으로 새지 않도록 CLOEXEC 로 막는다 —
        // dup2 는 사본의 CLOEXEC 를 지우므로 fd 3 은 exec 을 넘어 살아남는다.
        _ = fcntl(readEnd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeEnd, F_SETFD, FD_CLOEXEC)
    }

    /// `posix_spawn_file_actions_adddup2` 의 원본 fd.
    var inheritableWriteEnd: Int32 { writeEnd }

    /// 스폰 직후 호출한다. 부모 쪽 쓰기 끝을 닫아야 읽기가 EOF 를 본다.
    func closeWriteEnd() {
        lock.lock()
        defer { lock.unlock() }
        guard !writeClosed else { return }
        writeClosed = true
        Darwin.close(writeEnd)
    }

    /// 전용 스레드에서 EOF 까지 빨아낸다.
    ///
    /// 협력 스레드풀에 올리지 않는 이유는 `read(2)` 가 블로킹이기 때문이다 —
    /// 풀 스레드 하나를 런처가 끝날 때까지 붙잡으면 다른 실행이 굶는다.
    func startDraining() {
        lock.lock()
        let alreadyStarted = drainStarted
        drainStarted = true
        lock.unlock()
        guard !alreadyStarted else { return }

        let thread = Thread { [self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = buffer.withUnsafeMutableBytes { pointer in
                    read(readEnd, pointer.baseAddress, pointer.count)
                }
                if count > 0 {
                    lock.lock()
                    storage.append(contentsOf: buffer[0..<count])
                    lock.unlock()
                    continue
                }
                if count < 0 && errno == EINTR { continue }
                break
            }
            // 읽기 끝은 **이 스레드가 소유한다**. 블로킹 `read(2)` 중인 fd 를 다른
            // 스레드가 닫으면 그 fd 번호가 재사용될 때 엉뚱한 곳을 읽게 된다.
            lock.lock()
            drainFinished = true
            let shouldClose = !readClosed
            readClosed = true
            lock.unlock()
            if shouldClose { Darwin.close(readEnd) }
        }
        thread.name = "learnkit.launcher.status"
        thread.stackSize = 1 << 19
        thread.start()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: storage, as: UTF8.self)
    }

    var statuses: [LauncherStatus] { LauncherStatus.parse(stream: text) }

    var outcome: LauncherOutcome { LauncherOutcome(statuses: statuses) }

    /// `SPAWNED` 라인이 도착할 때까지 짧게 기다린다.
    ///
    /// 런처는 execv 성공 직후 이 줄을 쓰므로 보통 수 밀리초 안에 온다. 오지 않는다면
    /// 런처가 pre-exec 단계에서 실패한 것이고, 그 경우 `ERR` 라인이 대신 와 있다.
    func awaitSpawn(within limit: Duration) async -> (processIdentifier: Int32, processGroup: Int32)? {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            let snapshot = outcome
            // SPAWNED 한 줄에 pid 와 pgid 가 함께 온다 — 둘 다 있거나 둘 다 없다.
            if let pid = snapshot.processIdentifier, let group = snapshot.processGroup {
                return (pid, group)
            }
            // 런처가 스스로 실패했거나 이미 끝났다면 더 기다릴 이유가 없다.
            if snapshot.launcherFailure != nil || snapshot.termination != nil { return nil }
            if isDrainFinished { return nil }
            do {
                try await Task.sleep(for: .milliseconds(2))
            } catch {
                return nil
            }
        }
        return nil
    }

    func awaitProcessGroup(within limit: Duration) async -> Int32? {
        await awaitSpawn(within: limit)?.processGroup
    }

    var isDrainFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return drainFinished
    }

    /// 몇 번 불러도 안전하다. 성공·실패·취소 어느 경로로 나가도 같은 한 줄을 지난다.
    ///
    /// 배수 스레드가 떠 있으면 읽기 끝은 그쪽이 EOF 에서 닫는다 — 런처는 어느 경로로도
    /// 반드시 종료하므로 EOF 는 보장된다.
    func shutdown() {
        closeWriteEnd()
        lock.lock()
        let shouldClose = !readClosed && !drainStarted
        if shouldClose { readClosed = true }
        lock.unlock()
        if shouldClose { Darwin.close(readEnd) }
    }
}
