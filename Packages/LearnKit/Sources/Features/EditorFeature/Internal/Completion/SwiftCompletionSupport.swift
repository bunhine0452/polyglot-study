internal import Foundation
internal import LSPKit

/// 완성 창을 움직이는 순수 계산들. 편집기도 서버도 없이 테스트된다.
///
/// 전부 **UTF-16 오프셋**으로 논다. `CodeEditSourceEditor` 의 `CursorPosition.range`
/// 가 `NSRange` 라 그 좌표계를 그대로 쓰는 것이 변환을 한 번 줄인다.
enum SwiftCompletionSupport {
    /// Swift 식별자를 이루는 스칼라인가.
    ///
    /// 숫자를 포함하는 것은 맞다 — 식별자 **중간**에는 올 수 있고, 여기서 하는 일은
    /// "커서 앞의 낱말 조각" 을 집는 것이지 첫 글자를 판정하는 것이 아니다.
    static func isIdentifierScalar(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
    }

    /// 커서 바로 앞 글자가 트리거 문자면 그것을 돌려준다.
    ///
    /// 트리거 문자 집합은 우리가 정하지 않는다 — `initialize` 응답에서 서버가 광고한
    /// 것을 그대로 쓴다(sourcekit-lsp 는 `.` 과 `(`). 하드코딩하면 서버가 바뀔 때
    /// 조용히 어긋난다.
    static func triggerCharacter(before offset: Int, in text: String, triggers: Set<String>) -> String? {
        let ns = text as NSString
        guard offset > 0, offset <= ns.length else { return nil }
        let candidate = ns.substring(with: NSRange(location: offset - 1, length: 1))
        return triggers.contains(candidate) ? candidate : nil
    }

    /// 커서 앞의 식별자 조각 범위. 완성을 확정할 때 **이 범위를 갈아 끼운다.**
    ///
    /// 이게 없으면 `gre|` 에서 `greeting` 을 고를 때 `gregreeting` 이 된다.
    /// 트리거가 점이었다면 점 뒤에 아무 글자도 없으니 빈 범위가 나오고, 그때는
    /// 커서 자리에 그냥 끼워 넣는 것과 같아진다.
    static func replacementRange(cursorOffset: Int, in text: String) -> NSRange {
        let ns = text as NSString
        let end = min(max(cursorOffset, 0), ns.length)
        var start = end
        while start > 0 {
            let unit = ns.character(at: start - 1)
            guard let scalar = Unicode.Scalar(unit), isIdentifierScalar(scalar) else { break }
            start -= 1
        }
        return NSRange(location: start, length: end - start)
    }

    /// 커서 앞의 식별자 조각.
    static func identifierPrefix(cursorOffset: Int, in text: String) -> String {
        let range = replacementRange(cursorOffset: cursorOffset, in: text)
        guard range.length > 0 else { return "" }
        return (text as NSString).substring(with: range)
    }

    /// 이미 받아 둔 후보를 **서버에 다시 묻지 않고** 로컬로 거른다.
    ///
    /// `completionOnCursorMove` 는 동기이고 "스냅해야" 한다는 것이 CESE 의 계약이다.
    /// 글자 하나마다 왕복하면 그 계약이 깨진다 — 서버는 점을 칠 때 한 번만 부른다.
    ///
    /// 거르는 기준은 `filterText` 다. sourcekit-lsp 의 `label` 은 타입까지 들어간
    /// 시그니처(`split(separator: Character, ...)`)라 사용자가 친 글자와 맞지 않는다.
    static func filter(_ candidates: [CompletionCandidate], byPrefix prefix: String) -> [CompletionCandidate] {
        guard !prefix.isEmpty else { return candidates }
        let needle = prefix.lowercased()
        return candidates.filter { ($0.filterText ?? $0.label).lowercased().hasPrefix(needle) }
    }

    /// 후보 종류별 SF Symbol. **색은 여기서 정하지 않는다** — 이 화면은 무채색이다.
    ///
    /// 전부 "글자 하나를 사각형에 담은" 배지 계열(`v.square`, `s.square`, ...)이다 —
    /// `design/AlgorithmLesson.dc.html` 의 완성 팝업 시안이 종류를 `fn` 같은 텍스트
    /// 배지로 그린다. `.method`/`.function`/`.constructor` 만 예전에 SF Symbol
    /// `"function"`(𝑓(𝑥) 곡선 아이콘)을 썼는데, 그 배지 계열에서 혼자 이질적이었다 —
    /// `f.square` 로 맞춘다.
    static func symbolName(for kind: CompletionCandidate.Kind) -> String {
        switch kind {
        case .method, .function, .constructor: "f.square"
        case .variable, .property, .field: "v.square"
        case .class, .struct, .interface: "s.square"
        case .enum, .enumMember: "e.square"
        case .keyword: "k.square"
        case .module: "m.square"
        case .constant: "c.square"
        case .typeParameter: "t.square"
        case .snippet: "curlybraces"
        case .file, .folder: "doc"
        case .operator: "plusminus"
        default: "questionmark.square"
        }
    }
}
