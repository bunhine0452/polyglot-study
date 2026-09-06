import Darwin
import Foundation
import Testing

@testable import RunnerKit

/// 프로세스 그룹 기록은 **취소될 수 있는 무엇에도 매달리면 안 된다.**
///
/// 그룹은 손자까지 회수하는 유일한 손잡이다(`SubprocessRunner` 의 회수 `defer` 와
/// `onCancel` 킬러가 둘 다 그것만 본다). 예전에는 그 기록이 `awaitSpawn` 폴러 Task
/// 안에서만 일어났는데, 그 Task 는 출력 드레인이 끝나면 취소된다. 즉시 끝나는
/// 프로그램에서는 취소가 SPAWNED 파싱을 앞질러 그룹을 영영 모르게 되고, 손자가
/// 그대로 남는다. 부하 17.8 에서 `grandchildIsReaped` 실패로 한 번 잡혔다.
///
/// 그래서 기록을 드레인 스레드로 옮겼다. 아래 테스트들이 그 계약을 고정한다.
@Suite("런처 status 채널")
struct LauncherStatusChannelTests {
    /// 자식인 척 status 파이프에 바이트를 쓴다.
    private func write(_ text: String, to channel: LauncherStatusChannel) {
        let bytes = Array(text.utf8)
        _ = bytes.withUnsafeBytes { pointer in
            Darwin.write(channel.inheritableWriteEnd, pointer.baseAddress, pointer.count)
        }
    }

    /// 콜백이 올 때까지 기다린다. 드레인은 별도 스레드라 단언이 원자적이지 않다.
    private func waitForValue(_ box: SpawnBox, within seconds: Double = 2) -> (Int32, Int32)? {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if let value = box.value { return value }
            usleep(2000)
        }
        return box.value
    }

    @Test("아무도 기다리지 않아도 SPAWNED 는 기록된다")
    func spawnIsReportedWithoutAnyPoller() throws {
        let channel = try LauncherStatusChannel()
        let box = SpawnBox()

        channel.onSpawn { pid, group in box.set((pid, group)) }
        channel.startDraining()
        // `awaitSpawn` 을 **부르지 않는다.** 이것이 이 테스트의 요점이다.
        write("SPAWNED 4242 4200\n", to: channel)
        channel.closeWriteEnd()

        let observed = waitForValue(box)
        #expect(observed?.0 == 4242)
        #expect(observed?.1 == 4200)
    }

    @Test("폴러가 취소돼도 그룹은 남는다 — 회수 defer 가 때릴 대상을 잃지 않는다")
    func cancelledPollerDoesNotLoseTheGroup() async throws {
        let channel = try LauncherStatusChannel()
        let box = SpawnBox()
        channel.onSpawn { pid, group in box.set((pid, group)) }
        channel.startDraining()

        // 폴러를 띄우고 SPAWNED 가 오기 전에 죽인다 — 드레인 완료가 파싱을 앞지르는
        // 실제 상황을 흉내낸다.
        let poller = Task { await channel.awaitSpawn(within: .seconds(5)) }
        poller.cancel()
        _ = await poller.value

        write("SPAWNED 777 700\n", to: channel)
        channel.closeWriteEnd()

        let observed = waitForValue(box)
        #expect(observed?.1 == 700, "폴러가 취소되자 그룹이 사라졌다 — 손자를 회수할 손잡이가 없다")
    }

    @Test("여러 줄이 나눠 도착해도 한 번만 보고한다")
    func reportedExactlyOnce() throws {
        let channel = try LauncherStatusChannel()
        let counter = SpawnCounter()
        channel.onSpawn { _, _ in counter.increment() }
        channel.startDraining()

        // 한 줄이 두 번의 write 에 걸쳐 온다 — 파이프는 경계를 지켜 주지 않는다.
        write("SPAWNED 51", to: channel)
        usleep(20000)
        write("2 500\nEXIT 0\n", to: channel)
        channel.closeWriteEnd()

        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline && counter.value == 0 { usleep(2000) }
        usleep(50000)  // 뒤이은 EXIT 줄까지 처리할 여유
        #expect(counter.value == 1, "SPAWNED 를 \(counter.value)번 보고했다")
    }

    @Test("드레인이 먼저 시작돼도 뒤늦게 건 콜백이 놓치지 않는다")
    func handlerAttachedAfterArrival() throws {
        let channel = try LauncherStatusChannel()
        channel.startDraining()
        write("SPAWNED 31 30\n", to: channel)
        channel.closeWriteEnd()

        // 바이트가 이미 도착한 뒤에 콜백을 건다.
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline && !channel.isDrainFinished { usleep(2000) }

        let box = SpawnBox()
        channel.onSpawn { pid, group in box.set((pid, group)) }
        #expect(box.value?.1 == 30, "이미 도착한 SPAWNED 를 놓쳤다")
    }
}

final class SpawnBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: (Int32, Int32)?

    var value: (Int32, Int32)? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func set(_ newValue: (Int32, Int32)) {
        lock.lock()
        if stored == nil { stored = newValue }
        lock.unlock()
    }
}

final class SpawnCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
