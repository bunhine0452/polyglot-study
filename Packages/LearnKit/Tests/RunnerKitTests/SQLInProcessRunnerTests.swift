import Foundation
import Testing
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("SQL 인프로세스 러너 — 격리")
struct SQLInProcessRunnerIsolationTests {

    @Test("원본 .db 의 mtime 은 어떤 실행 후에도 변하지 않는다")
    func originalDatabaseIsNeverTouched() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let before = try SQLTestDatabase.Fingerprint(of: databaseURL)
            // mtime 해상도가 1초라도 차이를 잡도록 한 박자 쉬어 준다.
            try await Task.sleep(nanoseconds: 1_100_000_000)

            let runner = InProcessRunner(databaseURL: databaseURL)
            let attacks = [
                "SELECT count(*) FROM members;",
                "INSERT INTO members (id, name) VALUES (99, 'mallory');",
                "UPDATE members SET name = 'x';",
                "DELETE FROM members;",
                "DROP TABLE members;",
                "PRAGMA query_only = OFF; INSERT INTO members (id, name) VALUES (98, 'm');",
                "PRAGMA journal_mode = WAL;",
                "ATTACH DATABASE '\(databaseURL.path)' AS other;",
                "CREATE TABLE evil (x);",
                "VACUUM;",
            ]
            for sql in attacks {
                _ = try? await runner.execute(sql: sql)
            }

            let after = try SQLTestDatabase.Fingerprint(of: databaseURL)
            #expect(after.modificationDate == before.modificationDate)
            #expect(after.size == before.size)
            #expect(after.digest == before.digest)
            // 사이드카도 생기면 안 된다 — 원본을 아예 안 열었다는 증거.
            for suffix in ["-wal", "-shm", "-journal"] {
                #expect(!FileManager.default.fileExists(atPath: databaseURL.path + suffix))
            }
        }
    }

    @Test("PRAGMA query_only=OFF 로는 탈출할 수 없다")
    func cannotDisableQueryOnly() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let result = try await runner.execute(sql: "PRAGMA query_only = OFF;")
            #expect(result.failed)
            let message = try #require(result.diagnostics.first?.message)
            #expect(message.lowercased().contains("not authorized"))
            #expect(message.contains("query_only"))
        }
    }

    @Test("query_only 를 끈 뒤 쓰려는 시도도 첫 문장에서 막힌다")
    func writeAfterPragmaEscapeFails() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let result = try await runner.execute(
                sql: "PRAGMA query_only = OFF;\nINSERT INTO members (id, name) VALUES (99, 'mallory');"
            )
            #expect(result.failed)
            // 첫 문장에서 멈추므로 INSERT 는 준비조차 되지 않는다.
            #expect(result.statementCount == 0)
        }
    }

    @Test("ATTACH 로 다른 파일을 붙일 수 없다")
    func cannotAttach() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let result = try await runner.execute(
                sql: "ATTACH DATABASE '\(databaseURL.path)' AS other;"
            )
            #expect(result.failed)
            #expect(result.resultSet == nil)
        }
    }

    @Test("허용된 PRAGMA 는 통과한다")
    func allowedPragmaWorks() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let result = try await runner.execute(sql: "PRAGMA table_info(members);")
            #expect(!result.failed)
            #expect((result.resultSet?.rows.count ?? 0) == 5)
        }
    }

    @Test("READONLY 라서 쓰기 문장은 전부 실패한다", arguments: [
        "INSERT INTO members (id, name) VALUES (99, 'x');",
        "UPDATE members SET name = 'x' WHERE id = 1;",
        "DELETE FROM members WHERE id = 1;",
        "CREATE TABLE t (x);",
        "CREATE TEMP TABLE t (x);",
        "DROP TABLE members;",
    ])
    func writesAreRejected(sql: String) async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let result = try await runner.execute(sql: sql)
            #expect(result.failed, "\(sql) 가 통과했습니다")
        }
    }

    @Test("실행마다 별도 클론을 쓴다")
    func eachRunGetsItsOwnClone() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let observed = ClonePathCollector()
            var configuration = SQLRunnerConfiguration(databaseURL: databaseURL)
            configuration.cloneObserver = { url in observed.append(url) }
            let runner = InProcessRunner(configuration: configuration)

            _ = try await runner.execute(sql: "SELECT 1;")
            _ = try await runner.execute(sql: "SELECT 2;")

            let paths = observed.paths
            #expect(paths.count == 2)
            #expect(Set(paths).count == 2)
            // 실행이 끝났으면 클론도 워크스페이스와 함께 사라진다.
            for path in paths {
                #expect(!FileManager.default.fileExists(atPath: path))
            }
        }
    }

    @Test("복제본은 원본과 같은 내용을 본다")
    func cloneSeesSameData() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let result = try await runner.execute(sql: "SELECT count(*) AS n FROM members;")
            #expect(result.resultSet?.rows.first?.first == .integer(5))
        }
    }
}

@Suite("SQL 인프로세스 러너 — 진단과 중단")
struct SQLInProcessRunnerDiagnosticsTests {

    @Test("error_offset 이 행·열로 환산된다 — 앞 문장의 길이까지 더해서")
    func errorOffsetBecomesLineAndColumn() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let sql = """
                SELECT 1;
                SELECT id,
                       bad_col
                  FROM members;
                """
            let result = try await runner.execute(sql: sql, fileName: "answer.sql")

            let diagnostic = try #require(result.diagnostics.first)
            #expect(diagnostic.severity == .error)
            #expect(diagnostic.file == "answer.sql")
            #expect(diagnostic.line == 3)
            #expect(diagnostic.column == 8, "실제: \(String(describing: diagnostic.column))")
            #expect(diagnostic.message.contains("bad_col"))
        }
    }

    @Test("SQLite 가 오프셋을 안 주는 오류도 진단은 나온다")
    func diagnosticWithoutOffsetStillReported() async throws {
        // 3.51 에서 `no such table` 은 sqlite3_error_offset() 이 -1 이다.
        // 위치가 없다고 진단을 버리면 학습자는 아무 메시지도 못 본다.
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let result = try await runner.execute(sql: "SELECT * FROM missing_table;")
            let diagnostic = try #require(result.diagnostics.first)
            #expect(diagnostic.severity == .error)
            #expect(diagnostic.message.contains("missing_table"))
            #expect(diagnostic.line == nil)
        }
    }

    @Test("멀티바이트 앞의 오류도 표시 칼럼이 맞는다")
    func columnCountsCharactersNotBytes() {
        // '한글주석' 은 12바이트지만 4글자다. 바이트를 그대로 칼럼으로 쓰면 8칸 밀린다.
        let prefix = "SELECT '한글주석', "
        let sql = prefix + "bad_col FROM t;"
        let position = SQLSourcePosition.position(ofByteOffset: prefix.utf8.count, in: sql)
        #expect(position?.line == 1)
        #expect(position?.column == prefix.count + 1)
        #expect(prefix.utf8.count != prefix.count)
    }

    @Test("여러 줄 SQL 의 행 번호 환산")
    func lineNumbersAcrossNewlines() {
        let sql = "a\nbb\nccc"
        #expect(SQLSourcePosition.position(ofByteOffset: 0, in: sql)?.line == 1)
        #expect(SQLSourcePosition.position(ofByteOffset: 2, in: sql)?.line == 2)
        #expect(SQLSourcePosition.position(ofByteOffset: 3, in: sql)?.column == 2)
        #expect(SQLSourcePosition.position(ofByteOffset: 5, in: sql)?.line == 3)
        #expect(SQLSourcePosition.position(ofByteOffset: 99, in: sql) == nil)
    }

    @Test("무한 쿼리는 벽시계 데드라인에 끊긴다", .timeLimit(.minutes(1)))
    func infiniteQueryHitsDeadline() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        let started = Date()
        await #expect(throws: RunFailure.self) {
            try await runner.execute(
                sql: "WITH RECURSIVE spin(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM spin) SELECT count(*) FROM spin;",
                limits: ResourceLimits(wallClockSeconds: 1)
            )
        }
        let elapsed = Date().timeIntervalSince(started)
        #expect(elapsed < 6, "\(elapsed)초 걸렸습니다")
    }

    @Test("데드라인 초과는 wallClockExceeded 로 분류된다")
    func deadlineIsClassifiedCorrectly() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        do {
            _ = try await runner.execute(
                sql: "WITH RECURSIVE spin(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM spin) SELECT count(*) FROM spin;",
                limits: ResourceLimits(wallClockSeconds: 1)
            )
            Issue.record("끝나지 말았어야 합니다")
        } catch let failure as RunFailure {
            guard case .wallClockExceeded(let seconds) = failure else {
                Issue.record("wallClockExceeded 를 기대했는데 \(failure)")
                return
            }
            #expect(seconds == 1)
        }
    }

    @Test("취소는 sqlite3_interrupt 로 즉시 먹힌다", .timeLimit(.minutes(1)))
    func cancellationInterruptsImmediately() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        let task = Task { () -> (any Error)? in
            do {
                _ = try await runner.execute(
                    sql: "WITH RECURSIVE spin(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM spin) SELECT count(*) FROM spin;",
                    limits: ResourceLimits(wallClockSeconds: 60)
                )
                return nil
            } catch {
                return error
            }
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        let cancelledAt = Date()
        task.cancel()
        let error = await task.value
        let reaction = Date().timeIntervalSince(cancelledAt)

        let failure = try #require(error as? RunFailure)
        guard case .cancelled = failure else {
            Issue.record("cancelled 를 기대했는데 \(failure)")
            return
        }
        #expect(reaction < 3, "취소 반응이 \(reaction)초")
    }

    @Test("SQL 오류는 진단이지 실패가 아니다 — 종료코드 1 로 정상 스트림 종료")
    func sqlErrorIsDiagnosticNotThrow() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        var exitCode: Int32?
        var diagnostics: [Diagnostic] = []
        for try await event in runner.run(RunRequest(files: [SourceFile(path: "q.sql", contents: "SELEKT 1;")])) {
            if case .diagnostic(let diagnostic) = event { diagnostics.append(diagnostic) }
            if case .finished(let code, _) = event { exitCode = code }
        }
        #expect(exitCode == 1)
        #expect(diagnostics.contains { $0.severity == .error })
    }

    @Test("정상 쿼리는 종료코드 0 과 표 출력")
    func successfulQueryStreamsTable() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        var stdout = Data()
        var exitCode: Int32?
        var phases: [RunPhase] = []
        for try await event in runner.run(RunRequest(files: [SourceFile(path: "q.sql", contents: "SELECT 1 AS one, 'x' AS letter;")])) {
            switch event {
            case .standardOutput(let data): stdout.append(data)
            case .finished(let code, _): exitCode = code
            case .phase(let phase): phases.append(phase)
            default: break
            }
        }
        #expect(exitCode == 0)
        #expect(phases.contains(.preparing))
        let text = String(decoding: stdout, as: UTF8.self)
        #expect(text.contains("one | letter"))
        #expect(text.contains("1 | x"))
    }

    @Test("출력이 상한을 넘으면 잘리고 truncated 가 한 번 온다")
    func outputIsTruncated() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        let request = RunRequest(
            files: [SourceFile(path: "q.sql", contents: """
                WITH RECURSIVE gen(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM gen WHERE i < 20000)
                SELECT i, hex(randomblob(48)) FROM gen;
                """)],
            limits: ResourceLimits(wallClockSeconds: 20, outputBytes: 64 * 1024)
        )
        var stdout = Data()
        var truncatedCount = 0
        for try await event in runner.run(request) {
            switch event {
            case .standardOutput(let data): stdout.append(data)
            case .truncated: truncatedCount += 1
            default: break
            }
        }
        #expect(truncatedCount == 1)
        #expect(stdout.count <= 64 * 1024)
        #expect(stdout.count > 32 * 1024)
    }

    @Test("UTF-8 이 아닌 TEXT 는 손실 없이 바이트로 나온다")
    func nonUTF8TextSurvives() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        let result = try await runner.execute(sql: "SELECT CAST(x'FFFE' AS TEXT) AS raw;")
        let value = try #require(result.resultSet?.rows.first?.first)
        #expect(value == .blob(Data([0xFF, 0xFE])))
    }

    @Test("잘못된 SourceFile 경로는 스폰 전에 backend 오류로 거부된다")
    func badSourcePathIsRejected() async throws {
        let runner = InProcessRunner(databaseURL: nil)
        await #expect(throws: RunFailure.self) {
            try await runner.execute(RunRequest(files: [SourceFile(path: "../evil.sql", contents: "SELECT 1;")]))
        }
    }
}

@Suite("SQL 인프로세스 러너 — 힙 상한")
struct SQLiteHeapLimitTests {

    @Test("sqlite3_hard_heap_limit64 심볼을 찾을 수 있다")
    func symbolIsAvailable() {
        // macOS SDK 헤더에는 선언이 없지만 dylib 에는 심볼이 있다.
        #expect(SQLiteHeapLimit.isAvailable)
    }

    @Test("동시 요청 중 가장 작은 값이 실효 상한이 된다")
    func stackTakesMinimum() {
        var stack = HeapLimitStack(baseline: 0)
        #expect(stack.push(256 << 20) == 256 << 20)
        #expect(stack.push(512 << 20) == nil)          // 더 크므로 실효 상한 불변
        #expect(stack.push(64 << 20) == 64 << 20)      // 더 작으므로 조인다
        #expect(stack.pop(64 << 20) == 256 << 20)      // 다시 느슨해진다
        #expect(stack.pop(512 << 20) == nil)
        #expect(stack.pop(256 << 20) == 0)             // 마지막이 빠지면 baseline
        #expect(stack.isEmpty)
    }

    @Test("baseline 이 있으면 마지막 해제 때 그 값으로 돌아간다")
    func stackRestoresBaseline() {
        var stack = HeapLimitStack(baseline: 1 << 30)
        #expect(stack.push(1 << 20) == 1 << 20)
        #expect(stack.pop(1 << 20) == 1 << 30)
    }
}

/// `cloneObserver` 는 워커 스레드에서 불릴 수 있으므로 락으로 감싼다.
final class ClonePathCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ url: URL) {
        lock.lock()
        storage.append(url.path)
        lock.unlock()
    }

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
