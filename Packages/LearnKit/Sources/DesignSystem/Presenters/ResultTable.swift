/// 표 프리젠터가 그리는 것. `LearnCore.ResultSet` 을 표시용으로 옮긴 것이고,
/// 기대 결과와의 diff 표식을 행·셀에 얹을 수 있다.
///
/// 옮겨 담는 이유는 ``ResultPresentation`` 과 같다 — `DesignSystem` 은 `LearnCore` 를
/// 모른다. 대신 여기 있는 것은 **문자열과 표식뿐**이라, SQLite 저장 클래스 5종이
/// 디자인 시스템까지 올라오지 않는다.
public struct ResultTable: Hashable, Sendable {
    public struct Column: Hashable, Sendable {
        public var name: String
        /// 백엔드가 선언 타입을 아는 경우에만.
        public var declaredType: String?

        public init(name: String, declaredType: String? = nil) {
            self.name = name
            self.declaredType = declaredType
        }
    }

    /// 행 하나가 기대 결과와 어떻게 다른가. 색은 여기서만 나온다.
    public enum Mark: String, Hashable, Sendable, CaseIterable {
        /// 기대와 같다.
        case match
        /// 기대에는 있는데 결과에 없다.
        case missing
        /// 결과에만 있다.
        case unexpected
    }

    public struct Cell: Hashable, Sendable {
        public var text: String
        public var isNull: Bool
        public var isMismatch: Bool

        public init(text: String, isNull: Bool = false, isMismatch: Bool = false) {
            self.text = text
            self.isNull = isNull
            self.isMismatch = isMismatch
        }
    }

    public struct Row: Hashable, Sendable, Identifiable {
        public let id: Int
        public var cells: [Cell]
        public var mark: Mark

        public init(id: Int, cells: [Cell], mark: Mark = .match) {
            self.id = id
            self.cells = cells
            self.mark = mark
        }
    }

    public var columns: [Column]
    public var rows: [Row]
    public var isTruncated: Bool

    public init(columns: [Column], rows: [Row] = [], isTruncated: Bool = false) {
        self.columns = columns
        self.rows = rows
        self.isTruncated = isTruncated
    }

    public static let empty = ResultTable(columns: [])

    public var isEmpty: Bool { columns.isEmpty && rows.isEmpty }
    public var rowCount: Int { rows.count }
    public var columnCount: Int { columns.count }
    public var hasDifferences: Bool { rows.contains { $0.mark != .match } }
}
