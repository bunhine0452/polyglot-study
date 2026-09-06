internal import SwiftUI
internal import DesignSystem

/// 라운딩 없는 평평한 사각 버튼. **임시 로컬 헬퍼** — `DesignSystem.FlatButton` 프리미티브가
/// 나오면 이걸로 교체한다.
struct FlatButtonView: View {
    enum Style {
        case outline
        case filled
    }

    let title: String
    var style: Style = .outline
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appSans(.label, weight: .medium))
                .padding(.horizontal, Spacing.m)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(style == .filled ? Palette.paper : Palette.ink)
        .background(style == .filled ? Palette.ink : Palette.paper)
        .overlay(Rectangle().strokeBorder(Palette.ink, lineWidth: Rules.thickness))
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
    }
}
