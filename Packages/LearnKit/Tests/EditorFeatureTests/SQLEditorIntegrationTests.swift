import LearnCore
import RunnerKit
import Testing

@testable import EditorFeature

/// `{#screen-sql-result}` 종단 검증 — **목 데이터가 아니라** `InProcessRunner` 로 실제
/// SQLite 파일을 열고 실제 쿼리를 돌려 `SQLResultDiff` 를 얻는다. 팩토리를 주입하지
/// 않는다 — `EditorModel` 의 기본 배선(`InProcessRunner`·`SQLResultSetGrader`)이
/// 곧 검증 대상이다.
@Suite("SQL 에디터 · 실제 SQLite 종단 검증")
struct SQLEditorIntegrationTests {
    @Test("LEFT JOIN 정답은 실제 DB 위에서 통과한다")
    func correctSolutionPassesOnRealDatabase() async throws {
        try await SQLFixtureDatabase.withDatabase { databaseURL in
            let model = EditorModel(
                task: SampleTask.sql(database: databaseURL, solution: SQLFixtureDatabase.correctSolution)
            )
            model.code = SQLFixtureDatabase.correctSolution
            await model.run()

            guard case .graded(let result) = model.gradeState else {
                Issue.record("채점 상태가 아니다: \(model.gradeState)")
                return
            }
            #expect(result.passed)
            #expect(model.sqlComparison?.matches == true)
            #expect(model.sqlExpected?.rowCount == 6)
            #expect(model.sqlDiffTables?.rowCountsMatch == true)
        }
    }

    @Test("INNER JOIN 오답은 실제 DB 위에서 진짜 diff 를 낸다 — 체크인 0인 두 회원이 누락")
    func innerJoinMistakeProducesRealDiff() async throws {
        try await SQLFixtureDatabase.withDatabase { databaseURL in
            let model = EditorModel(
                task: SampleTask.sql(database: databaseURL, solution: SQLFixtureDatabase.correctSolution)
            )
            model.code = SQLFixtureDatabase.innerJoinMistake
            await model.run()

            guard case .graded(let result) = model.gradeState else {
                Issue.record("채점 상태가 아니다: \(model.gradeState)")
                return
            }
            #expect(!result.passed)

            let diff = try #require(model.sqlComparison?.diff)
            #expect(diff.missingRowCount == 2)
            #expect(diff.extraRowCount == 0)
            let missingNames = diff.missingRows.map { $0.first?.displayText }
            #expect(Set(missingNames) == ["Bob Bell", "Tushar Chandra"])

            // 화면이 그릴 두 표 — 실제 diff 에서 순수 계산된 결과다.
            let tables = try #require(model.sqlDiffTables)
            #expect(tables.rowCountsMatch)
            #expect(tables.actual.count == 6)
            #expect(tables.actual.filter(\.isPlaceholder).count == 2)
            let expectedHighlighted = tables.expected.filter {
                if case .data(true) = $0.kind { return true }
                return false
            }
            #expect(expectedHighlighted.count == 2)
        }
    }

    @Test("참조 해답이 깨져 있으면 학습자 잘못이 아니라 backend 오류로 failed 상태가 된다")
    func brokenReferenceBecomesFailedGradeState() async throws {
        try await SQLFixtureDatabase.withDatabase { databaseURL in
            let model = EditorModel(
                task: SampleTask.sql(database: databaseURL, solution: "SELECT * FROM nope;")
            )
            model.code = "SELECT 1;"
            await model.run()
            guard case .failed = model.gradeState else {
                Issue.record("failed 상태가 아니다: \(model.gradeState)")
                return
            }
        }
    }
}
