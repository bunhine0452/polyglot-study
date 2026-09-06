internal import Foundation
internal import SQLite3
internal import LearnCore
internal import LanguageKit

/// 인가 정책 + 데드라인 상태. C 콜백이 `void*` 로 받아가는 상자다.
///
/// 전부 **워커 스레드 하나**에서만 만들어지고 읽힌다. 다른 스레드가 건드리는 건
/// `SQLiteInterruptBox` 뿐이고 그건 자체 락을 가진다.
final class SQLiteCageContext {
    let allowedPragmas: Set<String>
    let deadline: DispatchTime
    let interrupt: SQLiteInterruptBox

    private(set) var deadlineExceeded = false
    private(set) var denials: [String] = []

    init(allowedPragmas: Set<String>, deadline: DispatchTime, interrupt: SQLiteInterruptBox) {
        self.allowedPragmas = allowedPragmas
        self.deadline = deadline
        self.interrupt = interrupt
    }

    /// 어떤 이유로든 쓰기가 되는 액션. `PRAGMA query_only` 만 믿지 않는 이중 방어다 —
    /// authorizer 는 prepare 단계에서 막으므로 사용자에게 더 나은 에러가 나가기도 한다.
    private static let deniedActions: Set<Int32> = [
        SQLITE_CREATE_INDEX, SQLITE_CREATE_TABLE, SQLITE_CREATE_TEMP_INDEX,
        SQLITE_CREATE_TEMP_TABLE, SQLITE_CREATE_TEMP_TRIGGER, SQLITE_CREATE_TEMP_VIEW,
        SQLITE_CREATE_TRIGGER, SQLITE_CREATE_VIEW, SQLITE_CREATE_VTABLE,
        SQLITE_DELETE, SQLITE_DROP_INDEX, SQLITE_DROP_TABLE, SQLITE_DROP_TEMP_INDEX,
        SQLITE_DROP_TEMP_TABLE, SQLITE_DROP_TEMP_TRIGGER, SQLITE_DROP_TEMP_VIEW,
        SQLITE_DROP_TRIGGER, SQLITE_DROP_VIEW, SQLITE_DROP_VTABLE,
        SQLITE_INSERT, SQLITE_UPDATE, SQLITE_ALTER_TABLE, SQLITE_REINDEX, SQLITE_ANALYZE,
        SQLITE_ATTACH, SQLITE_DETACH,
    ]

    /// 파일시스템·확장 로딩에 손이 닿는 함수들. 대부분 CLI/확장 전용이라 없을 수도 있지만
    /// 있는 빌드에서 뚫리는 걸 막는 비용이 0이다.
    private static let deniedFunctions: Set<String> = [
        "load_extension", "readfile", "writefile", "edit",
        "fts3_tokenizer", "zipfile", "sqlar_uncompress",
    ]

    func authorize(action: Int32, arg1: UnsafePointer<CChar>?, arg2: UnsafePointer<CChar>?) -> Int32 {
        if Self.deniedActions.contains(action) {
            record(action: action, arg1: arg1)
            return SQLITE_DENY
        }
        if action == SQLITE_PRAGMA {
            let name = arg1.map { String(cString: $0).lowercased() } ?? ""
            guard allowedPragmas.contains(name) else {
                let value = arg2.map { " = " + String(cString: $0) } ?? ""
                denials.append("PRAGMA \(name)\(value)")
                return SQLITE_DENY
            }
            return SQLITE_OK
        }
        if action == SQLITE_FUNCTION {
            // 함수 인가에서 이름은 두 번째 인자로 온다.
            let name = arg2.map { String(cString: $0).lowercased() } ?? ""
            guard !Self.deniedFunctions.contains(name) else {
                denials.append("함수 \(name)()")
                return SQLITE_DENY
            }
            return SQLITE_OK
        }
        return SQLITE_OK
    }

    private func record(action: Int32, arg1: UnsafePointer<CChar>?) {
        let target = arg1.map { " " + String(cString: $0) } ?? ""
        switch action {
        case SQLITE_ATTACH: denials.append("ATTACH\(target)")
        case SQLITE_DETACH: denials.append("DETACH\(target)")
        case SQLITE_INSERT: denials.append("INSERT\(target)")
        case SQLITE_UPDATE: denials.append("UPDATE\(target)")
        case SQLITE_DELETE: denials.append("DELETE\(target)")
        default: denials.append("쓰기 연산(action=\(action))\(target)")
        }
    }

    /// `sqlite3_progress_handler` 콜백. 0 이 아닌 값을 돌려주면 현재 문장이 중단된다.
    func progressTick() -> Int32 {
        if interrupt.isCancelled { return 1 }
        if DispatchTime.now() >= deadline {
            deadlineExceeded = true
            return 1
        }
        return 0
    }
}

/// 사용자 SQL 을 가둬 놓고 돌리는 곳.
///
/// 다섯 겹이다 — ① 원본이 아닌 **클론**을 연다 ② `SQLITE_OPEN_READONLY`
/// ③ `PRAGMA query_only` ④ authorizer(ATTACH/DETACH/쓰기/비허용 PRAGMA 거부)
/// ⑤ `sqlite3_hard_heap_limit64`. 어느 하나가 뚫려도 나머지가 남는다.
enum SQLiteCage {
    struct Options: Sendable {
        var wallClockSeconds: Int
        var heapLimitBytes: Int64
        var maxRows: Int
        var maxSQLBytes: Int
        var allowedPragmas: Set<String>
    }

    /// **반드시 전용 스레드에서 호출한다.** 열기·준비·실행·닫기가 전부 한 스레드에서 끝나야
    /// `SQLITE_OPEN_FULLMUTEX` 없이도 안전하고, 진행 콜백의 상태가 스레드 로컬로 유지된다.
    static func execute(
        databasePath: String,
        sql: String,
        file: String?,
        options: Options,
        interrupt: SQLiteInterruptBox
    ) throws -> SQLExecutionResult {
        let started = DispatchTime.now()
        let deadline = started + .seconds(options.wallClockSeconds)

        guard sql.utf8.count <= options.maxSQLBytes else {
            throw RunFailure.backend("SQL 이 너무 깁니다 (\(sql.utf8.count) > \(options.maxSQLBytes) 바이트)")
        }

        let heapToken = SQLiteHeapLimit.acquire(bytes: options.heapLimitBytes)
        defer { SQLiteHeapLimit.release(heapToken) }

        var handle: OpaquePointer?
        let openFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        let openResult = sqlite3_open_v2(databasePath, &handle, openFlags, nil)
        guard openResult == SQLITE_OK, let database = handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "알 수 없는 오류"
            if let handle { sqlite3_close_v2(handle) }
            throw RunFailure.backend("데이터베이스를 열 수 없음: \(message) (rc=\(openResult))")
        }
        defer {
            sqlite3_set_authorizer(database, nil, nil)
            sqlite3_progress_handler(database, 0, nil, nil)
            interrupt.detach()
            sqlite3_close_v2(database)
        }
        interrupt.attach(database)

        // ── ③ query_only. authorizer 설치 **전에** 걸어야 우리 자신이 거부당하지 않는다.
        try exec(database, "PRAGMA query_only = ON")
        guard try scalarInt(database, "PRAGMA query_only") == 1 else {
            throw RunFailure.backend("query_only 를 적용하지 못했습니다")
        }

        // ATTACH 는 authorizer 로도 막지만, 한도 0 이면 파서 단계에서 먼저 막힌다.
        sqlite3_limit(database, SQLITE_LIMIT_ATTACHED, 0)
        sqlite3_limit(database, SQLITE_LIMIT_SQL_LENGTH, Int32(clamping: options.maxSQLBytes))
        sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 32 << 20)
        sqlite3_limit(database, SQLITE_LIMIT_EXPR_DEPTH, 256)
        sqlite3_limit(database, SQLITE_LIMIT_COMPOUND_SELECT, 64)
        sqlite3_limit(database, SQLITE_LIMIT_FUNCTION_ARG, 64)
        sqlite3_limit(database, SQLITE_LIMIT_LIKE_PATTERN_LENGTH, 10_000)

        let context = SQLiteCageContext(
            allowedPragmas: options.allowedPragmas,
            deadline: deadline,
            interrupt: interrupt
        )
        let contextPointer = Unmanaged.passUnretained(context).toOpaque()

        sqlite3_set_authorizer(database, { raw, action, arg1, arg2, _, _ in
            guard let raw else { return SQLITE_DENY }
            return Unmanaged<SQLiteCageContext>.fromOpaque(raw)
                .takeUnretainedValue()
                .authorize(action: action, arg1: arg1, arg2: arg2)
        }, contextPointer)

        // 1000 VDBE 스텝마다 한 번. 무한 루프도 결국 스텝을 밟으므로 여기서 잡힌다.
        sqlite3_progress_handler(database, 1000, { raw in
            guard let raw else { return 1 }
            return Unmanaged<SQLiteCageContext>.fromOpaque(raw)
                .takeUnretainedValue()
                .progressTick()
        }, contextPointer)

        // 콜백은 unretained 포인터를 들고 있다. prepare/step 이 도는 동안 context 가
        // 살아 있음을 보장하는 유일한 구간이 여기다.
        var result = try withExtendedLifetime(context) {
            try runStatements(
                database: database,
                sql: sql,
                file: file,
                options: options,
                context: context,
                interrupt: interrupt
            )
        }

        let elapsed = DispatchTime.now().uptimeNanoseconds &- started.uptimeNanoseconds
        result.durationMilliseconds = Int(elapsed / 1_000_000)
        return result
    }

    private static func runStatements(
        database: OpaquePointer,
        sql: String,
        file: String?,
        options: Options,
        context: SQLiteCageContext,
        interrupt: SQLiteInterruptBox
    ) throws -> SQLExecutionResult {
        var result = SQLExecutionResult()
        var thrown: (any Error)?

        sql.withCString { base in
            var cursor = base
            while cursor.pointee != 0 {
                if thrown != nil { return }
                let statementOffset = base.distance(to: cursor)

                var statement: OpaquePointer?
                var tail: UnsafePointer<CChar>?
                let prepareResult = sqlite3_prepare_v2(database, cursor, -1, &statement, &tail)

                guard prepareResult == SQLITE_OK else {
                    if let failure = interruptFailure(prepareResult, context: context, interrupt: interrupt, options: options) {
                        thrown = failure
                        return
                    }
                    result.diagnostics.append(diagnostic(
                        database: database,
                        sql: sql,
                        file: file,
                        statementOffset: statementOffset,
                        context: context
                    ))
                    return
                }

                guard let statement else {
                    // 주석만 남은 꼬리. 더 볼 게 없다.
                    guard let tail, tail > cursor else { return }
                    cursor = tail
                    continue
                }
                defer { sqlite3_finalize(statement) }

                result.statementCount += 1
                do {
                    if let set = try step(
                        statement: statement,
                        database: database,
                        options: options,
                        context: context,
                        interrupt: interrupt,
                        truncated: &result.truncatedRows
                    ) {
                        result.resultSet = set
                    }
                } catch let error as SQLStatementError {
                    // 실행 도중 난 SQL 오류는 계약 실패가 아니라 진단이다.
                    result.diagnostics.append(Diagnostic(
                        file: file,
                        line: SQLSourcePosition.position(ofByteOffset: statementOffset, in: sql)?.line,
                        column: SQLSourcePosition.position(ofByteOffset: statementOffset, in: sql)?.column,
                        severity: .error,
                        message: error.message,
                        ruleID: "sqlite.runtime"
                    ))
                    return
                } catch {
                    thrown = error
                    return
                }

                guard let tail, tail > cursor else { return }
                cursor = tail
            }
        }

        if let thrown { throw thrown }
        return result
    }

    /// - Returns: 행을 내는 문장이면 결과셋, 아니면 nil.
    private static func step(
        statement: OpaquePointer,
        database: OpaquePointer,
        options: Options,
        context: SQLiteCageContext,
        interrupt: SQLiteInterruptBox,
        truncated: inout Bool
    ) throws -> SQLResultSet? {
        let columnCount = Int(sqlite3_column_count(statement))
        guard columnCount > 0 else {
            let rc = sqlite3_step(statement)
            if rc != SQLITE_DONE, rc != SQLITE_ROW {
                if let failure = interruptFailure(rc, context: context, interrupt: interrupt, options: options) {
                    throw failure
                }
                throw SQLStatementError(message: String(cString: sqlite3_errmsg(database)))
            }
            return nil
        }

        var columns: [SQLColumn] = []
        columns.reserveCapacity(columnCount)
        for index in 0..<columnCount {
            let name = sqlite3_column_name(statement, Int32(index)).map { String(cString: $0) } ?? "column\(index + 1)"
            let declared = sqlite3_column_decltype(statement, Int32(index)).map { String(cString: $0) }
            columns.append(SQLColumn(name: name, declaredType: declared))
        }

        var rows: [[SQLValue]] = []
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_ROW {
                if rows.count >= options.maxRows {
                    truncated = true
                    break
                }
                var row: [SQLValue] = []
                row.reserveCapacity(columnCount)
                for index in 0..<columnCount {
                    row.append(value(statement: statement, column: Int32(index)))
                }
                rows.append(row)
                continue
            }
            if rc == SQLITE_DONE { break }
            if let failure = interruptFailure(rc, context: context, interrupt: interrupt, options: options) {
                throw failure
            }
            throw SQLStatementError(message: String(cString: sqlite3_errmsg(database)))
        }
        return SQLResultSet(columns: columns, rows: rows)
    }

    private static func value(statement: OpaquePointer, column: Int32) -> SQLValue {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(statement, column))
        case SQLITE_FLOAT:
            return .real(sqlite3_column_double(statement, column))
        case SQLITE_NULL:
            return .null
        case SQLITE_BLOB:
            guard let pointer = sqlite3_column_blob(statement, column) else { return .blob(Data()) }
            let count = Int(sqlite3_column_bytes(statement, column))
            return .blob(Data(bytes: pointer, count: count))
        default:
            // 텍스트 포인터를 먼저 얻어야 sqlite3_column_bytes 가 맞는 길이를 준다.
            guard let pointer = sqlite3_column_text(statement, column) else { return .text("") }
            let count = Int(sqlite3_column_bytes(statement, column))
            let data = Data(bytes: pointer, count: count)
            if let string = String(data: data, encoding: .utf8) { return .text(string) }
            // UTF-8 이 아닌 TEXT. 손실 디코딩 대신 원시 바이트로 넘긴다.
            return .blob(data)
        }
    }

    /// 중단 계열 반환코드를 계약상 실패로 옮긴다. 계약 실패가 아니면 nil.
    private static func interruptFailure(
        _ code: Int32,
        context: SQLiteCageContext,
        interrupt: SQLiteInterruptBox,
        options: Options
    ) -> (any Error)? {
        switch code {
        case SQLITE_INTERRUPT:
            if interrupt.isCancelled { return RunFailure.cancelled }
            if context.deadlineExceeded || interrupt.isExpired {
                return RunFailure.wallClockExceeded(seconds: options.wallClockSeconds)
            }
            return RunFailure.cancelled
        case SQLITE_NOMEM:
            return RunFailure.memoryExceeded(megabytes: Int(options.heapLimitBytes / (1 << 20)))
        default:
            return nil
        }
    }

    private static func diagnostic(
        database: OpaquePointer,
        sql: String,
        file: String?,
        statementOffset: Int,
        context: SQLiteCageContext
    ) -> Diagnostic {
        var message = String(cString: sqlite3_errmsg(database))
        if let denial = context.denials.last {
            message += " (차단됨: \(denial))"
        }
        let offset = Int(sqlite3_error_offset(database))
        var line: Int?
        var column: Int?
        if offset >= 0,
           let position = SQLSourcePosition.position(ofByteOffset: statementOffset + offset, in: sql) {
            line = position.line
            column = position.column
        }
        return Diagnostic(
            file: file,
            line: line,
            column: column,
            severity: .error,
            message: message,
            ruleID: "sqlite.\(sqlite3_extended_errcode(database))"
        )
    }

    // MARK: - 작은 도우미

    struct SQLStatementError: Error { var message: String }

    private static func exec(_ database: OpaquePointer, _ sql: String) throws {
        let rc = sqlite3_exec(database, sql, nil, nil, nil)
        guard rc == SQLITE_OK else {
            throw RunFailure.backend("\(sql) 실패: \(String(cString: sqlite3_errmsg(database)))")
        }
    }

    private static func scalarInt(_ database: OpaquePointer, _ sql: String) throws -> Int64? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw RunFailure.backend("\(sql) 준비 실패: \(String(cString: sqlite3_errmsg(database)))")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return sqlite3_column_int64(statement, 0)
    }
}
