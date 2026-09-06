/// 산문 렌더러가 그리는 블록 다섯 + 코드 하나.
///
/// **인라인 요소는 여기 없다.** 강조·코드스팬·링크·취소선은 전부 ``InlineMarkdown`` 이
/// `AttributedString(markdown:options:)` 의 `.inlineOnlyPreservingWhitespace` 에
/// 위임한다(macOS 12+). 직접 만드는 것은 블록 구조뿐이고, 그래서 이 렌더러가 작다.
///
/// 코드 블록이 목록에 있는 것은 **인식**하기 위해서다 — 문단 스캐너가 펜스 안쪽을
/// 산문으로 오해하면 안 된다. 그리는 것은 산문 경로가 아니라 전용 ``ProseCodeBlock`` 이다.
/// 코드가 `AttributedString` 을 지나면 모노 폰트와 가로 스크롤이 둘 다 죽는다.
public enum ProseBlock: Hashable, Sendable {
    /// 인라인 마크다운 **소스**. 소프트 개행은 이미 공백으로 접혀 있다.
    case paragraph(String)
    /// `level` 은 1...6.
    case heading(level: Int, text: String)
    case list(ProseList)
    case blockquote([ProseBlock])
    case code(ProseCode)
    case thematicBreak
}

/// 목록 하나. 항목마다 블록 배열을 갖는다 — 항목 안에 문단·코드·중첩 목록이 올 수 있다.
public struct ProseList: Hashable, Sendable {
    public var isOrdered: Bool
    /// 순서 있는 목록의 시작 번호. 순서 없는 목록에서는 무의미하다.
    public var start: Int
    public var items: [[ProseBlock]]

    public init(isOrdered: Bool, start: Int = 1, items: [[ProseBlock]]) {
        self.isOrdered = isOrdered
        self.start = start
        self.items = items
    }
}

/// 펜스 코드 블록. `language` 는 info string 의 첫 낱말.
public struct ProseCode: Hashable, Sendable {
    public var language: String?
    public var text: String

    public init(language: String? = nil, text: String) {
        self.language = language
        self.text = text
    }
}

extension ProseBlock {
    /// 파싱 결과를 렌더 없이 단언하기 위한 창구. 뷰 분기와는 무관하다.
    public var kindName: String {
        switch self {
        case .paragraph: "paragraph"
        case .heading: "heading"
        case .list: "list"
        case .blockquote: "blockquote"
        case .code: "code"
        case .thematicBreak: "thematicBreak"
        }
    }
}
