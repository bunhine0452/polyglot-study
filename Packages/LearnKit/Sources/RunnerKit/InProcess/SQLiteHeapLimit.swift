internal import Foundation
internal import Darwin

/// 동시에 살아 있는 여러 실행의 힙 상한을 하나로 접는 스택.
///
/// `sqlite3_hard_heap_limit64` 는 **프로세스 전역**이다(연결별 상한은 SQLite 에 없다).
/// 그래서 실효 상한은 활성 요청 중 가장 작은 값이고, 마지막 요청이 빠지면 원래 값으로
/// 되돌려야 한다. 순수 자료구조로 뽑아둔 이유는 전역 상태를 건드리지 않고 검증하기 위해서다.
struct HeapLimitStack {
    private(set) var requested: [Int64] = []
    /// 스택이 비었을 때 되돌릴 값. 0 은 "상한 없음".
    private(set) var baseline: Int64 = 0

    init(baseline: Int64 = 0) {
        self.baseline = baseline
    }

    var effective: Int64 {
        // 0(=무제한)은 최소값 계산에서 빼야 한다. 전부 0이면 baseline 으로 돌아간다.
        let positive = requested.filter { $0 > 0 }
        return positive.min() ?? baseline
    }

    /// 새 요청을 올리고, 실효 상한이 바뀌었으면 새 값을 돌려준다.
    mutating func push(_ bytes: Int64) -> Int64? {
        let before = effective
        requested.append(bytes)
        let after = effective
        return after == before ? nil : after
    }

    /// 요청 하나를 내리고, 실효 상한이 바뀌었으면 적용할 값을 돌려준다.
    mutating func pop(_ bytes: Int64) -> Int64? {
        guard let index = requested.firstIndex(of: bytes) else { return nil }
        let before = effective
        requested.remove(at: index)
        let after = effective
        return after == before ? nil : after
    }

    var isEmpty: Bool { requested.isEmpty }
}

/// `sqlite3_hard_heap_limit64` 게이트.
///
/// - Important: macOS SDK 의 `sqlite3.h` 에는 이 함수 **선언이 없다**(3.51 dylib 에는 심볼이
///   있다). 그래서 `import SQLite3` 로는 못 부르고 `dlsym` 으로 찾는다. 없으면 조용히 비활성.
enum SQLiteHeapLimit {
    typealias Function = @convention(c) (Int64) -> Int64

    private static let function: Function? = {
        // RTLD_DEFAULT = (void *)-2 on Darwin.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "sqlite3_hard_heap_limit64") else {
            return nil
        }
        return unsafeBitCast(symbol, to: Function.self)
    }()

    static var isAvailable: Bool { function != nil }

    /// 현재 전역 상한. 음수를 넘기면 조회만 한다.
    static func current() -> Int64? { function.map { $0(-1) } }

    private nonisolated(unsafe) static var stack = HeapLimitStack()
    private static let lock = NSLock()

    struct Token: Sendable {
        let bytes: Int64
        let applied: Bool
    }

    static func acquire(bytes: Int64) -> Token {
        guard let function, bytes > 0 else { return Token(bytes: bytes, applied: false) }
        lock.lock()
        defer { lock.unlock() }
        if stack.isEmpty {
            stack = HeapLimitStack(baseline: function(-1))
        }
        if let newLimit = stack.push(bytes) {
            _ = function(newLimit)
        }
        return Token(bytes: bytes, applied: true)
    }

    static func release(_ token: Token) {
        guard let function, token.applied else { return }
        lock.lock()
        defer { lock.unlock() }
        if let newLimit = stack.pop(token.bytes) {
            _ = function(newLimit)
        }
        if stack.isEmpty {
            _ = function(stack.baseline)
        }
    }
}
