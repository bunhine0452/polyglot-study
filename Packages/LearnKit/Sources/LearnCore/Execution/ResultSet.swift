public import struct Foundation.Data

/// 실행이 낸 **구조화된 표**. 바이트 스트림과 나란히 흐르는 두 번째 결과 통로다.
///
/// `RunEvent` 가 바이트뿐이면 결과셋은 스트림으로 나갈 방법이 없고, 표 프리젠터는 결국
/// SQL 백엔드의 구체 타입을 알아야만 한다 — 그게 `Presenter.table` 이 언어 중립을
/// 잃는 근본 원인이다. 그래서 표는 여기서 언어 중립으로 정규화되고, SQL·컨테이너·
/// 에뮬레이터 어느 백엔드가 채워 넣든 UI 는 같은 타입 하나만 그린다.
public struct ResultSet: Hashable, Sendable {
    public struct Column: Hashable, Sendable {
        public var name: String
        /// 백엔드가 선언 타입을 아는 경우에만 (SQLite 의 `decltype` 등).
        public var declaredType: String?

        public init(name: String, declaredType: String? = nil) {
            self.name = name
            self.declaredType = declaredType
        }
    }

    /// 셀 하나. SQLite 저장 클래스 5종을 그대로 옮긴 것이고, 다른 백엔드도 여기에 맞춘다.
    ///
    /// - Note: 텍스트인데 UTF-8 로 디코드되지 않는 바이트열은 `.blob` 으로 온다.
    ///   손실 디코딩(`�` 치환)을 하면 채점이 조용히 틀리고 비UTF8 출력 계약도 깨진다.
    public enum Value: Hashable, Sendable {
        case null
        case integer(Int64)
        case real(Double)
        case text(String)
        case blob(Data)
    }

    public var columns: [Column]
    public var rows: [[Value]]
    /// 상한에 걸려 잘렸는가.
    public var isTruncated: Bool

    public init(columns: [Column], rows: [[Value]] = [], isTruncated: Bool = false) {
        self.columns = columns
        self.rows = rows
        self.isTruncated = isTruncated
    }

    public var rowCount: Int { rows.count }
    public var columnCount: Int { columns.count }
}

extension ResultSet.Value {
    /// 표 프리젠터가 그대로 찍을 수 있는 문자열.
    public var displayText: String {
        switch self {
        case .null: "NULL"
        case .integer(let value): String(value)
        case .real(let value): String(value)
        case .text(let value): value
        case .blob(let data): "x'" + data.map(Self.hex(_:)).joined() + "'"
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

    /// 바이트 하나를 두 자리 대문자 hex 로. `String(format:)` 을 쓰지 않는 이유는
    /// LearnCore 가 Foundation 전체가 아니라 `Data` 한 타입만 가져오기 때문이다.
    private static func hex(_ byte: UInt8) -> String {
        let digits = "0123456789ABCDEF"
        let high = digits[digits.index(digits.startIndex, offsetBy: Int(byte >> 4))]
        let low = digits[digits.index(digits.startIndex, offsetBy: Int(byte & 0x0F))]
        return String([high, low])
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}
