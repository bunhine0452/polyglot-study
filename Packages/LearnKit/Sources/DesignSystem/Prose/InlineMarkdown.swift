internal import Foundation
internal import SwiftUI

/// 인라인 마크다운의 **전부**. 강조·굵게·코드스팬·링크·취소선을 직접 파싱하지 않고
/// `AttributedString(markdown:options:)` 에 넘긴다(macOS 12+).
///
/// `.inlineOnlyPreservingWhitespace` 를 쓰는 이유는 둘이다.
///   1. 블록 구조를 해석하지 않으므로 ``ProseParser`` 가 이미 자른 문단을 다시 자르지 않는다.
///   2. 공백을 보존하므로 문단 스캐너가 만든 강제 개행(`\n`)이 그대로 살아 있다.
enum InlineMarkdown {
    /// 인라인 런에 입힐 서체 묶음.
    struct Style {
        var base: Font
        var mono: Font
        var color: Color
        var codeColor: Color
    }

    static func attributed(_ source: String, style: Style) -> AttributedString {
        var result: AttributedString
        do {
            result = try AttributedString(
                markdown: source,
                options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: false,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
        } catch {
            // 파싱이 통째로 실패해도 글자는 보여야 한다 — 마크업만 잃는다.
            result = AttributedString(source)
        }

        result.font = style.base
        result.foregroundColor = style.color

        // 런을 순회하면서 같은 값을 고치면 반복자가 무효화된다. 범위를 먼저 걷어 온다.
        let runs = result.runs.map {
            (range: $0.range, intent: $0.inlinePresentationIntent, isLink: $0.link != nil)
        }
        for run in runs {
            var container = AttributeContainer()
            let intent = run.intent ?? []
            if intent.contains(.code) {
                container.font = style.mono
                container.foregroundColor = style.codeColor
            } else {
                let strong = intent.contains(.stronglyEmphasized)
                let emphasized = intent.contains(.emphasized)
                if strong || emphasized {
                    var font = style.base
                    if strong { font = font.weight(.semibold) }
                    if emphasized { font = font.italic() }
                    container.font = font
                }
            }
            if intent.contains(.strikethrough) {
                container.strikethroughStyle = .single
            }
            // 색을 강조에 쓰지 않는 디자인이라 링크는 밑줄로만 구별한다.
            if run.isLink { container.underlineStyle = .single }
            result[run.range].mergeAttributes(container)
        }
        return result
    }

    /// 마크업을 벗긴 평문. 접힌 블록의 한 줄 요약처럼 서식을 그릴 수 없는 자리에 쓴다.
    static func plainText(_ source: String) -> String {
        let attributed =
            (try? AttributedString(
                markdown: source,
                options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: false,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )) ?? AttributedString(source)
        return String(attributed.characters)
    }
}
