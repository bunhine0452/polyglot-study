internal import Foundation

/// 완성 후보 하나. LSP 의 `CompletionItem` 에서 **이 앱이 쓰는 것만** 남긴 값이다.
///
/// 편집기(`CodeEditSourceEditor`)의 `CodeSuggestionEntry` 로 직접 만들지 않는 이유:
/// 그러면 이 타깃이 AppKit·SwiftUI 를 끌어오고, 매핑을 프로세스도 화면도 없이
/// 테스트할 수 없게 된다. 화면 계층이 이 값을 받아 자기 표현으로 감싼다.
public struct CompletionCandidate: Hashable, Sendable, Identifiable {
    /// LSP `CompletionItemKind`. 숫자를 그대로 두지 않는 이유는 화면이 아이콘을
    /// 고를 때 `case 6` 같은 것을 읽게 되기 때문이다.
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        case text, method, function, constructor, field, variable, `class`, interface
        case module, property, unit, value, `enum`, keyword, snippet, color, file
        case reference, folder, enumMember, constant, `struct`, event, `operator`
        case typeParameter
        case unknown

        /// LSP 스펙의 1...25 순서 그대로.
        public static func from(raw: Int?) -> Kind {
            switch raw {
            case 1: .text
            case 2: .method
            case 3: .function
            case 4: .constructor
            case 5: .field
            case 6: .variable
            case 7: .class
            case 8: .interface
            case 9: .module
            case 10: .property
            case 11: .unit
            case 12: .value
            case 13: .enum
            case 14: .keyword
            case 15: .snippet
            case 16: .color
            case 17: .file
            case 18: .reference
            case 19: .folder
            case 20: .enumMember
            case 21: .constant
            case 22: .struct
            case 23: .event
            case 24: .operator
            case 25: .typeParameter
            default: .unknown
            }
        }
    }

    /// 목록에 보이는 이름. sourcekit-lsp 는 여기에 시그니처를 통째로 넣는다
    /// (`split(separator: Character, maxSplits: Int, ...)`).
    public var label: String
    /// 오른쪽에 붙는 부가 정보. sourcekit-lsp 는 반환 타입을 준다(`[Substring]`).
    public var detail: String?
    public var documentation: String?
    /// 실제로 버퍼에 들어갈 문자열.
    public var insertText: String
    public var kind: Kind
    public var isDeprecated: Bool
    /// 서버가 정한 정렬 키. **알파벳순이 아니다** — sourcekit-lsp 는
    /// `"4998.78379906-split(...)"` 처럼 관련도 점수를 앞에 붙인다.
    public var sortText: String?
    /// 사용자가 친 글자로 걸러 낼 때 쓸 문자열. 없으면 `label`.
    public var filterText: String?

    public var id: String { (sortText ?? "") + "\u{0}" + label + "\u{0}" + insertText }

    public init(
        label: String,
        detail: String? = nil,
        documentation: String? = nil,
        insertText: String,
        kind: Kind = .unknown,
        isDeprecated: Bool = false,
        sortText: String? = nil,
        filterText: String? = nil
    ) {
        self.label = label
        self.detail = detail
        self.documentation = documentation
        self.insertText = insertText
        self.kind = kind
        self.isDeprecated = isDeprecated
        self.sortText = sortText
        self.filterText = filterText
    }
}

public enum LSPCompletionMapping {
    /// 후보 하나를 옮긴다.
    ///
    /// **삽입 문자열의 우선순위가 핵심이다.** sourcekit-lsp 의 `label` 은 사람이 읽는
    /// 시그니처(`split(separator: Character, maxSplits: Int, ...)`)이고 실제로 넣어야
    /// 하는 것은 `textEdit.newText`(`split(separator: , maxSplits: , ...)`)다 — 실측으로
    /// 확인했다. `label` 을 넣으면 타입 이름이 코드에 박힌다.
    ///
    /// 순위: `textEdit.newText` → `insertText` → `label`.
    public static func map(_ item: LSPCompletionItem) -> CompletionCandidate {
        CompletionCandidate(
            label: item.label,
            detail: item.detail,
            documentation: item.documentation?.text,
            insertText: item.textEdit?.newText ?? item.insertText ?? item.label,
            kind: CompletionCandidate.Kind.from(raw: item.kind),
            isDeprecated: item.deprecated ?? false,
            sortText: item.sortText,
            filterText: item.filterText
        )
    }

    /// 응답 전체를 옮기고 **서버가 정한 순서**로 정렬한다.
    ///
    /// LSP 스펙: `sortText` 가 있으면 그것으로, 없으면 `label` 로 오름차순. 관련도 정렬을
    /// 우리가 다시 하지 않는 이유는 서버가 커서 문맥을 알고 우리는 모르기 때문이다.
    ///
    /// - Parameter limit: 목록에 실을 최대 개수. sourcekit-lsp 는 점 하나에 200개를
    ///   보낸다(실측). 전부 그리면 완성 창이 200행짜리 스크롤 덩어리가 된다.
    public static func candidates(
        from response: LSPCompletionResponse,
        limit: Int = 100
    ) -> [CompletionCandidate] {
        let mapped = response.items.map(map)
        let sorted = mapped.enumerated().sorted { left, right in
            let leftKey = left.element.sortText ?? left.element.label
            let rightKey = right.element.sortText ?? right.element.label
            if leftKey != rightKey { return leftKey < rightKey }
            // 키가 같으면 서버가 준 순서를 유지한다 — `sorted(by:)` 는 안정 정렬이
            // 아니라서 명시하지 않으면 같은 입력에 다른 목록이 나온다.
            return left.offset < right.offset
        }.map(\.element)
        guard limit >= 0 else { return sorted }
        return Array(sorted.prefix(limit))
    }
}
