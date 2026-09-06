import Foundation
import Testing
@testable import RunnerKit

@Suite("SQL 결과셋 diff")
struct SQLResultDiffTests {

    private func rows(_ values: [Int]) -> [[SQLValue]] {
        values.map { [.integer(Int64($0)), .text("row\($0)")] }
    }

    private func set(_ values: [Int]) -> SQLResultSet {
        SQLResultSet(columnNames: ["id", "label"], rows: rows(values))
    }

    @Test("같은 결과셋은 빈 diff")
    func identicalIsEmpty() {
        let diff = SQLResultDiff.compute(expected: set([1, 2, 3]), actual: set([1, 2, 3]), orderMatters: true)
        #expect(diff.isEmpty)
        #expect(diff.summary == "결과셋 일치")
    }

    @Test("누락 행과 초과 행을 각각 센다")
    func countsMissingAndExtra() {
        let diff = SQLResultDiff.compute(expected: set([1, 2, 3]), actual: set([2, 3, 4, 5]), orderMatters: false)
        #expect(diff.missingRowCount == 1)
        #expect(diff.extraRowCount == 2)
        #expect(diff.missingRows.first?.first == .integer(1))
        #expect(diff.extraRows.count == 2)
    }

    @Test("첫 불일치 셀 좌표를 잡는다")
    func findsFirstMismatchedCell() {
        let expected = SQLResultSet(columnNames: ["a", "b"], rows: [
            [.integer(1), .text("x")],
            [.integer(2), .text("y")],
        ])
        let actual = SQLResultSet(columnNames: ["a", "b"], rows: [
            [.integer(1), .text("x")],
            [.integer(2), .text("CHANGED")],
        ])
        let diff = SQLResultDiff.compute(expected: expected, actual: actual, orderMatters: true)
        #expect(diff.mismatchedRowCount == 1)
        let cell = try? #require(diff.cellMismatches.first)
        #expect(cell?.row == 1)
        #expect(cell?.column == 1)
        #expect(cell?.columnName == "b")
        #expect(cell?.expected == .text("y"))
        #expect(cell?.actual == .text("CHANGED"))
    }

    @Test("세 목록 모두 50개에서 잘리고 총 개수는 그대로")
    func capsEachListAtFifty() {
        let expected = set(Array(1...300))
        let actual = set(Array(1001...1300))
        let diff = SQLResultDiff.compute(expected: expected, actual: actual, orderMatters: true)

        #expect(diff.missingRowCount == 300)
        #expect(diff.extraRowCount == 300)
        #expect(diff.mismatchedRowCount == 300)
        #expect(diff.missingRows.count == 50)
        #expect(diff.extraRows.count == 50)
        #expect(diff.cellMismatches.count == 50)
        #expect(diff.isTruncated)
    }

    @Test("순서 무관이면 다중집합이 같을 때 좌표 잡음을 지운다")
    func unorderedSuppressesPositionalNoise() {
        let expected = set([1, 2, 3])
        let shuffled = set([3, 1, 2])
        let unordered = SQLResultDiff.compute(expected: expected, actual: shuffled, orderMatters: false)
        #expect(unordered.isEmpty)

        let ordered = SQLResultDiff.compute(expected: expected, actual: shuffled, orderMatters: true)
        #expect(!ordered.isEmpty)
        #expect(ordered.mismatchedRowCount == 3)
        #expect(ordered.missingRowCount == 0)
    }

    @Test("INTEGER 와 REAL 은 diff 에서도 같은 값")
    func diffUsesGradingNormalization() {
        let expected = SQLResultSet(columnNames: ["n"], rows: [[.integer(10)]])
        let actual = SQLResultSet(columnNames: ["n"], rows: [[.real(10.0)]])
        #expect(SQLResultDiff.compute(expected: expected, actual: actual, orderMatters: true).isEmpty)
    }

    @Test("1만 행 전부 오답이어도 100ms 안에 끝난다")
    func tenThousandRowsUnderOneHundredMilliseconds() {
        let expected = SQLResultSet(
            columnNames: ["id", "name", "city"],
            rows: (0..<10_000).map { [.integer(Int64($0)), .text("name\($0)"), .text("city\($0 % 17)")] }
        )
        let actual = SQLResultSet(
            columnNames: ["id", "name", "city"],
            rows: (0..<10_000).map { [.integer(Int64($0 + 500_000)), .text("wrong\($0)"), .text("nowhere")] }
        )

        let started = DispatchTime.now()
        let diff = SQLResultDiff.compute(expected: expected, actual: actual, orderMatters: true)
        let elapsedMilliseconds =
            Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000

        #expect(diff.missingRowCount == 10_000)
        #expect(diff.extraRowCount == 10_000)
        #expect(diff.missingRows.count == 50)
        #expect(elapsedMilliseconds < 100, "\(elapsedMilliseconds)ms 걸렸습니다")
    }
}
