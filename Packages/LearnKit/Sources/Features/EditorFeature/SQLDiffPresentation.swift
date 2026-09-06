internal import LearnCore
internal import RunnerKit

/// SQL 결과 화면(`{#screen-sql-result}`)의 표 두 개가 그릴 행. `ResultSet`·`SQLResultDiff`
/// 에서 순수하게 조립된다 — 뷰를 만들지 않고 테스트할 수 있다.
struct SQLDiffRow: Hashable, Identifiable {
    enum Kind: Hashable {
        /// 실제 행. `highlighted` 는 상대 표에 짝이 없다는 뜻이다(누락 또는 초과).
        case data(highlighted: Bool)
        /// 높이를 맞추려 채운 자리. `summary` 가 있으면 그 개수를 알리는 첫 자리이고,
        /// 없으면 그 뒤를 채우는 빈 자리다.
        case placeholder(summary: String?)
    }

    let id: Int
    let kind: Kind
    let values: [ResultSet.Value]

    var isPlaceholder: Bool {
        if case .placeholder = kind { return true }
        return false
    }
}

/// 내 결과·예상 결과 두 표. `{#sql-row-padding}`: 행 수가 다르면 짧은 쪽에 플레이스홀더
/// 행을 채워 두 표의 높이를 맞춘다 — 하단 캡션의 y 좌표가 흔들리면 안 되기 때문이다.
struct SQLDiffTables: Hashable {
    let actual: [SQLDiffRow]
    let expected: [SQLDiffRow]

    /// 두 표가 실제로 같은 행 수를 갖는지. 캡션이 안 움직인다는 계약을 테스트가
    /// 렌더링 없이 확인하는 창구다.
    var rowCountsMatch: Bool { actual.count == expected.count }
}

enum SQLDiffPresentation {
    /// - Parameters:
    ///   - expected: 참조 해답이 낸 결과셋(채점기가 준 그대로 — 열 매칭 이전).
    ///   - actual: 제출이 낸 결과셋. `comparison.projectedActual` 이 있으면 그걸 써야
    ///     열 이름이 정답과 나란히 보인다.
    ///   - diff: `SQLResultComparator` 가 계산한 진짜 차이.
    static func build(expected: ResultSet, actual: ResultSet, diff: SQLResultDiff) -> SQLDiffTables {
        let expectedHighlighted = highlightedIndices(in: expected.rows, matching: diff.missingRows)
        let actualHighlighted = highlightedIndices(in: actual.rows, matching: diff.extraRows)

        var actualRows = dataRows(actual.rows, highlighted: actualHighlighted)
        var expectedRows = dataRows(expected.rows, highlighted: expectedHighlighted)

        // 높이는 순수하게 행 수 차이로만 맞춘다 — diff 요약 개수가 상한(`limit`)에
        // 잘려도 두 표의 키는 항상 맞아야 한다.
        let target = max(actualRows.count, expectedRows.count)
        pad(&actualRows, upTo: target) { "\($0)행 누락" }
        pad(&expectedRows, upTo: target) { "\($0)행 초과" }

        return SQLDiffTables(actual: actualRows, expected: expectedRows)
    }

    private static func dataRows(_ rows: [[ResultSet.Value]], highlighted: Set<Int>) -> [SQLDiffRow] {
        rows.enumerated().map { index, row in
            SQLDiffRow(id: index, kind: .data(highlighted: highlighted.contains(index)), values: row)
        }
    }

    private static func pad(_ rows: inout [SQLDiffRow], upTo target: Int, summary: (Int) -> String) {
        let shortfall = target - rows.count
        guard shortfall > 0 else { return }
        let baseID = rows.count
        rows.append(SQLDiffRow(id: baseID, kind: .placeholder(summary: summary(shortfall)), values: []))
        guard shortfall > 1 else { return }
        for offset in 1..<shortfall {
            rows.append(SQLDiffRow(id: baseID + offset, kind: .placeholder(summary: nil), values: []))
        }
    }

    /// `needles` 안의 각 행 값과 위치가 같은(다중집합) `rows` 의 인덱스. 중복 행이
    /// 있어도 필요한 개수만 소비한다 — `SQLResultDiff.compute` 와 같은 계산이다.
    private static func highlightedIndices(
        in rows: [[ResultSet.Value]], matching needles: [[ResultSet.Value]]
    ) -> Set<Int> {
        guard !needles.isEmpty else { return [] }
        var remaining: [[ResultSet.Value]: Int] = [:]
        for row in needles { remaining[row.map(\.normalizedForGrading), default: 0] += 1 }

        var indices: Set<Int> = []
        for (index, row) in rows.enumerated() {
            let key = row.map(\.normalizedForGrading)
            if let count = remaining[key], count > 0 {
                remaining[key] = count - 1
                indices.insert(index)
            }
        }
        return indices
    }
}
