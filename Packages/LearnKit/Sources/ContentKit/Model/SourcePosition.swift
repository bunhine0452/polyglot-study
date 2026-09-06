/// 레슨 소스 안의 한 지점. 1-기반 줄·열.
///
/// swift-markdown 의 `SourceRange` 를 그대로 쓰지 않는 이유는 하나다 — `Markup` 계열
/// 타입을 파싱 경계 밖으로 내보내지 않기로 했기 때문이다. `SourceLocation` 자체는
/// `Sendable` 이지만 그걸 공개하면 "위치를 얻으려면 Markdown 을 import 해야 한다"가
/// 되고, 그 순간 `LessonBlock` 을 쓰는 nonisolated 코어와 UI 가 파서의 의존성을
/// 함께 끌고 다니게 된다. 위치는 값 두 개면 충분하다.
public struct SourcePosition: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    /// 1-기반. 위치를 알 수 없으면 0.
    public var line: Int
    /// 1-기반. 위치를 알 수 없으면 0.
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    /// 위치 정보가 없는 지점. 손으로 만든 블록이나 범위 없는 노드에 쓴다.
    public static let unknown = SourcePosition(line: 0, column: 0)

    public var isKnown: Bool { line > 0 }

    /// 에러 메시지에 붙는 표준 형태. `line:column` 이 그대로 나온다.
    public var description: String { "\(line):\(column)" }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.line, lhs.column) < (rhs.line, rhs.column)
    }
}

/// 소스 상의 반열린 구간. 블록 하나가 차지한 영역을 가리킨다.
public struct SourceSpan: Hashable, Sendable, Codable, CustomStringConvertible {
    public var start: SourcePosition
    public var end: SourcePosition

    public init(start: SourcePosition, end: SourcePosition) {
        self.start = start
        self.end = end
    }

    public static let unknown = SourceSpan(start: .unknown, end: .unknown)

    public var description: String { "\(start)-\(end)" }
}
