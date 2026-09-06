internal import SwiftUI
internal import DesignSystem

/// 진단 표의 한 행. 열 폭은 디자인(`design/Onboarding.dc.html`)의 그리드를 그대로 따른다 —
/// 120 / 120 / 128 / 480 / 352. `Tokens.swift` 에 이 폭들과 정확히 맞는 이름이 없어서
/// (가장 가까운 `Spacing` 배수가 아니라 이 표 전용 값이다) `OnboardingLayout` 상수로 둔다.
struct DiagnosticRowView: View {
    let row: OnboardingModel.Row
    let onCopy: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(row.trackName)
                .font(.appSans(.label, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(width: OnboardingLayout.trackWidth, alignment: .leading)
            MonoTextView(text: row.toolName, size: .label, color: Palette.secondary)
                .frame(width: OnboardingLayout.toolWidth, alignment: .leading)
            statusCell
                .frame(width: OnboardingLayout.statusWidth, alignment: .leading)
            detailCell
                .frame(width: OnboardingLayout.detailWidth, alignment: .leading)
            commandCell
                .frame(width: OnboardingLayout.commandWidth, alignment: .leading)
        }
        .padding(.vertical, Spacing.s)
        .frame(minHeight: OnboardingLayout.rowMinHeight, alignment: .leading)
        .overlay(alignment: .bottom) { RuleView(color: Palette.ruleSoft) }
    }

    @ViewBuilder
    private var statusCell: some View {
        switch row.status {
        case .scanning:
            HStack(spacing: Spacing.s) {
                StatusGlyphView(glyph: .emptySquare, tint: Palette.cellEmpty)
                Text("확인 중…")
                    .font(.appSans(.label))
                    .foregroundStyle(Palette.faint)
            }
        case let .resolved(availability):
            let presentation = availability.presentation
            HStack(spacing: Spacing.s) {
                StatusGlyphView(glyph: presentation.glyph, tint: glyphColor(presentation.glyph))
                Text(presentation.statusLabel)
                    .font(.appSans(.label, weight: .medium))
                    .foregroundStyle(Palette.ink)
            }
        }
    }

    @ViewBuilder
    private var detailCell: some View {
        switch row.status {
        case .scanning:
            EmptyView()
        case let .resolved(availability):
            // 디자인은 이 열을 12px 산스로 그린다. `Typography.Sans` 스케일이 11(micro)에서
            // 13(label)으로 건너뛰어 정확히 12px 인 값이 없다 — micro 로 근사한다.
            Text(availability.presentation.detailText)
                .font(.appSans(.micro))
                .foregroundStyle(Palette.secondary)
                .lineLimit(2)
                .padding(.trailing, Spacing.l)
        }
    }

    @ViewBuilder
    private var commandCell: some View {
        if case let .resolved(availability) = row.status, let command = availability.presentation.copyableCommand {
            InstallCommandView(command: command, onCopy: onCopy)
        } else {
            EmptyView()
        }
    }

    private func glyphColor(_ glyph: StatusGlyph) -> Color {
        switch glyph {
        case .filledPass: Palette.pass
        case .filledFail: Palette.fail
        case .emptySquare: Palette.faint
        }
    }
}

/// 표 전용 레이아웃 상수. `design/Onboarding.dc.html` 의 그리드 수치를 그대로 옮긴 것이라
/// `Spacing`/`Rules` 토큰으로 표현되지 않는다(둘 다 8px 배수 얼개용이지 열 폭용이 아니다).
enum OnboardingLayout {
    static let trackWidth: CGFloat = 120
    static let toolWidth: CGFloat = 120
    static let statusWidth: CGFloat = 128
    static let detailWidth: CGFloat = 480
    static let commandWidth: CGFloat = 352
    /// 스캔 중에도 확정 결과와 같은 높이를 예약한다 — 결과가 채워질 때 표가 튀지 않게.
    static let rowMinHeight: CGFloat = 44
}
