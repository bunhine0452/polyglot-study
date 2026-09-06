internal import CodeEditSourceEditor
internal import DesignSystem
internal import LSPKit
internal import SwiftUI

/// `CompletionCandidate`(LSPKit 의 값)를 편집기가 그릴 수 있는 항목으로 감싼다.
///
/// `LSPKit` 이 직접 `CodeSuggestionEntry` 를 만들지 않는 이유: 그러면 그 타깃이
/// AppKit·SwiftUI 를 끌어오고, LSP 매핑을 화면 없이 테스트할 수 없게 된다. 경계는
/// 여기다 — 값은 아래에서 오고, 색과 아이콘은 여기서 붙는다.
struct SwiftSuggestionEntry: CodeSuggestionEntry {
    let candidate: CompletionCandidate

    var label: String { candidate.label }
    var detail: String? { candidate.detail }
    var documentation: String? { candidate.documentation }

    /// 정의로 뛰는 기능은 아직 없다. 셋 다 nil 이면 완성 창이 링크를 그리지 않는다.
    var pathComponents: [String]? { nil }
    var targetPosition: CursorPosition? { nil }
    var sourcePreview: String? { nil }

    var image: Image { Image(systemName: SwiftCompletionSupport.symbolName(for: candidate.kind)) }

    /// **무채색이다.** 이 화면 안에 유채색은 0건이라는 규칙이 완성 창에도 적용된다 —
    /// 다른 편집기가 종류마다 색을 칠하는 자리지만, 여기서는 아이콘 모양으로만 구분한다.
    var imageColor: Color { Palette.secondary }

    var deprecated: Bool { candidate.isDeprecated }
}
