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
    /// 클론에 한해 쓰기를 허용하는가. ``SQLiteCage/WritePolicy`` 참조.
    let allowsWrites: Bool
    let deadline: DispatchTime
    let interrupt: SQLiteInterruptBox

    private(set) var deadlineExceeded = false
    private(set) var denials: [String] = []

    init(
        allowedPragmas: Set<String>,
        allowsWrites: Bool,
        deadline: DispatchTime,
        interrupt: SQLiteInterruptBox
    ) {
        self.allowedPragmas = allowedPragmas
        self.allowsWrites = allowsWrites
        self.deadline = deadline
        self.interrupt = interrupt
    }

    /// 어떤 이유로든 쓰기가 되는 액션. `PRAGMA query_only` 만 믿지 않는 이중 방어다 —
    /// authorizer 는 prepare 단계에서 막으므로 사용자에게 더 나은 에러가 나가기도 한다.
    /// 쓰기를 허용해도 **절대 열지 않는** 것. 다른 파일에 손이 닿는 통로다.
    private static let alwaysDeniedActions: Set<Int32> = [
        SQLITE_ATTACH, SQLITE_DETACH,
    ]

    /// 데이터·스키마를 바꾸는 액션. 쓰기를 허용하면 이 집합만 열린다.
    ///
    /// 여는 근거는 격리이지 신뢰가 아니다 — 대상은 **실행마다 새로 뜨는 클론**이고
    /// 실행이 끝나면 워크스페이스째 지워진다. 학습자가 망칠 수 있는 것은 자기 사본뿐이다.
    /// 폭주는 ``SQLiteCage/WritePolicy/maxPages`` 가 막는다.
    private static let mutationActions: Set<Int32> = [
        SQLITE_CREATE_INDEX, SQLITE_CREATE_TABLE, SQLITE_CREATE_TEMP_INDEX,
        SQLITE_CREATE_TEMP_TABLE, SQLITE_CREATE_TEMP_TRIGGER, SQLITE_CREATE_TEMP_VIEW,
        SQLITE_CREATE_TRIGGER, SQLITE_CREATE_VIEW, SQLITE_CREATE_VTABLE,
        SQLITE_DELETE, SQLITE_DROP_INDEX, SQLITE_DROP_TABLE, SQLITE_DROP_TEMP_INDEX,
        SQLITE_DROP_TEMP_TABLE, SQLITE_DROP_TEMP_TRIGGER, SQLITE_DROP_TEMP_VIEW,
        SQLITE_DROP_TRIGGER, SQLITE_DROP_VIEW, SQLITE_DROP_VTABLE,
        SQLITE_INSERT, SQLITE_UPDATE, SQLITE_ALTER_TABLE, SQLITE_REINDEX, SQLITE_ANALYZE,
    ]

    /// 파일시스템·확장 로딩에 손이 닿는 함수들. 대부분 CLI/확장 전용이라 없을 수도 있지만
    /// 있는 빌드에서 뚫리는 걸 막는 비용이 0이다.
    private static let deniedFunctions: Set<String> = [
        "load_extension", "readfile", "writefile", "edit",
        "fts3_tokenizer", "zipfile", "sqlar_uncompress",
    ]

    func authorize(action: Int32, arg1: UnsafePointer<CChar>?, arg2: UnsafePointer<CChar>?) -> Int32 {
        if Self.alwaysDeniedActions.contains(action) {
            record(action: action, arg1: arg1)
            return SQLITE_DENY
        }
        if Self.mutationActions.contains(action) {
            guard allowsWrites else {
                record(action: action, arg1: arg1)
                return SQLITE_DENY
            }
            return SQLITE_OK
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
/// 여섯 겹이다 — ① 원본이 아닌 **클론**을 연다 ② 쓰기 정책(읽기 전용이면
/// `SQLITE_OPEN_READONLY` + `PRAGMA query_only`) ③ authorizer(ATTACH/DETACH·비허용
/// PRAGMA 거부, 읽기 전용이면 쓰기도 거부) ④ `sqlite3_hard_heap_limit64`
/// ⑤ **`PRAGMA max_page_count`** ⑥ 벽시계·행 수·SQL 길이 상한.
/// 어느 하나가 뚫려도 나머지가 남는다.
enum SQLiteCage {
    /// 클론에 무엇을 허용할지.
    ///
    /// ## 왜 쓰기를 여는가
    ///
    /// SQL 커리큘럼의 3분의 1이 `INSERT`·`UPDATE`·`DELETE`·`CREATE TABLE` 이다.
    /// 읽기 전용으로는 그걸 **가르칠 수 없다** — 실측으로 확인했다
    /// (`not authorized (차단됨: INSERT category)`).
    ///
    /// 여는 근거는 격리다. 대상은 실행마다 새로 뜨는 클론이고 워크스페이스째 지워진다.
    /// 원본 시드는 손대지 않는다.
    ///
    /// ## 대신 반드시 있어야 하는 것 — 디스크 상한
    ///
    /// 읽기 전용이 **구조적으로** 막고 있던 실패 모드가 하나 있다. 파일을 채우는 것이다.
    ///
    /// ```sql
    /// INSERT INTO t SELECT * FROM t;   -- 문장 하나마다 행이 두 배
    /// ```
    ///
    /// 실측(2026-09-07): 상한 없이 3초 돌리면 **2,266MB · 1,677만 행**이 쌓이고 오류도
    /// 나지 않는다. 기존 다섯 겹 중 디스크를 보는 층은 하나도 없었다 — 힙 상한은 메모리,
    /// `maxRows` 는 **반환** 행 수, 벽시계는 시간이다. 같은 조건에서 16,384 페이지 상한을
    /// 걸면 0MB 에서 `database or disk is full` 로 멈춘다.
    ///
    /// 그래서 쓰기 허용과 페이지 상한은 **한 값**이다. 따로 끌 수 없다.
    enum WritePolicy: Sendable, Hashable {
        /// 읽기만. `SQLITE_OPEN_READONLY` + `query_only` + authorizer 삼중.
        case readOnly
        /// 클론에 한해 쓰기 허용. `maxPages` 로 파일 크기를 묶는다.
        case clonedWritable(maxPages: Int)

        var allowsWrites: Bool {
            if case .clonedWritable = self { return true }
            return false
        }
    }

    struct Options: Sendable {
        var wallClockSeconds: Int
        var heapLimitBytes: Int64
        var maxRows: Int
        var maxSQLBytes: Int
        var allowedPragmas: Set<String>
        var writePolicy: WritePolicy = .readOnly
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
        let openFlags =
            (options.writePolicy.allowsWrites ? SQLITE_OPEN_READWRITE : SQLITE_OPEN_READONLY)
            | SQLITE_OPEN_FULLMUTEX
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

        // ── ② 쓰기 정책. 어느 쪽이든 authorizer 설치 **전에** 걸어야 우리 자신이
        //    거부당하지 않는다 (authorizer 는 PRAGMA 를 허용 목록으로만 통과시킨다).
        switch options.writePolicy {
        case .readOnly:
            try exec(database, "PRAGMA query_only = ON")
            guard try scalarInt(database, "PRAGMA query_only") == 1 else {
                throw RunFailure.backend("query_only 를 적용하지 못했습니다")
            }
        case .clonedWritable(let maxPages):
            // ── ⑤ 디스크 상한. 넘으면 SQLITE_FULL 이 나고 트랜잭션이 되감긴다.
            //    `max_page_count` 는 allowedPragmas 에 **없다** — 학습자가 스스로
            //    상한을 올릴 수 있으면 상한이 아니다.
            try exec(database, "PRAGMA max_page_count = \(maxPages)")
            let applied = try scalarInt(database, "PRAGMA max_page_count")
            guard applied == Int64(maxPages) else {
                let actual = applied.map(String.init) ?? "없음"
                throw RunFailure.backend(
                    "max_page_count 를 적용하지 못했습니다 (요청 \(maxPages), 실제 \(actual))")
            }
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
            allowsWrites: options.writePolicy.allowsWrites,
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
                        interrupt: interrupt
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
        interrupt: SQLiteInterruptBox
    ) throws -> ResultSet? {
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

        var columns: [ResultSet.Column] = []
        columns.reserveCapacity(columnCount)
        for index in 0..<columnCount {
            let name = sqlite3_column_name(statement, Int32(index)).map { String(cString: $0) } ?? "column\(index + 1)"
            let declared = sqlite3_column_decltype(statement, Int32(index)).map { String(cString: $0) }
            columns.append(ResultSet.Column(name: name, declaredType: declared))
        }

        var rows: [[ResultSet.Value]] = []
        var truncated = false
        while true {
            let rc = sqlite3_step(statement)
            if rc == SQLITE_ROW {
                if rows.count >= options.maxRows {
                    truncated = true
                    break
                }
                var row: [ResultSet.Value] = []
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
        return ResultSet(columns: columns, rows: rows, isTruncated: truncated)
    }

    private static func value(statement: OpaquePointer, column: Int32) -> ResultSet.Value {
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
