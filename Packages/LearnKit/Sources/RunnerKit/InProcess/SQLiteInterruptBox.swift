internal import Foundation
internal import SQLite3

/// 취소·데드라인 신호를 실행 중인 연결에 꽂는 통로.
///
/// `sqlite3_interrupt` 는 다른 스레드에서 불러도 안전하지만 **연결이 살아 있는 동안만** 그렇다.
/// 그래서 핸들을 락 안에 가두고, 워커가 `sqlite3_close_v2` 하기 직전에 `detach()` 한다.
/// 이게 없으면 취소와 종료가 겹칠 때 해제된 포인터로 interrupt 를 쏜다.
final class SQLiteInterruptBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handle: OpaquePointer?
    private var cancelledFlag = false
    private var expiredFlag = false

    init() {}

    func attach(_ database: OpaquePointer) {
        lock.lock()
        defer { lock.unlock() }
        handle = database
        // attach 전에 이미 신호가 왔으면 즉시 반영한다.
        if cancelledFlag || expiredFlag {
            sqlite3_interrupt(database)
        }
    }

    func detach() {
        lock.lock()
        handle = nil
        lock.unlock()
    }

    /// 상위 Task 취소.
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelledFlag = true
        if let handle { sqlite3_interrupt(handle) }
    }

    /// 벽시계 데드라인 초과.
    func expire() {
        lock.lock()
        defer { lock.unlock() }
        expiredFlag = true
        if let handle { sqlite3_interrupt(handle) }
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }

    var isExpired: Bool {
        lock.lock()
        defer { lock.unlock() }
        return expiredFlag
    }
}
