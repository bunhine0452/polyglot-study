import Foundation
import SwiftUI
import Testing

@testable import DesignSystem

@Suite("산문 렌더러 · 인라인 위임")
struct ProseInlineTests {
    static let style = InlineMarkdown.Style(
        base: .system(size: 15),
        mono: .system(size: 12.5, design: .monospaced),
        color: Palette.ink,
        codeColor: Palette.ink
    )

    /// 인라인 의도별로 런을 모은다. 폰트 객체를 비교하는 대신 **어떤 의도가 어느 글자에
    /// 붙었는지**를 본다 — 그게 위임이 실제로 동작했다는 증거다.
    static func runs(_ source: String) -> [(text: String, intent: InlinePresentationIntent?)] {
        let attributed = InlineMarkdown.attributed(source, style: style)
        return attributed.runs.map {
            (String(attributed[$0.range].characters), $0.inlinePresentationIntent)
        }
    }

    @Test("굵게·기울임·코드스팬을 AttributedString 이 알아본다")
    func inlineIntents() {
        let runs = Self.runs("보통 **굵게** *기울임* `코드`")
        let strong = runs.first { $0.intent?.contains(.stronglyEmphasized) == true }
        let emphasized = runs.first {
            $0.intent?.contains(.emphasized) == true && $0.intent?.contains(.stronglyEmphasized) != true
        }
        let code = runs.first { $0.intent?.contains(.code) == true }
        #expect(strong?.text == "굵게")
        #expect(emphasized?.text == "기울임")
        #expect(code?.text == "코드")
    }

    @Test("마크업 기호는 결과 문자열에 남지 않는다")
    func markupIsConsumed() {
        let text = String(InlineMarkdown.attributed("**굵게** `코드`", style: Self.style).characters)
        #expect(text == "굵게 코드")
    }

    @Test("링크는 색이 아니라 밑줄로 구별한다 — 색은 통과·실패에만 쓴다")
    func linksAreUnderlined() {
        let attributed = InlineMarkdown.attributed("[문서](https://example.com)", style: Self.style)
        let linked = attributed.runs.first { $0.link != nil }
        #expect(linked != nil)
        #expect(linked?.underlineStyle == .single)
        #expect(linked?.foregroundColor == Palette.ink)
    }

    @Test("공백 보존 모드라 강제 개행이 살아 있다")
    func whitespaceIsPreserved() {
        let text = String(InlineMarkdown.attributed("앞\n뒤", style: Self.style).characters)
        #expect(text == "앞\n뒤")
    }

    @Test("블록 문법은 인라인 모드에서 해석되지 않는다")
    func blockSyntaxStaysLiteral() {
        // 문단 스캐너가 이미 자른 뒤라 여기에 블록이 오면 안 되지만, 와도 글자로만 남아야 한다.
        let text = String(InlineMarkdown.attributed("# 제목", style: Self.style).characters)
        #expect(text == "# 제목")
    }

    @Test("깨진 마크업도 글자는 잃지 않는다")
    func brokenMarkupKeepsText() {
        let text = String(InlineMarkdown.attributed("**닫히지 않음", style: Self.style).characters)
        #expect(text.contains("닫히지 않음"))
    }

    @Test("평문 변환이 마크업을 벗긴다")
    func plainText() {
        #expect(InlineMarkdown.plainText("**굵게** 와 `코드`") == "굵게 와 코드")
    }
}

@Suite("산문 렌더러 · 한 줄 요약")
struct ProseSummaryTests {
    @Test("첫 문단의 첫 문장만 남는다")
    func firstSentenceOnly() {
        let summary = ProseSummary.headline("첫 문장이다. 둘째 문장이다.\n\n다른 문단.")
        #expect(summary == "첫 문장이다.")
    }

    @Test("마크업을 벗긴다")
    func stripsMarkup() {
        #expect(ProseSummary.headline("`Optional` 은 **타입**이다.") == "Optional 은 타입이다.")
    }

    @Test("소수점과 확장자에서 끊기지 않는다")
    func doesNotBreakOnDecimals() {
        #expect(ProseSummary.firstSentence(of: "3.14 는 파이다.") == "3.14 는 파이다.")
        #expect(ProseSummary.firstSentence(of: "main.py 를 실행한다.") == "main.py 를 실행한다.")
    }

    @Test("물음표·느낌표도 문장 끝이다")
    func questionAndExclamation() {
        #expect(ProseSummary.firstSentence(of: "무엇인가? 다음 문장.") == "무엇인가?")
        #expect(ProseSummary.firstSentence(of: "조심! 다음 문장.") == "조심!")
    }

    @Test("길면 말줄임표로 자른다")
    func truncates() {
        let long = String(repeating: "가", count: 100)
        let summary = ProseSummary.headline(long, limit: 10)
        #expect(summary.count == 11)
        #expect(summary.hasSuffix("…"))
    }

    @Test("코드 블록만 있는 산문은 빈 요약")
    func codeOnlyHasNoHeadline() {
        #expect(ProseSummary.headline("```\ncode\n```") == "")
    }

    @Test("목록만 있으면 첫 항목이 요약이 된다")
    func listHeadline() {
        #expect(ProseSummary.headline("- 첫 항목입니다.\n- 둘째") == "첫 항목입니다.")
    }
}

@Suite("산문 렌더러 · 뷰 조립")
struct ProseViewTests {
    @Test("뷰가 들고 있는 블록이 파서 결과와 같다")
    func viewParsesOnce() {
        let source = "# 제목\n\n문단.\n\n```\ncode\n```"
        #expect(ProseView(source).parsedBlocks == ProseParser.parse(source))
    }

    @Test("코드 블록의 꼬리 개행은 빈 줄로 그려지지 않는다")
    func codeBlockTrimsTrailingNewlines() {
        #expect(ProseCodeBlock("let x = 1\n\n").displayedCode == "let x = 1")
    }

    @Test("두 크기의 행간과 본문 크기가 서로 다르다")
    func scalesDiffer() {
        #expect(ProseView.Scale.allCases.count == 2)
        #expect(ProseView.Scale.body.baseSize == .body)
        #expect(ProseView.Scale.compact.baseSize == .label)
        #expect(ProseView.Scale.body.lineSpacing > ProseView.Scale.compact.lineSpacing)
    }

    @Test("제목 단계가 커질수록 글자가 작아진다 — 역전이 없다")
    func headingScaleIsMonotonic() {
        let sizes = (1...6).map { ProseView.Scale.body.headingSize(level: $0).rawValue }
        #expect(sizes == sizes.sorted(by: >))
        #expect(sizes.first == Typography.Sans.title.rawValue)
    }
}
