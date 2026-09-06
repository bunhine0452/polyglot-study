internal import Foundation

/// 결과셋 채점 기준. 레슨 메타데이터에서 온다.
public struct SQLGradingCriteria: Hashable, Sendable {
    /// `ORDER BY` 를 요구하는 문제인지. 기본은 거짓 — SQL 은 원래 순서를 보장하지 않으므로
    /// 정렬을 요구하지 않은 문제에서 순서를 따지면 정답이 오답이 된다.
    public var orderMatters: Bool
    /// 제출이 정답보다 열을 더 많이 내도 통과시킬지.
    public var allowsExtraColumns: Bool
    public var diffLimit: Int

    public init(
        orderMatters: Bool = false,
        allowsExtraColumns: Bool = true,
        diffLimit: Int = SQLResultDiff.defaultLimit
    ) {
        self.orderMatters = orderMatters
        self.allowsExtraColumns = allowsExtraColumns
        self.diffLimit = diffLimit
    }

    public static let unordered = SQLGradingCriteria(orderMatters: false)
    public static let ordered = SQLGradingCriteria(orderMatters: true)

    /// 콘텐츠 팩의 문자열 메타데이터에서 읽는다.
    public static func from(metadata: [String: String]) -> SQLGradingCriteria {
        var criteria = SQLGradingCriteria()
        if let raw = metadata["orderMatters"] ?? metadata["order_matters"] {
            criteria.orderMatters = Self.boolean(raw)
        }
        if let raw = metadata["allowsExtraColumns"] ?? metadata["allows_extra_columns"] {
            criteria.allowsExtraColumns = Self.boolean(raw)
        }
        return criteria
    }

    private static func boolean(_ raw: String) -> Bool {
        ["true", "1", "yes", "y", "on"].contains(raw.trimmingCharacters(in: .whitespaces).lowercased())
    }
}

/// 정답 결과셋과 제출 결과셋을 견준 결과.
public struct SQLComparison: Hashable, Sendable {
    public enum Failure: Hashable, Sendable, CustomStringConvertible {
        case columnMissing(name: String, position: Int)
        case unexpectedExtraColumns(count: Int)
        case rowCountMismatch(expected: Int, actual: Int)
        case rowsDiffer(missing: Int, extra: Int)
        case orderDiffers

        public var description: String {
            switch self {
            case .columnMissing(let name, let position):
                "\(position + 1)번째 열 '\(name)' 을 결과에서 찾을 수 없습니다"
            case .unexpectedExtraColumns(let count):
                "요구하지 않은 열이 \(count)개 더 있습니다"
            case .rowCountMismatch(let expected, let actual):
                "행 수가 다릅니다 (기대 \(expected), 실제 \(actual))"
            case .rowsDiffer(let missing, let extra):
                "행 내용이 다릅니다 (누락 \(missing), 초과 \(extra))"
            case .orderDiffers:
                "행 순서가 다릅니다 — 이 문제는 정렬을 요구합니다"
            }
        }
    }

    public var matches: Bool
    /// 정답 열 i 가 제출 결과의 몇 번째 열에 대응하는지.
    public var columnMapping: [Int]
    public var failures: [Failure]
    public var diff: SQLResultDiff
    /// 열 매칭을 적용해 잘라낸 제출 결과. 표 프리젠터가 그대로 그린다.
    public var projectedActual: SQLResultSet?

    public var summary: String {
        matches ? "정답" : failures.map(\.description).joined(separator: " / ")
    }
}

/// 결과셋 비교기.
///
/// 열은 **이름 대소문자 무시 부분집합 매칭**이다. `SELECT id, name` 과 `SELECT NAME, ID`
/// 는 같은 답이고, 정답이 요구하지 않은 열이 더 붙어도(기본 설정) 통과한다.
/// 이름으로 못 맞추는 무명 표현식(`count(*)`, `a+b`)은 위치로 떨어뜨린다.
public struct SQLResultComparator: Sendable {
    public var criteria: SQLGradingCriteria

    public init(criteria: SQLGradingCriteria = .unordered) {
        self.criteria = criteria
    }

    public func compare(expected: SQLResultSet, actual: SQLResultSet) -> SQLComparison {
        var failures: [SQLComparison.Failure] = []

        guard let mapping = matchColumns(expected: expected.columns, actual: actual.columns, failures: &failures) else {
            return SQLComparison(
                matches: false,
                columnMapping: [],
                failures: failures,
                diff: SQLResultDiff(limit: criteria.diffLimit),
                projectedActual: nil
            )
        }

        if !criteria.allowsExtraColumns, actual.columns.count > expected.columns.count {
            failures.append(.unexpectedExtraColumns(count: actual.columns.count - expected.columns.count))
        }

        let projected = actual.projected(onto: mapping)
        let diff = SQLResultDiff.compute(
            expected: expected,
            actual: projected,
            orderMatters: criteria.orderMatters,
            limit: criteria.diffLimit
        )

        if expected.rows.count != projected.rows.count {
            failures.append(.rowCountMismatch(expected: expected.rows.count, actual: projected.rows.count))
        }
        if diff.missingRowCount > 0 || diff.extraRowCount > 0 {
            failures.append(.rowsDiffer(missing: diff.missingRowCount, extra: diff.extraRowCount))
        } else if criteria.orderMatters, diff.mismatchedRowCount > 0 {
            // 다중집합은 같은데 좌표가 어긋났다 = 순서만 다르다.
            failures.append(.orderDiffers)
        }

        return SQLComparison(
            matches: failures.isEmpty,
            columnMapping: mapping,
            failures: failures,
            diff: diff,
            projectedActual: projected
        )
    }

    /// - Returns: 정답 열 인덱스 → 제출 열 인덱스. 못 맞추면 nil 과 실패 사유.
    private func matchColumns(
        expected: [SQLColumn],
        actual: [SQLColumn],
        failures: inout [SQLComparison.Failure]
    ) -> [Int]? {
        var byName: [String: [Int]] = [:]
        for (index, column) in actual.enumerated() where !column.isAnonymousExpression {
            byName[column.matchKey, default: []].append(index)
        }

        var used: Set<Int> = []
        var mapping: [Int] = []
        mapping.reserveCapacity(expected.count)

        for (position, column) in expected.enumerated() {
            var resolved: Int?
            if !column.isAnonymousExpression, let candidates = byName[column.matchKey] {
                resolved = candidates.first { !used.contains($0) }
            }
            if resolved == nil {
                let positional: Int? = (position < actual.count && !used.contains(position)) ? position : nil
                if column.isAnonymousExpression {
                    // 정답 쪽이 무명 표현식이면 이름으로 맞출 방법이 없다 — 위치로 간다.
                    resolved = positional ?? (0..<actual.count).first { !used.contains($0) }
                } else if let positional, actual[positional].isAnonymousExpression {
                    // 정답은 별칭을 붙였고 제출은 안 붙인 경우(`count(*) AS total` vs `count(*)`).
                    // 제출 쪽도 무명일 때만 위치로 봐준다 — 아니면 다른 열을 조용히 비교하게 된다.
                    resolved = positional
                }
            }
            guard let index = resolved else {
                failures.append(.columnMissing(name: column.name, position: position))
                return nil
            }
            used.insert(index)
            mapping.append(index)
        }
        return mapping
    }
}
