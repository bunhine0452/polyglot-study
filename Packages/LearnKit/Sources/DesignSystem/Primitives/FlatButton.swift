public import SwiftUI

/// 이 앱의 유일한 버튼. 36px 높이 · 16px 좌우 패딩 · 1px 잉크 테두리 · 곡률 0.
///
/// 기본 버튼 스타일을 쓰지 않고 전용 스타일을 끼우는 것이 핵심이다 — macOS 26 의 기본
/// 스타일은 둥근 모서리와 반투명 머티리얼 배경을 그린다. 그 둘이 이 디자인에서 가장
/// 눈에 띄는 이물질이다.
public struct FlatButton: View {
    public enum Emphasis: Sendable, CaseIterable {
        /// 화면의 주 동작. 잉크 채움에 종이색 글자.
        case primary
        /// 부차 동작. 종이 바탕에 잉크 테두리.
        case secondary

        var background: Color {
            switch self {
            case .primary: Palette.ink
            case .secondary: Palette.paper
            }
        }

        var foreground: Color {
            switch self {
            case .primary: Palette.paper
            case .secondary: Palette.ink
            }
        }
    }

    /// 컨트롤 높이. 토큰의 8px 그리드에 없는 값이라 여기서 고정한다
    /// (디자인 실측 36px — 40px 행 안에서 위아래 2px 씩 숨 쉬는 크기다).
    static let height: CGFloat = 36

    private let title: String
    private let emphasis: Emphasis
    private let shortcutHint: String?
    private let isEnabled: Bool
    private let action: () -> Void

    /// - Parameter shortcutHint: 버튼 오른쪽에 흐리게 붙는 모노 글리프(`↩` 등). 장식이다.
    public init(
        _ title: String,
        emphasis: Emphasis = .primary,
        shortcutHint: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.emphasis = emphasis
        self.shortcutHint = shortcutHint
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Text(title)
                    .font(AppFont.sans(.label, weight: .medium))
                if let shortcutHint {
                    MonoText(shortcutHint, size: .micro, color: emphasis.foreground)
                        .opacity(0.7)
                }
            }
            .foregroundStyle(emphasis.foreground)
            .frame(height: Self.height)
            .padding(.horizontal, Spacing.m)
        }
        .buttonStyle(FlatButtonStyle(emphasis: emphasis))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// 눌림도 반전 계열로만 표현한다 — 스케일도, 곡률도 쓰지 않는다.
private struct FlatButtonStyle: ButtonStyle {
    let emphasis: FlatButton.Emphasis

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(emphasis.background)
            .overlay {
                Rectangle().strokeBorder(Palette.ink, lineWidth: Rules.thickness)
            }
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
