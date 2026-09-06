internal import Foundation
public import LearnCore

/// `Presenter.table` 이 그릴 결과셋 차이.
///
/// 오답은 1만 행짜리일 수 있다. 전부 들고 있으면 UI 가 죽으므로 **각 목록을 50개로 자르고
/// 총 개수만 따로 센다** — "3개 빠짐"과 "9,998개 빠짐"은 학습자에게 완전히 다른 정보다.
public struct SQLResultDiff: Hashable, Sendable {
    public static let defaultLimit = 50

    /// 위치가 같은 행끼리 비교했을 때 처음 어긋난 셀.
    public struct CellMismatch: Hashable, Sendable {
        public var row: Int
        public var column: Int
        public var columnName: String
        public var expected: ResultSet.Value
        public var actual: ResultSet.Value

        public init(row: Int, column: Int, columnName: String, expected: ResultSet.Value, actual: ResultSet.Value) {
            self.row = row
            self.column = column
            self.columnName = columnName
            self.expected = expected
            self.actual = actual
        }
    }

    /// 정답에는 있는데 제출에는 없는 행 (최대 `limit` 개).
    public var missingRows: [[ResultSet.Value]]
    /// 제출에만 있는 행 (최대 `limit` 개).
    public var extraRows: [[ResultSet.Value]]
    /// 행 좌표가 같은데 값이 다른 첫 셀들 (최대 `limit` 개).
    public var cellMismatches: [CellMismatch]

    /// 상한과 무관한 실제 개수.
    public var missingRowCount: Int
    public var extraRowCount: Int
    public var mismatchedRowCount: Int
    public var limit: Int

    public init(
        missingRows: [[ResultSet.Value]] = [],
        extraRows: [[ResultSet.Value]] = [],
        cellMismatches: [CellMismatch] = [],
        missingRowCount: Int = 0,
        extraRowCount: Int = 0,
        mismatchedRowCount: Int = 0,
        limit: Int = SQLResultDiff.defaultLimit
    ) {
        self.missingRows = missingRows
        self.extraRows = extraRows
        self.cellMismatches = cellMismatches
        self.missingRowCount = missingRowCount
        self.extraRowCount = extraRowCount
        self.mismatchedRowCount = mismatchedRowCount
        self.limit = limit
    }

    public var isEmpty: Bool {
        missingRowCount == 0 && extraRowCount == 0 && mismatchedRowCount == 0
    }

    public var isTruncated: Bool {
        missingRowCount > missingRows.count
            || extraRowCount > extraRows.count
            || mismatchedRowCount > cellMismatches.count
    }

    public var summary: String {
        guard !isEmpty else { return "결과셋 일치" }
        var parts: [String] = []
        if missingRowCount > 0 { parts.append("누락 \(missingRowCount)행") }
        if extraRowCount > 0 { parts.append("초과 \(extraRowCount)행") }
        if mismatchedRowCount > 0 { parts.append("값 불일치 \(mismatchedRowCount)행") }
        if let first = cellMismatches.first {
            parts.append("첫 불일치 (행 \(first.row + 1), 열 \(first.columnName)): "
                + "기대 \(first.expected.displayText) ≠ 실제 \(first.actual.displayText)")
        }
        return parts.joined(separator: ", ")
    }

    /// 두 결과셋의 차이를 계산한다. 열 개수가 다르면 겹치는 만큼만 셀을 비교한다.
    ///
    /// 다중집합 비교는 사전 한 번 훑기로 끝나므로 행 수에 선형이다.
    public static func compute(
        expected: ResultSet,
        actual: ResultSet,
        orderMatters: Bool,
        limit: Int = SQLResultDiff.defaultLimit
    ) -> SQLResultDiff {
        let expectedRows = expected.rows.map { $0.map(\.normalizedForGrading) }
        let actualRows = actual.rows.map { $0.map(\.normalizedForGrading) }

        // ── 누락·초과 (순서 무관 다중집합)
        var remaining: [[ResultSet.Value]: Int] = Dictionary(minimumCapacity: expectedRows.count)
        for row in expectedRows { remaining[row, default: 0] += 1 }

        var extraRows: [[ResultSet.Value]] = []
        var extraCount = 0
        for row in actualRows {
            if let count = remaining[row], count > 0 {
                remaining[row] = count - 1
            } else {
                extraCount += 1
                if extraRows.count < limit { extraRows.append(row) }
            }
        }

        var missingRows: [[ResultSet.Value]] = []
        var missingCount = 0
        for row in expectedRows {
            guard let count = remaining[row], count > 0 else { continue }
            remaining[row] = count - 1
            missingCount += 1
            if missingRows.count < limit { missingRows.append(row) }
        }

        // ── 첫 불일치 셀 (같은 좌표끼리)
        var cellMismatches: [CellMismatch] = []
        var mismatchedRowCount = 0
        let sharedRows = min(expectedRows.count, actualRows.count)
        for rowIndex in 0..<sharedRows {
            let expectedRow = expectedRows[rowIndex]
            let actualRow = actualRows[rowIndex]
            if expectedRow == actualRow { continue }
            mismatchedRowCount += 1
            guard cellMismatches.count < limit else { continue }
            let sharedColumns = min(expectedRow.count, actualRow.count)
            var columnIndex = 0
            while columnIndex < sharedColumns, expectedRow[columnIndex] == actualRow[columnIndex] {
                columnIndex += 1
            }
            let name = columnIndex < expected.columns.count
                ? expected.columns[columnIndex].name
                : "열\(columnIndex + 1)"
            cellMismatches.append(CellMismatch(
                row: rowIndex,
                column: columnIndex,
                columnName: name,
                expected: columnIndex < expectedRow.count ? expectedRow[columnIndex] : .null,
                actual: columnIndex < actualRow.count ? actualRow[columnIndex] : .null
            ))
        }

        // 순서를 안 따지면 좌표 불일치는 참고용 잡음이다 — 다중집합이 같으면 지운다.
        if !orderMatters, missingCount == 0, extraCount == 0 {
            cellMismatches = []
            mismatchedRowCount = 0
        }

        return SQLResultDiff(
            missingRows: missingRows,
            extraRows: extraRows,
            cellMismatches: cellMismatches,
            missingRowCount: missingCount,
            extraRowCount: extraCount,
            mismatchedRowCount: mismatchedRowCount,
            limit: limit
        )
    }
}
