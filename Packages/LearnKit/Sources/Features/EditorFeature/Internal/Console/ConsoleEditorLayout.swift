internal import DesignSystem
internal import SwiftUI

/// `{#screen-editor-console}` — 좌우 2단. 우측 결과 패널은 폭 520px 고정
/// (`Spacing.resultPanelWidth`)이고 출력·테스트 탭을 담는다. 콘솔 프리젠터(대부분의
/// 언어)가 이 레이아웃을 쓴다 — SQL(`table` 프리젠터)은 ``SQLResultLayout`` 이다.
struct ConsoleEditorLayout: View {
    @Bindable var model: EditorModel

    var body: some View {
        HStack(spacing: 0) {
            codePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ConsoleResultPanel(model: model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var codePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorCodePanel(
                fileName: model.task.entryFileName,
                engineLabel: EditorModel.toolName(for: model.task.language),
                language: model.task.language,
                code: $model.code,
                isEditable: model.canRun,
                // Swift 트랙에서만 값이 있다. `{#lsp-completion}`.
                completionDelegate: model.languageSupport
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // `{#inline-diagnostic-row}`: 진단이 있는 줄만 코드 아래 이어 붙인다 — 나머지
            // 코드는 손대지 않는다.
            if !model.diagnosticRows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(model.diagnosticRows) { row in
                        InlineDiagnosticRowView(row: row)
                    }
                }
            }
        }
        .background(Palette.card)
    }
}
