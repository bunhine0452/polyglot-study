import Foundation
import Testing
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("SQL 결과셋 채점 — 값 동일성")
struct SQLValueEqualityTests {

    @Test("INTEGER 10 과 REAL 10.0 은 같다")
    func integerEqualsWholeReal() {
        #expect(SQLValue.integer(10).normalizedForGrading == SQLValue.real(10.0).normalizedForGrading)
        #expect(SQLValue.integer(0).normalizedForGrading == SQLValue.real(-0.0).normalizedForGrading)
        #expect(SQLValue.integer(-7).normalizedForGrading == SQLValue.real(-7.0).normalizedForGrading)
    }

    @Test("소수부가 있으면 접히지 않는다")
    func fractionalRealStaysReal() {
        #expect(SQLValue.integer(10).normalizedForGrading != SQLValue.real(10.5).normalizedForGrading)
        #expect(SQLValue.real(10.5).normalizedForGrading == .real(10.5))
    }

    @Test("Int64 로 정확히 못 담는 REAL 은 그대로 REAL")
    func hugeRealStaysReal() {
        #expect(SQLValue.real(1e300).normalizedForGrading == .real(1e300))
        #expect(SQLValue.real(.nan).normalizedForGrading.isNull == false)
        if case .real = SQLValue.real(.infinity).normalizedForGrading {} else {
            Issue.record("무한대는 정수로 접히면 안 됩니다")
        }
    }

    @Test("NULL·빈 문자열·0 은 서로 다르다")
    func nullEmptyZeroAreDistinct() {
        let values: [SQLValue] = [.null, .text(""), .integer(0), .real(0.0), .text("0")]
        let normalized = values.map(\.normalizedForGrading)
        // 0 과 0.0 만 같고 나머지는 전부 다르다 → 서로 다른 값 4가지.
        #expect(Set(normalized).count == 4)
        #expect(SQLValue.null.normalizedForGrading != SQLValue.text("").normalizedForGrading)
        #expect(SQLValue.text("").normalizedForGrading != SQLValue.integer(0).normalizedForGrading)
        #expect(SQLValue.integer(0).normalizedForGrading != SQLValue.text("0").normalizedForGrading)
        #expect(SQLValue.null.normalizedForGrading != SQLValue.integer(0).normalizedForGrading)
    }
}

@Suite("SQL 결과셋 채점 — 비교기")
struct SQLResultComparatorTests {

    private func set(_ columns: [String], _ rows: [[SQLValue]]) -> SQLResultSet {
        SQLResultSet(columnNames: columns, rows: rows)
    }

    @Test("정수와 실수가 섞여도 통과")
    func numericStorageClassIsIgnored() {
        let expected = set(["total"], [[.integer(10)]])
        let actual = set(["total"], [[.real(10.0)]])
        #expect(SQLResultComparator().compare(expected: expected, actual: actual).matches)
    }

    @Test("NULL 을 빈 문자열로 낸 답은 오답")
    func nullIsNotEmptyString() {
        let expected = set(["nickname"], [[.null]])
        let actual = set(["nickname"], [[.text("")]])
        let comparison = SQLResultComparator().compare(expected: expected, actual: actual)
        #expect(!comparison.matches)
        #expect(comparison.diff.missingRowCount == 1)
        #expect(comparison.diff.extraRowCount == 1)
    }

    @Test("중복 행 개수까지 맞아야 통과")
    func duplicateRowCountsMustMatch() {
        let expected = set(["city"], [[.text("Seoul")], [.text("Seoul")], [.text("Busan")]])
        let twoSeoul = set(["city"], [[.text("Seoul")], [.text("Seoul")], [.text("Busan")]])
        let oneSeoul = set(["city"], [[.text("Seoul")], [.text("Busan")]])
        let threeSeoul = set(["city"], [[.text("Seoul")], [.text("Seoul")], [.text("Seoul")], [.text("Busan")]])

        #expect(SQLResultComparator().compare(expected: expected, actual: twoSeoul).matches)

        let short = SQLResultComparator().compare(expected: expected, actual: oneSeoul)
        #expect(!short.matches)
        #expect(short.diff.missingRowCount == 1)

        let long = SQLResultComparator().compare(expected: expected, actual: threeSeoul)
        #expect(!long.matches)
        #expect(long.diff.extraRowCount == 1)
    }

    @Test("orderMatters=false 면 순서가 달라도 통과")
    func unorderedIgnoresOrder() {
        let expected = set(["n"], [[.integer(1)], [.integer(2)], [.integer(3)]])
        let shuffled = set(["n"], [[.integer(3)], [.integer(1)], [.integer(2)]])
        #expect(SQLResultComparator(criteria: .unordered).compare(expected: expected, actual: shuffled).matches)
    }

    @Test("orderMatters=true 면 순서가 다르면 오답이고 사유가 orderDiffers")
    func orderedRejectsShuffle() {
        let expected = set(["n"], [[.integer(1)], [.integer(2)], [.integer(3)]])
        let shuffled = set(["n"], [[.integer(3)], [.integer(1)], [.integer(2)]])
        let comparison = SQLResultComparator(criteria: .ordered).compare(expected: expected, actual: shuffled)
        #expect(!comparison.matches)
        #expect(comparison.failures == [.orderDiffers])
        #expect(comparison.diff.mismatchedRowCount == 3)
    }

    @Test("orderMatters 는 메타데이터에서 온다")
    func criteriaFromMetadata() {
        #expect(SQLGradingCriteria.from(metadata: ["orderMatters": "true"]).orderMatters)
        #expect(SQLGradingCriteria.from(metadata: ["order_matters": "YES"]).orderMatters)
        #expect(!SQLGradingCriteria.from(metadata: ["orderMatters": "false"]).orderMatters)
        #expect(!SQLGradingCriteria.from(metadata: [:]).orderMatters)
    }

    @Test("열은 대소문자 무시하고 이름으로 맞춘다")
    func columnNamesAreCaseInsensitive() {
        let expected = set(["id", "name"], [[.integer(1), .text("Ada")]])
        let actual = set(["NAME", "Id"], [[.text("Ada"), .integer(1)]])
        let comparison = SQLResultComparator().compare(expected: expected, actual: actual)
        #expect(comparison.matches)
        #expect(comparison.columnMapping == [1, 0])
    }

    @Test("정답이 요구하지 않은 열이 더 있어도 통과 (부분집합 매칭)")
    func extraColumnsAreIgnored() {
        let expected = set(["name"], [[.text("Ada")]])
        let actual = set(["id", "name", "city"], [[.integer(1), .text("Ada"), .text("Seoul")]])
        let comparison = SQLResultComparator().compare(expected: expected, actual: actual)
        #expect(comparison.matches)
        #expect(comparison.columnMapping == [1])
        #expect(comparison.projectedActual?.columns.count == 1)
    }

    @Test("allowsExtraColumns=false 면 초과 열을 잡아낸다")
    func extraColumnsCanBeForbidden() {
        let expected = set(["name"], [[.text("Ada")]])
        let actual = set(["name", "city"], [[.text("Ada"), .text("Seoul")]])
        let criteria = SQLGradingCriteria(orderMatters: false, allowsExtraColumns: false)
        let comparison = SQLResultComparator(criteria: criteria).compare(expected: expected, actual: actual)
        #expect(!comparison.matches)
        #expect(comparison.failures.contains(.unexpectedExtraColumns(count: 1)))
    }

    @Test("무명 표현식은 위치로 맞춘다")
    func anonymousExpressionsFallBackToPosition() {
        let expected = SQLResultSet(
            columns: [SQLColumn(name: "count(*)")],
            rows: [[.integer(5)]]
        )
        let actual = SQLResultSet(
            columns: [SQLColumn(name: "COUNT(*)  ")],
            rows: [[.integer(5)]]
        )
        #expect(SQLColumn(name: "count(*)").isAnonymousExpression)
        let comparison = SQLResultComparator().compare(expected: expected, actual: actual)
        #expect(comparison.matches)
        #expect(comparison.columnMapping == [0])
    }

    @Test("정답이 별칭을 붙였고 제출이 안 붙였으면 위치로 봐준다")
    func aliasOmissionIsForgiven() {
        let expected = SQLResultSet(columns: [SQLColumn(name: "total")], rows: [[.integer(5)]])
        let actual = SQLResultSet(columns: [SQLColumn(name: "count(*)")], rows: [[.integer(5)]])
        #expect(SQLResultComparator().compare(expected: expected, actual: actual).matches)
    }

    @Test("이름이 다른 진짜 다른 열은 위치로 봐주지 않는다")
    func wrongNamedColumnIsNotSilentlyMatched() {
        let expected = set(["salary"], [[.integer(100)]])
        let actual = set(["bonus"], [[.integer(100)]])
        let comparison = SQLResultComparator().compare(expected: expected, actual: actual)
        #expect(!comparison.matches)
        #expect(comparison.failures == [.columnMissing(name: "salary", position: 0)])
    }
}

@Suite("SQL 결과셋 채점 — 실제 DB 위에서")
struct SQLResultSetGraderTests {

    @Test("정답 쿼리는 통과하고 presenter 는 table")
    func correctSubmissionPasses() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let grader = SQLResultSetGrader(runner: InProcessRunner(databaseURL: databaseURL))
            let grading = try await grader.grade(
                submission: "SELECT name FROM members WHERE city = 'Seoul';",
                reference: "SELECT name FROM members WHERE city = 'Seoul';"
            )
            #expect(grading.passed)
            #expect(grading.result.presenter == .table)
            #expect(grading.expected?.rows.count == 3)
        }
    }

    @Test("정렬만 다른 답은 orderMatters 에 따라 갈린다")
    func orderMattersBranches() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let runner = InProcessRunner(databaseURL: databaseURL)
            let submission = "SELECT name FROM members ORDER BY name DESC;"
            let reference = "SELECT name FROM members ORDER BY name ASC;"

            let lenient = try await SQLResultSetGrader(runner: runner, criteria: .unordered)
                .grade(submission: submission, reference: reference)
            #expect(lenient.passed)

            let strict = try await SQLResultSetGrader(runner: runner, criteria: .ordered)
                .grade(submission: submission, reference: reference)
            #expect(!strict.passed)
            #expect(strict.comparison?.failures == [.orderDiffers])
        }
    }

    @Test("NULL 을 '' 로 바꾼 답은 오답")
    func nullVersusEmptyStringOnRealData() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let grader = SQLResultSetGrader(runner: InProcessRunner(databaseURL: databaseURL))
            let grading = try await grader.grade(
                submission: "SELECT id, coalesce(nickname, '') AS nickname FROM members;",
                reference: "SELECT id, nickname FROM members;"
            )
            #expect(!grading.passed)
            #expect(grading.comparison?.diff.missingRowCount == 1)
            #expect(grading.comparison?.diff.extraRowCount == 1)
        }
    }

    @Test("DISTINCT 로 중복을 없앤 답은 오답 — 중복 개수까지 맞아야 한다")
    func duplicateRowsMatterOnRealData() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let grader = SQLResultSetGrader(runner: InProcessRunner(databaseURL: databaseURL))
            let grading = try await grader.grade(
                submission: "SELECT DISTINCT city FROM visits;",
                reference: "SELECT city FROM visits;"
            )
            #expect(!grading.passed)
            #expect(grading.comparison?.diff.missingRowCount == 3)
        }
    }

    @Test("REAL 10.0 과 INTEGER 10 이 섞여도 실제 DB 에서 통과")
    func mixedNumericStorageOnRealData() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let grader = SQLResultSetGrader(runner: InProcessRunner(databaseURL: databaseURL))
            let grading = try await grader.grade(
                submission: "SELECT count(*) * 1.0 AS total FROM members;",
                reference: "SELECT count(*) AS total FROM members;"
            )
            // 저장 클래스는 실제로 다르다 — 정규화가 없으면 오답이 됐을 케이스다.
            #expect(grading.expected?.rows.first?.first == .integer(5))
            #expect(grading.actual?.rows.first?.first == .real(5.0))
            #expect(grading.passed)
        }
    }

    @Test("참조 해답이 깨져 있으면 학습자 잘못이 아니라 backend 오류")
    func brokenReferenceThrows() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let grader = SQLResultSetGrader(runner: InProcessRunner(databaseURL: databaseURL))
            await #expect(throws: RunFailure.self) {
                try await grader.grade(
                    submission: "SELECT 1;",
                    reference: "SELECT * FROM nope;"
                )
            }
        }
    }

    @Test("제출이 문법 오류면 진단이 붙은 오답")
    func brokenSubmissionIsGradedFalse() async throws {
        try await SQLTestDatabase.withDatabase { databaseURL in
            let grader = SQLResultSetGrader(runner: InProcessRunner(databaseURL: databaseURL))
            let grading = try await grader.grade(
                submission: "SELEKT name FROM members;",
                reference: "SELECT name FROM members;"
            )
            #expect(!grading.passed)
            #expect(grading.result.hasErrors)
            #expect(grading.result.exitCode == 1)
        }
    }
}
