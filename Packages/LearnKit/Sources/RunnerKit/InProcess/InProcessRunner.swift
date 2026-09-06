public import Foundation
public import LanguageKit
internal import LearnCore

/// SQL 인프로세스 백엔드 설정.
public struct SQLRunnerConfiguration: Sendable {
    /// 학습용 원본 DB. nil 이면 빈 인메모리 DB 로 연다(표현식 전용 레슨).
    public var databaseURL: URL?
    /// 워크스페이스 안에서 클론이 갖는 이름.
    public var databaseFileName: String
    /// 결과셋 행 상한. 넘으면 잘리고 `RunEvent.truncated` 가 나간다.
    public var maxRows: Int
    public var maxSQLBytes: Int
    /// nil 이면 `ResourceLimits.memoryMegabytes` 에서 유도한다.
    public var heapLimitBytes: Int64?
    /// authorizer 가 통과시키는 PRAGMA. 스키마 탐색용 읽기 전용 프라그마만 들어 있다.
    public var allowedPragmas: Set<String>
    /// 워크스페이스 상위 디렉터리. 테스트가 잔여물을 세려고 주입한다.
    public var workspaceContainer: URL?
    /// 클론이 만들어질 때마다 호출된다. 실행마다 별도 클론인지 검증하는 데 쓴다.
    public var cloneObserver: (@Sendable (URL) -> Void)?

    public init(
        databaseURL: URL? = nil,
        databaseFileName: String = "study.db",
        maxRows: Int = 50_000,
        maxSQLBytes: Int = 1 << 20,
        heapLimitBytes: Int64? = nil,
        allowedPragmas: Set<String> = SQLRunnerConfiguration.defaultAllowedPragmas,
        workspaceContainer: URL? = nil,
        cloneObserver: (@Sendable (URL) -> Void)? = nil
    ) {
        self.databaseURL = databaseURL
        self.databaseFileName = databaseFileName
        self.maxRows = maxRows
        self.maxSQLBytes = maxSQLBytes
        self.heapLimitBytes = heapLimitBytes
        self.allowedPragmas = allowedPragmas
        self.workspaceContainer = workspaceContainer
        self.cloneObserver = cloneObserver
    }

    /// 스키마를 들여다보는 데만 쓰이는 프라그마. `query_only`·`journal_mode`·`writable_schema`
    /// 처럼 상태를 바꾸는 것은 **전부** 빠져 있다 — 이 목록이 탈출 경로의 유일한 문이다.
    public static let defaultAllowedPragmas: Set<String> = [
        "table_info", "table_xinfo", "table_list",
        "index_list", "index_info", "index_xinfo",
        "foreign_key_list", "collation_list", "function_list", "pragma_list",
    ]
}

/// 프로세스조차 띄우지 않는 SQL 실행기.
///
/// 서브프로세스 백엔드와 같은 `CodeRunner` 계약을 지키지만 격리 수단이 완전히 다르다 —
/// rlimit·killpg 대신 클론 + READONLY + query_only + authorizer + 힙 상한 다섯 겹이고,
/// 타임아웃은 SIGKILL 이 아니라 `sqlite3_progress_handler` 와 `sqlite3_interrupt` 다.
public struct InProcessRunner: CodeRunner {
    public var configuration: SQLRunnerConfiguration

    public init(configuration: SQLRunnerConfiguration = SQLRunnerConfiguration()) {
        self.configuration = configuration
    }

    public init(databaseURL: URL?) {
        self.init(configuration: SQLRunnerConfiguration(databaseURL: databaseURL))
    }

    /// stdin 도 네트워크도 없다. prepare 단계가 따로 있어 진단은 낼 수 있다.
    public var capabilities: RunnerCapabilities { [.compileDiagnostics] }

    // MARK: - CodeRunner

    public func run(_ request: RunRequest) -> AsyncThrowingStream<RunEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // 워크스페이스 조립과 DB 클론이 preparing, prepare/step 이 running 이다.
                    continuation.yield(.phase(.preparing))
                    continuation.yield(.phase(.running))
                    let outcome = try await self.execute(request)
                    for diagnostic in outcome.diagnostics {
                        continuation.yield(.diagnostic(diagnostic))
                    }
                    self.emitOutput(outcome, limits: request.limits, into: continuation)
                    continuation.yield(.finished(
                        exitCode: outcome.failed ? 1 : 0,
                        durationMilliseconds: outcome.durationMilliseconds
                    ))
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
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - 구조화된 실행 (채점기가 쓰는 입구)

    /// 요청 하나를 **자기만의 워크스페이스와 자기만의 DB 클론**에서 실행한다.
    ///
    /// 참조 해답과 사용자 제출을 각각 이 메서드로 돌리면 서로의 임시 상태를 볼 수 없다.
    public func execute(_ request: RunRequest) async throws -> SQLExecutionResult {
        do {
            return try await executeInWorkspace(request)
        } catch let error as WorkspaceError {
            // 경로 판정 실패도 호출자 입장에서는 백엔드가 실행을 거부한 것이다.
            throw RunFailure.backend(error.description)
        }
    }

    private func executeInWorkspace(_ request: RunRequest) async throws -> SQLExecutionResult {
        let (sql, file) = try Self.source(for: request)

        return try await RunWorkspace.withWorkspace(
            files: request.files,
            container: configuration.workspaceContainer
        ) { workspace in
            let databasePath: String
            if let source = configuration.databaseURL {
                let clone = try SQLDatabaseClone.clone(
                    source: source,
                    into: workspace.root,
                    named: configuration.databaseFileName
                )
                configuration.cloneObserver?(clone)
                databasePath = clone.path
            } else {
                databasePath = ":memory:"
            }

            let options = SQLiteCage.Options(
                wallClockSeconds: max(1, request.limits.wallClockSeconds),
                heapLimitBytes: configuration.heapLimitBytes
                    ?? Int64(request.limits.memoryMegabytes) * (1 << 20),
                maxRows: configuration.maxRows,
                maxSQLBytes: configuration.maxSQLBytes,
                allowedPragmas: configuration.allowedPragmas
            )
            return try await Self.executeOnDedicatedThread(
                databasePath: databasePath,
                sql: sql,
                file: file,
                options: options
            )
        }
    }

    /// SQL 문자열만 있으면 되는 짧은 입구. 채점기와 테스트가 쓴다.
    public func execute(sql: String, limits: ResourceLimits = .lesson, fileName: String = "query.sql") async throws -> SQLExecutionResult {
        try await execute(RunRequest(files: [SourceFile(path: fileName, contents: sql)], limits: limits))
    }

    // MARK: - 내부

    private static func source(for request: RunRequest) throws -> (sql: String, file: String?) {
        if let entryPoint = request.entryPoint {
            guard let file = request.files.first(where: { $0.path == entryPoint }) else {
                throw RunFailure.backend("진입점 파일을 찾을 수 없음: \(entryPoint)")
            }
            return (file.contents, file.path)
        }
        guard let file = request.files.first else {
            throw RunFailure.backend("실행할 SQL 파일이 없습니다")
        }
        return (file.contents, file.path)
    }

    /// SQLite 연결을 **전용 스레드**에 가둔다.
    ///
    /// 협력 스레드풀에서 돌리면 무한 쿼리 하나가 풀 스레드를 하나 잡아먹고, 그 스레드는
    /// interrupt 가 도착할 때까지 절대 양보하지 않는다. 전용 스레드면 그 대가를 우리만 낸다.
    private static func executeOnDedicatedThread(
        databasePath: String,
        sql: String,
        file: String?,
        options: SQLiteCage.Options
    ) async throws -> SQLExecutionResult {
        let interrupt = SQLiteInterruptBox()

        // progress handler 는 step 중에만 돈다. prepare 가 병적으로 오래 걸리는 경우까지
        // 덮으려면 바깥에서 한 번 더 찔러줘야 한다.
        let watchdog = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(options.wallClockSeconds) * 1_000_000_000 + 250_000_000)
            } catch {
                return
            }
            interrupt.expire()
        }
        defer { watchdog.cancel() }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SQLExecutionResult, any Error>) in
                let thread = Thread {
                    do {
                        let result = try SQLiteCage.execute(
                            databasePath: databasePath,
                            sql: sql,
                            file: file,
                            options: options,
                            interrupt: interrupt
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                thread.name = "learnkit.sql.inprocess"
                thread.stackSize = 1 << 21
                thread.start()
            }
        } onCancel: {
            interrupt.cancel()
        }
    }

    private func emitOutput(
        _ result: SQLExecutionResult,
        limits: ResourceLimits,
        into continuation: AsyncThrowingStream<RunEvent, any Error>.Continuation
    ) {
        var truncated = result.truncatedRows
        guard let set = result.resultSet else {
            if truncated { continuation.yield(.truncated) }
            return
        }

        var budget = limits.outputBytes
        var chunk = Data()

        func flush() {
            guard !chunk.isEmpty else { return }
            continuation.yield(.standardOutput(chunk))
            chunk.removeAll(keepingCapacity: true)
        }

        func append(_ data: Data) -> Bool {
            guard budget > 0 else { return false }
            if data.count > budget {
                chunk.append(data.prefix(budget))
                budget = 0
                return false
            }
            chunk.append(data)
            budget -= data.count
            if chunk.count >= 64 * 1024 { flush() }
            return true
        }

        if !append(SQLTextRenderer.headerLine(set.columns)) { truncated = true }
        if budget > 0 {
            for row in set.rows {
                if Task.isCancelled { break }
                if !append(SQLTextRenderer.rowLine(row)) {
                    truncated = true
                    break
                }
            }
        }
        flush()
        if truncated { continuation.yield(.truncated) }
    }
}
