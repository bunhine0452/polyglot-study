public import SwiftUI

/// 마크다운 산문 렌더러. 레슨 본문·힌트·해설·회고 질문이 전부 이걸로 그려진다.
///
/// 인라인은 `AttributedString` 이, 블록은 ``ProseParser`` + 이 뷰가 맡는다.
/// 코드 블록만 예외로 ``ProseCodeBlock`` 이라는 전용 뷰로 빠진다 —
/// `AttributedString` 을 지나면 모노 폰트와 가로 스크롤을 둘 다 잃는다.
public struct ProseView: View {
    /// 산문이 놓이는 자리의 크기. 카드 본문은 `.body`, 힌트·해설처럼 접혀 있는
    /// 보조 산문은 `.compact`.
    public enum Scale: Sendable, CaseIterable {
        case body
        case compact
    }

    private let blocks: [ProseBlock]
    private let scale: Scale

    public init(_ markdown: String, scale: Scale = .body) {
        self.blocks = ProseParser.parse(markdown)
        self.scale = scale
    }

    public init(blocks: [ProseBlock], scale: Scale = .body) {
        self.blocks = blocks
        self.scale = scale
    }

    /// 파싱 결과. 렌더 없이 단언하기 위해 모듈 안에 열어 둔다.
    var parsedBlocks: [ProseBlock] { blocks }

    public var body: some View {
        VStack(alignment: .leading, spacing: ProseMetrics.blockGap) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                ProseBlockView(block: block, scale: scale)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 블록 하나. 중첩(목록 항목·인용 본문)에서는 ``ProseView`` 를 다시 부르는데,
/// 그 자리를 `AnyView` 로 끊는다 — 끊지 않으면 두 뷰의 `body` 타입이 서로를 참조해
/// 순환한다.
struct ProseBlockView: View {
    let block: ProseBlock
    let scale: ProseView.Scale

    var body: some View {
        switch block {
        case .paragraph(let source):
            ProseParagraph(source: source, style: scale.inlineStyle, lineSpacing: scale.lineSpacing)
        case .heading(let level, let text):
            ProseParagraph(
                source: text,
                style: scale.headingStyle(level: level),
                lineSpacing: ProseMetrics.headingLineSpacing
            )
        case .list(let list):
            ProseListView(list: list, scale: scale)
        case .blockquote(let children):
            AnyView(ProseView(blocks: children, scale: scale))
                .padding(.leading, ProseMetrics.quoteIndent)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Palette.ruleHard)
                        .frame(width: Rules.emphasisThickness)
                }
        case .code(let code):
            ProseCodeBlock(code.text, language: code.language)
        case .thematicBreak:
            Rule(.soft)
        }
    }
}

/// 문단 한 개. 제목도 크기만 다른 같은 뷰다 — 인라인 처리가 완전히 같아야 한다.
struct ProseParagraph: View {
    let source: String
    let style: InlineMarkdown.Style
    let lineSpacing: CGFloat

    var body: some View {
        Text(InlineMarkdown.attributed(source, style: style))
            .lineSpacing(lineSpacing)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProseListView: View {
    let list: ProseList
    let scale: ProseView.Scale

    var body: some View {
        VStack(alignment: .leading, spacing: ProseMetrics.listItemGap) {
            ForEach(Array(list.items.enumerated()), id: \.offset) { offset, item in
                HStack(alignment: .top, spacing: 0) {
                    marker(at: offset)
                        .frame(width: ProseMetrics.markerColumn, alignment: .leading)
                    AnyView(ProseView(blocks: item, scale: scale))
                }
            }
        }
    }

    /// 마커를 본문 첫 줄의 시각적 중심에 맞춘다. 베이스라인 정렬을 쓰지 않는 이유는
    /// 불릿이 사각형이라 베이스라인이라는 것이 없기 때문이다.
    @ViewBuilder
    private func marker(at offset: Int) -> some View {
        let lineHeight = scale.baseSize.rawValue + scale.lineSpacing
        if list.isOrdered {
            MonoText("\(list.start + offset).", size: .label, color: Palette.secondary)
                .padding(.top, (lineHeight - Typography.Mono.label.rawValue) / 2)
        } else {
            Rectangle()
                .fill(Palette.faint)
                .frame(width: ProseMetrics.bulletSize, height: ProseMetrics.bulletSize)
                .padding(.top, (lineHeight - ProseMetrics.bulletSize) / 2)
        }
    }
}
