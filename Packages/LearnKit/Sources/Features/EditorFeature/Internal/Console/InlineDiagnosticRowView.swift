internal import DesignSystem
internal import SwiftUI

/// `{#inline-diagnostic-row}` 의 뷰 절반 — 데이터 절반은 `EditorDiagnosticPresentation`.
///
/// 거터 6px 사각(잉크, **빨강이 아니다** — 이 화면 안에는 유채색이 0건이어야 한다) +
/// 그 줄의 소스 텍스트 + 코드 아래 한국어 설명 + 위치 라벨. **진단이 붙은 행만
/// 배경이 `Palette.paper` 로 바뀐다** — 나머지 코드는 `Palette.card`(흰 편집기 배경)
/// 그대로다.
struct InlineDiagnosticRowView: View {
    let row: InlineDiagnosticRow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                gutter
                MonoText(row.codeLine.isEmpty ? " " : row.codeLine, size: .code)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: Typography.codeLineHeight)
            .background(Palette.paper)

            HStack(alignment: .top, spacing: 0) {
                Color.clear.frame(width: EditorLayout.gutterWidth)
                VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                    Text(row.message)
                        .font(AppFont.sans(.note))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    LabelText(row.locationLabel)
                }
                .padding(.trailing, Spacing.m)
            }
            .padding(.vertical, Spacing.s)
            .background(Palette.paper)
            .overlay(alignment: .top) { Rule(.soft) }
            .overlay(alignment: .bottom) { Rule(.soft) }
        }
    }

    private var gutter: some View {
        HStack(spacing: Spacing.s) {
            Rectangle()
                .fill(Palette.ink)
                .frame(width: Rules.gutterMarkSize, height: Rules.gutterMarkSize)
            MonoText("\(row.line)", size: .micro, color: Palette.faint)
        }
        .frame(width: EditorLayout.gutterWidth, alignment: .trailing)
        .padding(.trailing, Spacing.s)
    }
}
