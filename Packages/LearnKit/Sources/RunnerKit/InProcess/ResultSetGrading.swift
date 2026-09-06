public import Foundation
public import LearnCore

/// 결과셋 채점에만 필요한 부가 규칙.
///
/// `ResultSet` 자체는 LearnCore 의 언어 중립 타입이다. 여기 있는 것들은 **SQL 채점**의
/// 규칙이라 코어로 올리지 않는다 — 저장 클래스 접기나 무명 표현식 판정은 SQL 방언의 사정이다.
extension ResultSet.Column {
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

extension ResultSet.Value {
    /// 채점용 정규화. **INTEGER 10 과 REAL 10.0 을 같은 값으로 접는다.**
    ///
    /// `SELECT 10` 과 `SELECT avg(x)` 가 같은 답이어야 하는데 저장 클래스만 다른 경우가
    /// 실제 레슨에서 계속 나온다. 반대로 `NULL`·`''`·`0` 은 서로 다른 케이스라 절대 안 접힌다.
    public var normalizedForGrading: ResultSet.Value {
        guard case .real(let double) = self else { return self }
        // Int64(exactly:) 는 소수부가 있거나 Int64 범위를 넘거나 NaN/Inf 면 nil 이다.
        guard let integer = Int64(exactly: double) else { return self }
        return .integer(integer)
    }
}

extension ResultSet {
    /// 테스트·픽스처 편의 생성자.
    public init(columnNames: [String], rows: [[Value]] = [], isTruncated: Bool = false) {
        self.init(
            columns: columnNames.map { Column(name: $0) },
            rows: rows,
            isTruncated: isTruncated
        )
    }

    /// 주어진 열 인덱스만 뽑아 새 결과셋을 만든다. 열 매칭 후 행 비교에 쓴다.
    public func projected(onto indices: [Int]) -> ResultSet {
        ResultSet(
            columns: indices.map { columns[$0] },
            rows: rows.map { row in indices.map { row[$0] } },
            isTruncated: isTruncated
        )
    }

    /// 채점용으로 모든 셀을 정규화한 사본.
    public var normalizedForGrading: ResultSet {
        ResultSet(
            columns: columns,
            rows: rows.map { $0.map(\.normalizedForGrading) },
            isTruncated: isTruncated
        )
    }
}

/// 결과셋을 콘솔 바이트로 옮기는 최소 렌더러.
///
/// 표 프리젠터는 `RunEvent.resultSet` 으로 온 구조화된 표를 직접 그리고, 이건 stdout
/// 폴백과 계약 테스트용이다 — 두 통로가 같은 데이터를 서로 다른 방식으로 나른다.
public enum SQLTextRenderer {
    public static let columnSeparator = Data(" | ".utf8)
    public static let newline = Data("\n".utf8)

    public static func headerLine(_ columns: [ResultSet.Column]) -> Data {
        var data = Data()
        for (index, column) in columns.enumerated() {
            if index > 0 { data.append(columnSeparator) }
            data.append(Data(column.name.utf8))
        }
        data.append(newline)
        return data
    }

    public static func rowLine(_ row: [ResultSet.Value]) -> Data {
        var data = Data()
        for (index, value) in row.enumerated() {
            if index > 0 { data.append(columnSeparator) }
            data.append(value.outputBytes)
        }
        data.append(newline)
        return data
    }

    /// 표 전체를 문자열로. `GradeResult.stdout` 채울 때 쓴다(바이트 상한은 호출부 책임).
    public static func render(_ set: ResultSet, maxRows: Int = 200) -> String {
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
