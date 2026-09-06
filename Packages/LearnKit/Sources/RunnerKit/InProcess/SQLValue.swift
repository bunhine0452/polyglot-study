public import Foundation

/// SQLite 한 셀의 값. 저장 클래스 5종을 그대로 옮긴 것이다.
///
/// - Note: `TEXT` 인데 UTF-8 로 디코드되지 않는 바이트열은 `.blob` 으로 온다.
///   손실 디코딩(`�` 치환)을 하면 채점이 조용히 틀리고, 비UTF8 출력 계약도 못 지킨다.
public enum SQLValue: Hashable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)

    /// 채점용 정규화. **INTEGER 10 과 REAL 10.0 을 같은 값으로 접는다.**
    ///
    /// `SELECT 10` 과 `SELECT avg(x)` 가 같은 답이어야 하는데 저장 클래스만 다른 경우가
    /// 실제 레슨에서 계속 나온다. 반대로 `NULL`·`''`·`0` 은 서로 다른 케이스라 절대 안 접힌다.
    public var normalizedForGrading: SQLValue {
        guard case .real(let double) = self else { return self }
        // Int64(exactly:) 는 소수부가 있거나 Int64 범위를 넘거나 NaN/Inf 면 nil 이다.
        guard let integer = Int64(exactly: double) else { return self }
        return .integer(integer)
    }

    /// 표 프리젠터가 그대로 찍을 수 있는 문자열.
    public var displayText: String {
        switch self {
        case .null: "NULL"
        case .integer(let value): String(value)
        case .real(let value): String(value)
        case .text(let value): value
        case .blob(let data): "x'" + data.map { String(format: "%02X", $0) }.joined() + "'"
        }
    }

    /// 콘솔로 흘려보낼 원시 바이트. BLOB 은 바이트 그대로 나간다 — stdout 은 바이트 스트림이고,
    /// 여기서 hex 로 바꿔버리면 비UTF8 출력이 파이프라인을 통과하는지 영영 검증할 수 없다.
    public var outputBytes: Data {
        switch self {
        case .null: Data("NULL".utf8)
        case .integer(let value): Data(String(value).utf8)
        case .real(let value): Data(String(value).utf8)
        case .text(let value): Data(value.utf8)
        case .blob(let data): data
        }
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}
