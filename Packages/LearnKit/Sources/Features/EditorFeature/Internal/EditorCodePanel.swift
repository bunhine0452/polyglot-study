internal import CodeEditLanguages
internal import CodeEditSourceEditor
internal import DesignSystem
internal import EditorUI
internal import LearnCore
internal import SwiftUI

/// 코드 편집 표면 하나. 콘솔 화면의 좌측 패널과 SQL 화면의 상단 쿼리 패널이 둘 다
/// 이걸 쓴다 — 파일명 머리줄(32px) + 실제 편집 가능한 `SourceEditor`.
///
/// `EditorUIConfiguration.make()` 를 그대로 쓴다 — 화면이 `CodeEditSourceEditor` 를
/// 직접 구성하지 않는다는 `EditorUI` 의 계약이다. 문법 하이라이팅은
/// `MonochromeEditorTheme` 가 이미 무채색으로 고정해 뒀다.
struct EditorCodePanel: View {
    let fileName: String
    let engineLabel: String
    let language: LanguageID
    @Binding var code: String
    /// `false` 면 채점 중이거나 실행 중이라 편집을 잠근다.
    var isEditable: Bool = true

    @State private var editorState = SourceEditorState()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MonoText(fileName, size: .label, weight: .medium)
                Spacer(minLength: Spacing.m)
                LabelText(engineLabel)
            }
            .padding(.horizontal, EditorLayout.barPadding)
            .frame(height: EditorLayout.codeHeaderHeight)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) { Rule(.soft) }

            SourceEditor(
                $code,
                language: Self.codeLanguage(for: language),
                configuration: EditorUIConfiguration.make(),
                state: $editorState
            )
            .disabled(!isEditable)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.card)
    }

    static func codeLanguage(for language: LanguageID) -> CodeLanguage {
        switch language {
        case .swift: .swift
        case .python: .python
        case .sql: .sql
        default: .default
        }
    }
}
