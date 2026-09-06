internal import Markdown

/// 디렉티브 본문에서 값을 꺼내는 자리. **여기가 `Markup` 의 마지막 경계**다 —
/// 나가는 것은 전부 `String` 이거나 `Int` 다.
enum Body {
    /// 산문을 마크다운 **소스**로 되돌린다.
    ///
    /// `AttributedString` 이나 평문이 아니라 소스인 이유는 렌더러가 아직 정해지지
    /// 않았기 때문이다. Textual 로 태우든 자체 렌더러를 쓰든 입력은 마크다운이고,
    /// 소스를 들고 있으면 둘 다 된다. 트리를 들고 있으면 둘 다 안 된다(`Sendable` 아님).
    ///
    /// - Parameter includingCode: 펜스 코드 블록을 산문에 포함할지. `@Example`·`@Blank`
    ///   는 코드 블록이 **본문의 payload** 라서 산문에서 뺀다.
    static func prose(of directive: BlockDirective, includingCode: Bool) -> String {
        var pieces: [String] = []
        for child in directive.children {
            if child is BlockDirective { continue }
            if !includingCode && child is CodeBlock { continue }
            // `detachedFromParent` 가 이 함수의 정확성을 쥐고 있다. 아래 `proseFormat`
            // 주석을 보라 — 붙어 있는 노드를 그대로 포맷하면 디렉티브 깊이만큼 들여쓰기가
            // 새어 들어온다.
            let text = child.detachedFromParent.format(options: proseFormat).trimmedWhitespace()
            if !text.isEmpty { pieces.append(text) }
        }
        return pieces.joined(separator: "\n\n")
    }

    /// 본문 안의 펜스 코드 블록 정확히 하나.
    static func singleCodeBlock(of directive: BlockDirective) throws(LessonParseError)
        -> (code: String, language: String?)
    {
        let blocks = directive.children.compactMap { $0 as? CodeBlock }
        guard let first = blocks.first else {
            throw LessonParseError(
                .missingCodeBlock(directive: directive.name), at: .at(directive.nameLocation))
        }
        guard blocks.count == 1 else {
            throw LessonParseError(
                .multipleCodeBlocks(directive: directive.name),
                at: .at(blocks[1].range?.lowerBound))
        }
        return (first.code, first.language)
    }

    /// 이름이 맞는 직계 하위 디렉티브를 문서 순서대로.
    static func childDirectives(of directive: BlockDirective, named name: String)
        -> [BlockDirective]
    {
        directive.children.compactMap { $0 as? BlockDirective }.filter { $0.name == name }
    }

    /// 본문의 평문. 인라인 코드는 백틱을 벗기고 알맹이만 남긴다.
    ///
    /// `@Answer` 정답에 쓴다. 정답은 보통 `` `range` `` 처럼 인라인 코드로 쓰이는데,
    /// 렌더된 마크다운을 그대로 답으로 삼으면 백틱이 정답의 일부가 되어 채점이 틀린다.
    static func plainText(of directive: BlockDirective) -> String {
        var walker = PlainTextWalker()
        for child in directive.children where !(child is BlockDirective) {
            walker.visit(child)
        }
        return walker.text.trimmedWhitespace()
    }

    /// 산문 포맷 옵션. 기본값과 다른 곳은 셋 — 순서 없는 목록의 불릿을 `-` 로 고정하고,
    /// 순서 있는 목록의 번호를 증가시키고, 코드 블록을 항상 펜스로 낸다. 포맷터가
    /// 라운드트립마다 표기를 바꾸면 같은 레슨이 서로 다른 문자열이 된다.
    ///
    /// ## 왕복 결함 둘 — 여기와 ``prose(of:includingCode:)`` 가 함께 막는다
    ///
    /// **1. 디렉티브 깊이만큼의 들여쓰기.** `MarkupFormatter.linePrefix(for:)` 는 노드의
    /// **조상 사슬 전체**를 훑어 `parent is BlockDirective` 인 단계마다 4칸을 붙인다.
    /// 디렉티브 본문의 자식을 붙어 있는 채로 포맷하면 모든 줄이 (깊이 × 4)칸 밀리고,
    /// `trimmedWhitespace()` 는 문자열 양 끝만 깎으므로 **첫 줄만** 되돌아온다. 실측된
    /// 결과 — 평평한 목록 `- 첫째 / - 둘째` 가 `- 첫째\n    - 둘째` 로 나와 CommonMark
    /// 로 다시 읽으면 중첩 목록이 되고, 인용은 `>     인용` 이 되어 인용 안이 들여쓰기
    /// 코드블록이 되며, 코드 펜스는 본문과 **닫는 펜스**까지 밀린다. `@Hint`·`@Choice`
    /// 처럼 깊이 2인 자리는 8칸이다. 그래서 포맷 전에 `detachedFromParent` 로 노드를
    /// 떼어낸다 — 그 순간 조상 사슬이 없어져 접두사가 0이 된다.
    ///
    /// **2. 번호 재작성.** 기본값 `.allSame(1)` 은 `1. 하나 / 2. 둘` 을 `1. / 1.` 로
    /// 내놓는다. 마크다운 렌더러는 그래도 1,2 로 세지만, 이 문자열은 렌더러 말고
    /// `packtool` 리포트와 튜터 RAG 도 그대로 받는다 — 거기서는 원문과 다른 글자다.
    ///
    /// - Note: 저자가 `3.` 부터 시작한 목록은 여전히 `1.` 로 재작성된다. swift-markdown
    ///   이 시작 번호를 보존하지 않는 문제(업스트림 #76, `numeralPrefix(for:)` 의
    ///   FIXME)라 옵션으로는 막을 수 없다. `.incrementing` 은 그중 재현 가능한 절반 —
    ///   항목 사이의 증가 — 을 되찾는다.
    ///
    /// `let` 이 아니라 계산 프로퍼티인 이유는 `MarkupFormatter.Options` 가 `Sendable`
    /// 이 아니라서 전역 상수로 둘 수 없기 때문이다.
    private static var proseFormat: MarkupFormatter.Options {
        MarkupFormatter.Options(
            unorderedListMarker: .dash,
            orderedListNumerals: .incrementing(start: 1),
            useCodeFence: .always)
    }

    /// 블록 노드를 평문으로. 문단 사이는 개행 두 개.
    private struct PlainTextWalker: MarkupWalker {
        var text = ""

        mutating func visitText(_ node: Markdown.Text) { text += node.string }
        mutating func visitInlineCode(_ node: InlineCode) { text += node.code }
        mutating func visitCodeBlock(_ node: CodeBlock) { text += node.code }
        mutating func visitSoftBreak(_ node: SoftBreak) { text += "\n" }
        mutating func visitLineBreak(_ node: LineBreak) { text += "\n" }
        mutating func visitParagraph(_ node: Paragraph) {
            if !text.isEmpty { text += "\n\n" }
            descendInto(node)
        }
    }
}
