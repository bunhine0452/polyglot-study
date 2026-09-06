internal import Foundation
public import LearnCore

/// 인프로세스 SQL 실행 한 번의 결과.
///
/// SQL 자체가 틀린 것(`no such table`)은 **실패가 아니라 진단**이다. 던지는 건
/// 실행기가 계약을 못 지킨 경우 — 타임아웃·취소·메모리 초과·백엔드 오류 — 뿐이다.
public struct SQLExecutionResult: Sendable {
    /// 행을 낸 마지막 문장의 결과셋. 전부 비-SELECT 였으면 nil.
    public var resultSet: ResultSet?
    /// 실제로 준비·실행된 문장 수.
    public var statementCount: Int
    public var diagnostics: [Diagnostic]
    public var durationMilliseconds: Int

    public init(
        resultSet: ResultSet? = nil,
        statementCount: Int = 0,
        diagnostics: [Diagnostic] = [],
        durationMilliseconds: Int = 0
    ) {
        self.resultSet = resultSet
        self.statementCount = statementCount
        self.diagnostics = diagnostics
        self.durationMilliseconds = durationMilliseconds
    }

    /// `maxRows` 에 걸려 행이 잘렸다. 절단 여부는 결과셋 자신이 들고 다닌다 —
    /// 스트림으로 나갈 때 플래그가 결과와 떨어지면 소비자가 다시 짝지어야 한다.
    public var truncatedRows: Bool { resultSet?.isTruncated ?? false }

    public var failed: Bool { diagnostics.contains { $0.severity == .error } }
}

/// SQL 텍스트 안의 바이트 오프셋을 사람이 읽는 행·열로 옮긴다.
///
/// `sqlite3_error_offset()` (SQLite 3.38+) 이 주는 건 **UTF-8 바이트 오프셋**이다.
/// 그대로 열 번호로 쓰면 한글 주석이 한 줄만 있어도 캐럿이 엉뚱한 데 찍힌다.
public enum SQLSourcePosition {
    /// - Returns: 1-기반 (행, 열). 열은 UTF-16 이 아니라 **표시용 Character 수**다.
    public static func position(ofByteOffset offset: Int, in sql: String) -> (line: Int, column: Int)? {
        guard offset >= 0 else { return nil }
        let utf8 = Array(sql.utf8)
        guard offset <= utf8.count else { return nil }

        var line = 1
        var lineStart = 0
        var index = 0
        while index < offset {
            if utf8[index] == 0x0A {
                line += 1
                lineStart = index + 1
            }
            index += 1
        }
        let prefix = String(decoding: utf8[lineStart..<offset], as: UTF8.self)
        return (line, prefix.count + 1)
    }
}
