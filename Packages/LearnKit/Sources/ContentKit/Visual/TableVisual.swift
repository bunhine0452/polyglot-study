/// 표 장면의 정적 정보와 프레임들.
///
/// DP(배낭·LCS)가 이 장면을 쓴다. 그리드 크기는 저작 시점에 고정되고, 프레임마다
/// 채워지는 칸이 늘어난다 — 이미 채운 칸을 지우거나 값을 바꾸는 시각화는 v1 범위
/// 밖이다(DP 는 앞으로만 채우지 되돌리지 않는다).
public struct TableVisual: Hashable, Sendable {
    /// 행 머리글. 배낭이라면 "무게 0..W", LCS 라면 두 번째 문자열의 접두사들.
    public var rowHeaders: [String]
    /// 열 머리글. 배낭이라면 품목 번호, LCS 라면 첫 번째 문자열의 접두사들.
    ///
    /// 행·열 크기를 별도 정수 필드로 두지 않고 머리글 배열의 개수로 삼는다 — `rows: 5`
    /// 와 `rowHeaders.count == 5` 를 따로 적으면 굽는 도구가 언젠가 둘을 어긋나게
    /// 만들고, 그러면 "크기가 틀렸다"는 검증 케이스가 하나 더 필요해진다. 표는 항상
    /// 머리글이 있어야 렌더러가 축을 그릴 수 있으므로 잃는 표현력이 없다.
    public var columnHeaders: [String]
    public var frames: [TableFrame]

    public var rowCount: Int { rowHeaders.count }
    public var columnCount: Int { columnHeaders.count }

    /// 모든 프레임의 칸과 참조가 `rowHeaders`×`columnHeaders` 범위 안에 있고, 자막이
    /// 비지 않았을 때만 만들어진다.
    public init(rowHeaders: [String], columnHeaders: [String], frames: [TableFrame])
        throws(VisualFrameSetError)
    {
        guard !rowHeaders.isEmpty, !columnHeaders.isEmpty else { throw .emptyTable }
        guard !frames.isEmpty else { throw .noFrames }

        func inBounds(row: Int, column: Int) -> Bool {
            (0..<rowHeaders.count).contains(row) && (0..<columnHeaders.count).contains(column)
        }

        for (frameIndex, frame) in frames.enumerated() {
            guard !frame.caption.isEmpty else { throw .emptyCaption(frameIndex: frameIndex) }
            for cell in frame.cells {
                guard inBounds(row: cell.row, column: cell.column) else {
                    throw .cellOutOfBounds(
                        frameIndex: frameIndex, row: cell.row, column: cell.column,
                        rows: rowHeaders.count, columns: columnHeaders.count)
                }
                for reference in cell.from {
                    guard inBounds(row: reference.row, column: reference.column) else {
                        throw .cellOutOfBounds(
                            frameIndex: frameIndex, row: reference.row, column: reference.column,
                            rows: rowHeaders.count, columns: columnHeaders.count)
                    }
                }
            }
        }

        self.rowHeaders = rowHeaders
        self.columnHeaders = columnHeaders
        self.frames = frames
    }
}

/// 표 칸에서 칸으로의 참조. DP 점화식이 어느 칸을 보고 지금 칸을 채웠는지 — LCS 라면
/// 대각선 한 칸, 배낭이라면 바로 위 행의 칸 하나 또는 둘.
public struct TableCellRef: Hashable, Sendable, Codable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

/// 칸의 상태. 색이 아니라 "이 칸이 지금 어떤 단계인가"만 담는다.
public enum TableCellRole: String, Hashable, Sendable, Codable, CaseIterable {
    /// 점화식 없이 바로 정해지는 값 — 첫 행·첫 열의 초기값.
    case base
    /// 지금 이 프레임에서 막 계산되는 칸.
    case current
    /// 이전 프레임에서 이미 계산이 끝난 칸.
    case filled
}

/// 채워진 칸 하나.
public struct TableCell: Hashable, Sendable {
    public var row: Int
    public var column: Int
    public var value: Int
    public var role: TableCellRole
    /// 이 칸을 만든 참조 칸들. 화살표로 그릴 재료다. 참조가 없으면(`base`) 빈 배열.
    public var from: [TableCellRef]

    public init(
        row: Int, column: Int, value: Int, role: TableCellRole, from: [TableCellRef] = []
    ) {
        self.row = row
        self.column = column
        self.value = value
        self.role = role
        self.from = from
    }
}

/// 표 장면의 프레임 하나. 이전 프레임과의 **차이**가 아니라 이 시점까지 채워진 칸
/// 전부를 담는다 — 재생기가 임의의 프레임으로 뛰어도 그 앞 프레임을 순서대로 다시
/// 재생해 누적할 필요가 없다.
public struct TableFrame: Hashable, Sendable {
    public var caption: String
    public var cells: [TableCell]

    public init(caption: String, cells: [TableCell] = []) {
        self.caption = caption
        self.cells = cells
    }
}

// MARK: - Codable

extension TableCell: Codable {
    private enum CodingKeys: String, CodingKey { case row, column, value, role, from }

    /// `from` 을 생략하면 빈 배열로 본다 — `base` 칸은 점화식을 참조하지 않으므로
    /// 매번 `"from": []` 을 적어야 한다면 사이드카가 장황해진다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        row = try container.decode(Int.self, forKey: .row)
        column = try container.decode(Int.self, forKey: .column)
        value = try container.decode(Int.self, forKey: .value)
        role = try container.decode(TableCellRole.self, forKey: .role)
        from = try container.decodeIfPresent([TableCellRef].self, forKey: .from) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(row, forKey: .row)
        try container.encode(column, forKey: .column)
        try container.encode(value, forKey: .value)
        try container.encode(role, forKey: .role)
        try container.encode(from, forKey: .from)
    }
}

extension TableFrame: Codable {
    private enum CodingKeys: String, CodingKey { case caption, cells }

    /// `cells` 를 생략하면 빈 배열로 본다 — 아직 아무 칸도 채우지 않은 "시작" 프레임을
    /// 적을 때 빈 배열을 강제하지 않는다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caption = try container.decode(String.self, forKey: .caption)
        cells = try container.decodeIfPresent([TableCell].self, forKey: .cells) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(caption, forKey: .caption)
        try container.encode(cells, forKey: .cells)
    }
}

extension TableVisual: Codable {
    private enum CodingKeys: String, CodingKey { case rowHeaders, columnHeaders, frames }

    /// 모양만 읽고 곧바로 검증 초기화자에 넘긴다 — 값 자체가 틀렸으면 여기서 이미
    /// 던진다. ``PackManifest`` 처럼 "일단 다 담고 나중에 `validate()`" 로 가지 않는
    /// 이유는 ``VisualFrameSetError`` 문서에 적었다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rowHeaders = try container.decode([String].self, forKey: .rowHeaders)
        let columnHeaders = try container.decode([String].self, forKey: .columnHeaders)
        let frames = try container.decode([TableFrame].self, forKey: .frames)
        try self.init(rowHeaders: rowHeaders, columnHeaders: columnHeaders, frames: frames)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rowHeaders, forKey: .rowHeaders)
        try container.encode(columnHeaders, forKey: .columnHeaders)
        try container.encode(frames, forKey: .frames)
    }
}
