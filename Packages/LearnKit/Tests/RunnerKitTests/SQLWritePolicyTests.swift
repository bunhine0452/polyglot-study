import Foundation
import LanguageKit
import LearnCore
import Testing

@testable import RunnerKit

/// 클론에 쓰기를 여는 대신 디스크 상한이 서 있어야 한다는 계약.
///
/// 읽기 전용은 파일이 커지는 것을 **구조적으로** 막고 있었다. 그걸 열었으니 그 자리에
/// 다른 층이 들어와야 한다 — `PRAGMA max_page_count` 다. 아래가 그 교대를 고정한다.
@Suite("SQL 쓰기 정책과 디스크 상한")
struct SQLWritePolicyTests {
    /// 결과셋의 모든 셀을 사람이 읽는 문자열로. 단언을 짧게 쓰기 위한 것.
    private static func cells(_ result: SQLExecutionResult) -> [String] {
        (result.resultSet?.rows ?? []).flatMap { $0.map(\.displayText) }
    }

    /// 폭주 SQL. 문장 하나마다 행이 두 배가 된다.
    private static let runaway = """
        CREATE TABLE bomb (payload TEXT);
        INSERT INTO bomb VALUES (hex(randomblob(512)));
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        INSERT INTO bomb SELECT payload FROM bomb;
        SELECT count(*) FROM bomb;
        """

    @Test("클론에는 실제로 쓸 수 있다 — 이게 없으면 SQL 트랙의 3분의 1을 못 가르친다")
    func writesLandOnTheClone() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner()
            let result = try await runner.execute(
                sql: """
                    INSERT INTO members (id, name) VALUES (99, 'mallory');
                    SELECT name FROM members WHERE id = 99;
                    """,
                database: databaseURL)
            #expect(!result.failed, "쓰기가 거부됐다: \(result.diagnostics.map(\.message))")
            #expect(Self.cells(result).contains("mallory"))
        }
    }

    @Test("CREATE TABLE 도 된다 — DDL 레슨이 성립한다")
    func schemaChangesAreAllowed() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let result = try await InProcessRunner().execute(
                sql: """
                    CREATE TABLE delivery (id INTEGER PRIMARY KEY, note TEXT NOT NULL);
                    INSERT INTO delivery (id, note) VALUES (1, '문 앞');
                    SELECT note FROM delivery;
                    """,
                database: databaseURL)
            #expect(!result.failed, "\(result.diagnostics.map(\.message))")
            #expect(Self.cells(result).contains("문 앞"))
        }
    }

    /// 이 프로젝트에서 가장 중요한 단언이다. 상한이 없으면 3초에 2GB 가 쌓인다(실측).
    @Test("폭주하는 INSERT 는 페이지 상한에서 멈춘다")
    func runawayWriteHitsThePageCap() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            // 64 페이지 = 256KB. 폭주를 빨리 잡되 정상 문장은 통과할 만큼은 된다.
            let runner = InProcessRunner(
                configuration: SQLRunnerConfiguration(maxDatabasePages: 64))
            let result = try await runner.execute(
                sql: Self.runaway, database: databaseURL,
                limits: ResourceLimits(wallClockSeconds: 20))

            #expect(result.failed, "상한이 있는데 폭주가 통과했다")
            let message = (result.diagnostics.map(\.message) + Self.cells(result))
                .joined(separator: " ")
            #expect(
                message.lowercased().contains("full") || message.contains("가득"),
                "디스크 상한이 아닌 다른 이유로 실패했다: \(message)")
        }
    }

    @Test("학습자는 상한을 스스로 올릴 수 없다")
    func learnerCannotRaiseTheCap() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let result = try await InProcessRunner().execute(
                sql: "PRAGMA max_page_count = 1000000;", database: databaseURL)
            #expect(result.failed)
            let message = try #require(result.diagnostics.first?.message)
            #expect(message.lowercased().contains("not authorized"))
            #expect(message.contains("max_page_count"))
        }
    }

    @Test("쓰기를 열어도 ATTACH 는 여전히 거부된다 — 다른 파일에 손이 닿는 통로다")
    func attachStaysDenied() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let result = try await InProcessRunner().execute(
                sql: "ATTACH DATABASE '\(databaseURL.path)' AS other;", database: databaseURL)
            #expect(result.failed)
        }
    }

    @Test("읽기 전용 모드는 그대로 남아 있다")
    func readOnlyModeStillDenies() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(
                configuration: SQLRunnerConfiguration(allowsWrites: false))
            let result = try await runner.execute(
                sql: "INSERT INTO members (id, name) VALUES (99, 'mallory');",
                database: databaseURL)
            #expect(result.failed)
            let message = try #require(result.diagnostics.first?.message)
            #expect(message.lowercased().contains("not authorized"))
        }
    }
}
