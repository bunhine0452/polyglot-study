import LearnCore
import RunnerKit
import Testing

@testable import EditorFeature

/// `{#sql-row-padding}` 순수 계산 — 실제 SQLite 없이 `ResultSet`·`SQLResultDiff` 를
/// 직접 조립해 표 두 개의 행 배열이 맞는지만 본다. 실측 SQLite 종단 검증은
/// `SQLEditorIntegrationTests` 에 있다.
@Suite("SQL 결과 화면 · 표 두 개 조립")
struct SQLDiffPresentationTests {
    private func rows(_ values: [[ResultSet.Value]]) -> ResultSet {
        ResultSet(columnNames: ["name", "checkins"], rows: values)
    }

    @Test("일치하면 하이라이트도 플레이스홀더도 없다")
    func perfectMatchHasNoDecoration() {
        let set = rows([[.text("Ada"), .integer(1)], [.text("Grace"), .integer(2)]])
        let diff = SQLResultDiff.compute(expected: set, actual: set, orderMatters: false)
        let tables = SQLDiffPresentation.build(expected: set, actual: set, diff: diff)

        #expect(tables.rowCountsMatch)
        #expect(tables.actual.count == 2)
        #expect(tables.expected.count == 2)
        #expect(tables.actual.allSatisfy { if case .data(false) = $0.kind { true } else { false } })
        #expect(tables.expected.allSatisfy { if case .data(false) = $0.kind { true } else { false } })
    }

    @Test("디자인 예시 — 6행 기대에 4행 제출, 2행 누락")
    func designExampleShortfallOnActualSide() {
        let expected = rows([
            [.text("Annabel Miller"), .integer(5)],
            [.text("Jeremy Bowers"), .integer(4)],
            [.text("Joe Germuska"), .integer(2)],
            [.text("Morty Schapiro"), .integer(1)],
            [.text("Bob Bell"), .integer(0)],
            [.text("Tushar Chandra"), .integer(0)],
        ])
        let actual = rows([
            [.text("Annabel Miller"), .integer(5)],
            [.text("Jeremy Bowers"), .integer(4)],
            [.text("Joe Germuska"), .integer(2)],
            [.text("Morty Schapiro"), .integer(1)],
        ])
        let diff = SQLResultDiff.compute(expected: expected, actual: actual, orderMatters: false)
        #expect(diff.missingRowCount == 2)

        let tables = SQLDiffPresentation.build(expected: expected, actual: actual, diff: diff)

        // 하단 캡션이 안 움직이려면 두 표 행 수가 반드시 같아야 한다.
        #expect(tables.rowCountsMatch)
        #expect(tables.actual.count == 6)
        #expect(tables.expected.count == 6)

        // 내 결과 쪽: 실제 4행 + 요약 플레이스홀더 1행 + 빈 채움 1행.
        #expect(tables.actual.prefix(4).allSatisfy { !$0.isPlaceholder })
        guard case .placeholder(let summary) = tables.actual[4].kind else {
            Issue.record("5번째 행이 플레이스홀더가 아니다: \(tables.actual[4].kind)")
            return
        }
        #expect(summary == "2행 누락")
        guard case .placeholder(let blankSummary) = tables.actual[5].kind else {
            Issue.record("6번째 행이 플레이스홀더가 아니다")
            return
        }
        #expect(blankSummary == nil)

        // 예상 결과 쪽: 6행 전부 데이터고, 마지막 둘(Bob Bell·Tushar Chandra)만 하이라이트.
        #expect(tables.expected.allSatisfy { !$0.isPlaceholder })
        let highlighted = tables.expected.map { row -> Bool in
            if case .data(let flag) = row.kind { return flag }
            return false
        }
        #expect(highlighted == [false, false, false, false, true, true])
    }

    @Test("반대 방향 — 제출이 더 길면 예상 결과 쪽에 플레이스홀더가 붙는다")
    func shortfallOnExpectedSide() {
        let expected = rows([[.text("Ada"), .integer(1)]])
        let actual = rows([[.text("Ada"), .integer(1)], [.text("Extra"), .integer(9)]])
        let diff = SQLResultDiff.compute(expected: expected, actual: actual, orderMatters: false)
        #expect(diff.extraRowCount == 1)

        let tables = SQLDiffPresentation.build(expected: expected, actual: actual, diff: diff)
        #expect(tables.rowCountsMatch)
        #expect(tables.actual.count == 2)
        #expect(tables.expected.count == 2)

        guard case .placeholder(let summary) = tables.expected[1].kind else {
            Issue.record("예상 결과 쪽에 플레이스홀더가 없다")
            return
        }
        #expect(summary == "1행 초과")

        let actualHighlighted = tables.actual.map { row -> Bool in
            if case .data(let flag) = row.kind { return flag }
            return false
        }
        #expect(actualHighlighted == [false, true])
    }

    @Test("중복 행도 다중집합으로 정확히 소비된다")
    func duplicateRowsConsumeCorrectCount() {
        let expected = rows([[.text("Seoul"), .integer(0)], [.text("Seoul"), .integer(0)], [.text("Busan"), .integer(0)]])
        let actual = rows([[.text("Seoul"), .integer(0)], [.text("Busan"), .integer(0)]])
        let diff = SQLResultDiff.compute(expected: expected, actual: actual, orderMatters: false)
        let tables = SQLDiffPresentation.build(expected: expected, actual: actual, diff: diff)

        #expect(tables.rowCountsMatch)
        // 예상 결과 3행 중 정확히 1행(누락된 Seoul 사본 하나)만 하이라이트돼야 한다 —
        // 둘 다 하이라이트되면 다중집합 소비가 아니라 값만 보고 표시한 것이다.
        let highlightedCount = tables.expected.filter {
            if case .data(true) = $0.kind { return true }
            return false
        }.count
        #expect(highlightedCount == 1)
    }

    @Test("빈 결과셋끼리는 표도 비어 있다")
    func emptyResultSetsProduceEmptyTables() {
        let empty = ResultSet(columns: [])
        let diff = SQLResultDiff.compute(expected: empty, actual: empty, orderMatters: false)
        let tables = SQLDiffPresentation.build(expected: empty, actual: empty, diff: diff)
        #expect(tables.actual.isEmpty)
        #expect(tables.expected.isEmpty)
        #expect(tables.rowCountsMatch)
    }
}
