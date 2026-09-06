public import Foundation

/// 결과셋 열 하나.
public struct SQLColumn: Hashable, Sendable {
    public var name: String
    public var declaredType: String?

    public init(name: String, declaredType: String? = nil) {
        self.name = name
        self.declaredType = declaredType
    }

    /// 이름으로 매칭할 수 없는 열인지. `count(*)`, `a + b`, `?` 처럼 SQLite 가
    /// 표현식 텍스트를 그대로 열 이름으로 준 경우다. 이런 열은 위치로 맞춘다.
    public var isAnonymousExpression: Bool {
        guard let first = name.unicodeScalars.first else { return true }
        if !(CharacterSet.letters.contains(first) || first == "_") { return true }
        for scalar in name.unicodeScalars {
            guard CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "$" else {
                return true
            }
        }
        return false
    }

    public var matchKey: String { name.lowercased() }
}

/// 한 SELECT 가 낸 결과셋.
public struct SQLResultSet: Hashable, Sendable {
    public var columns: [SQLColumn]
    public var rows: [[SQLValue]]

    public init(columns: [SQLColumn], rows: [[SQLValue]] = []) {
        self.columns = columns
        self.rows = rows
    }

    /// 테스트·픽스처 편의 생성자.
    public init(columnNames: [String], rows: [[SQLValue]] = []) {
        self.init(columns: columnNames.map { SQLColumn(name: $0) }, rows: rows)
    }

    public var rowCount: Int { rows.count }
    public var columnCount: Int { columns.count }

    /// 주어진 열 인덱스만 뽑아 새 결과셋을 만든다. 열 매칭 후 행 비교에 쓴다.
    public func projected(onto indices: [Int]) -> SQLResultSet {
        SQLResultSet(
            columns: indices.map { columns[$0] },
            rows: rows.map { row in indices.map { row[$0] } }
        )
    }

    /// 채점용으로 모든 셀을 정규화한 사본.
    public var normalizedForGrading: SQLResultSet {
        SQLResultSet(
            columns: columns,
            rows: rows.map { $0.map(\.normalizedForGrading) }
        )
    }
}

/// 결과셋을 콘솔 바이트로 옮기는 최소 렌더러. 표 프리젠터는 `SQLResultSet` 를 직접 쓰고,
/// 이건 stdout 폴백과 계약 테스트용이다.
public enum SQLTextRenderer {
    public static let columnSeparator = Data(" | ".utf8)
    public static let newline = Data("\n".utf8)

    public static func headerLine(_ columns: [SQLColumn]) -> Data {
        var data = Data()
        for (index, column) in columns.enumerated() {
            if index > 0 { data.append(columnSeparator) }
            data.append(Data(column.name.utf8))
        }
        data.append(newline)
        return data
    }

    public static func rowLine(_ row: [SQLValue]) -> Data {
        var data = Data()
        for (index, value) in row.enumerated() {
            if index > 0 { data.append(columnSeparator) }
            data.append(value.outputBytes)
        }
        data.append(newline)
        return data
    }

    /// 표 전체를 문자열로. `GradeResult.stdout` 채울 때 쓴다(바이트 상한은 호출부 책임).
    public static func render(_ set: SQLResultSet, maxRows: Int = 200) -> String {
        var lines: [String] = [set.columns.map(\.name).joined(separator: " | ")]
        for row in set.rows.prefix(maxRows) {
            lines.append(row.map(\.displayText).joined(separator: " | "))
        }
        if set.rows.count > maxRows {
            lines.append("… \(set.rows.count - maxRows)행 더 있음")
        }
        return lines.joined(separator: "\n")
    }
}
