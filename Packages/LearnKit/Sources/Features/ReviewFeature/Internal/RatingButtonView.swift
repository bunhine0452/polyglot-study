internal import SwiftUI
internal import DesignSystem
internal import LearnCore

/// 채점 버튼 한 개. 4개 인스턴스가 전부 `RatingButtonMetrics.shared` 하나만 참조한다 —
/// `spec.rating` 은 텍스트(라벨·숫자 힌트·간격)를 고르는 데만 쓰이고 스타일에는 관여하지 않는다.
struct RatingButtonView: View {
    let spec: RatingButtonSpec
    let action: () -> Void

    private var metrics: RatingButtonMetrics { .metrics(for: spec.rating) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: Spacing.xs) {
                    Text(spec.label)
                        .font(AppFont.sans(.body, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    MonoText(spec.intervalLabel, size: .label, color: Palette.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                MonoText("\(spec.keyHint)", size: .micro, color: Palette.faint)
                    .padding(.top, Spacing.s)
                    .padding(.leading, Spacing.m)
            }
            // 4버튼 모두 여기서 폭을 균등 분할한다 — `RatingButtonRow` 의 `HStack` 이
            // 이 modifier 를 가진 자식 4개를 같은 폭으로 나눈다.
            .frame(maxWidth: .infinity)
            .frame(height: metrics.height)
        }
        .buttonStyle(RatingButtonPressStyle(metrics: metrics))
        .keyboardShortcut(KeyEquivalent(Character(String(spec.keyHint))), modifiers: [])
        .accessibilityLabel("\(spec.label), 다음 복습 \(spec.intervalLabel) 뒤")
    }
}

/// 눌림도 반전 계열로만 표현한다 — `DesignSystem.FlatButton` 의 `FlatButtonStyle` 과 같은 관용구.
/// 별도 버튼 타입을 두는 이유는 이 버튼의 모양(세로 스택 + 좌상단 숫자 힌트)이 `FlatButton`
/// 이 다루는 가로 라벨 버튼과 달라서다.
private struct RatingButtonPressStyle: ButtonStyle {
    let metrics: RatingButtonMetrics

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(metrics.background)
            .overlay {
                Rectangle().strokeBorder(metrics.borderColor, lineWidth: metrics.borderWidth)
            }
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
