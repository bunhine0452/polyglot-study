internal import Foundation

/// 접힌 행의 **한 줄 요약**. 서식을 그릴 수 없는 자리에서 산문을 대표하는 문장 하나를 뽑는다.
///
/// 요약을 화면 계층이 각자 만들면 같은 레슨이 화면마다 다르게 접힌다. 마크업을 벗기는
/// 일도 인라인 파서를 다시 쓰는 셈이라, 여기 한 곳에 모은다.
public enum ProseSummary {
    /// 첫 문단(없으면 첫 제목)의 첫 문장. 길면 말줄임표로 자른다.
    ///
    /// - Parameter limit: 자르기 전 최대 글자 수. 0 이하면 자르지 않는다.
    public static func headline(_ markdown: String, limit: Int = 48) -> String {
        guard let source = firstTextualSource(in: ProseParser.parse(markdown)) else { return "" }
        let plain = InlineMarkdown.plainText(source)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmed
        let sentence = firstSentence(of: plain)
        guard limit > 0, sentence.count > limit else { return sentence }
        let head = sentence.prefix(limit).trimmed
        return head + "…"
    }

    private static func firstTextualSource(in blocks: [ProseBlock]) -> String? {
        for block in blocks {
            switch block {
            case .paragraph(let text), .heading(_, let text):
                if !text.trimmed.isEmpty { return text }
            case .list(let list):
                for item in list.items {
                    if let found = firstTextualSource(in: item) { return found }
                }
            case .blockquote(let children):
                if let found = firstTextualSource(in: children) { return found }
            case .code, .thematicBreak:
                continue
            }
        }
        return nil
    }

    /// 첫 문장. 마침표·물음표·느낌표에서 끊고, 없으면 통째로 돌려준다.
    ///
    /// 소수점(`3.14`)이나 확장자(`main.py`)에서 끊기지 않도록 마침표 **다음이 공백이거나
    /// 끝**일 때만 문장 끝으로 본다.
    static func firstSentence(of text: String) -> String {
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            if character == "?" || character == "!" {
                return String(text[..<next]).trimmed
            }
            if character == "." {
                if next == text.endIndex || text[next] == " " {
                    return String(text[..<next]).trimmed
                }
            }
            index = next
        }
        return text.trimmed
    }
}
