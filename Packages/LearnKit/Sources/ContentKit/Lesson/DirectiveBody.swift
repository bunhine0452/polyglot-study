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
            let text = child.format(options: proseFormat).trimmedWhitespace()
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

    /// 산문 포맷 옵션. 기본값과 다른 곳은 둘 — 순서 없는 목록의 불릿을 `-` 로 고정하고
    /// 코드 블록을 항상 펜스로 낸다. 포맷터가 라운드트립마다 표기를 바꾸면 같은 레슨이
    /// 서로 다른 문자열이 된다.
    ///
    /// `let` 이 아니라 계산 프로퍼티인 이유는 `MarkupFormatter.Options` 가 `Sendable`
    /// 이 아니라서 전역 상수로 둘 수 없기 때문이다.
    private static var proseFormat: MarkupFormatter.Options {
        MarkupFormatter.Options(unorderedListMarker: .dash, useCodeFence: .always)
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
