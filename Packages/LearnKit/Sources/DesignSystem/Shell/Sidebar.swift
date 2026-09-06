internal import SwiftUI

/// 232px 고정 사이드바. `NavigationSplitView` 도 `List` 도 쓰지 않는다.
///
/// 이유는 취향이 아니다. 둘 다 macOS 에서 사이드바에 **머티리얼 배경과 둥근 선택 캡슐**을
/// 강제로 그리고, 그걸 끄는 공개 API 가 없다. 이 디자인의 활성 항목은 잉크 반전 사각형이고
/// 배경은 불투명한 종이색이라, 시스템 컨테이너를 쓰는 순간 둘 다 깨진다.
/// 그래서 `HStack` + `VStack` + 1px 룰로 직접 조립한다.
struct Sidebar: View {
    /// 브랜드 블록 위 여백. 디자인 실측 28px — 8px 그리드 밖이라 여기서 고정한다.
    static let topPadding: CGFloat = 28
    /// 행 높이. 40px = 8 × 5.
    static let rowHeight: CGFloat = Spacing.unit * 5
    /// 좌우 여백. 24px = 8 × 3.
    static let horizontalPadding: CGFloat = Spacing.l

    let selection: ShellDestination
    let badge: (ShellDestination) -> String?
    let select: (ShellDestination) -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                brand
                Rule(.hard)
                ForEach(ShellDestination.allCases) { destination in
                    SidebarRow(
                        title: destination.title,
                        badge: badge(destination),
                        isSelected: destination == selection
                    ) {
                        select(destination)
                    }
                }
                Spacer(minLength: 0)
                Rule(.soft)
                // 설정은 목적지가 아니라 푸터 크롬이다. 화면이 생기면 행 자체를 버튼으로 바꾼다.
                SidebarRow(title: "설정", badge: nil, isSelected: false, action: nil)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // 오른쪽 1px 룰까지 합쳐서 232px 이 되게 한다(디자인의 border-box 와 동일).
            .frame(width: Spacing.sidebarWidth - Rules.thickness)
            .background(Palette.paper)

            Rule(.hard, axis: .vertical)
        }
        .frame(width: Spacing.sidebarWidth)
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Polyglot")
                // 토큰 미수록: 디자인 실측 18px. Typography.Sans 에 11/13/15/20/… 만 있다.
                .font(AppFont.sans(points: 18, weight: .semibold))
                .tracking(-0.18)
                .foregroundStyle(Palette.ink)
            LabelText("10개 언어 · 독립 트랙")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, Self.topPadding)
        .padding(.bottom, Spacing.l)
    }
}

/// 40px 사이드바 행. 활성일 때 배경 전체가 잉크로 반전된다.
struct SidebarRow: View {
    let title: String
    let badge: String?
    let isSelected: Bool
    let action: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            content
            Rule(.soft)
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.s) {
            Text(title)
                .font(AppFont.sans(.label, weight: isSelected ? .medium : .regular))
                .foregroundStyle(foreground)
            Spacer(minLength: Spacing.s)
            if let badge {
                MonoText(badge, size: .micro, color: isSelected ? Palette.paper : Palette.secondary)
            }
        }
        .padding(.horizontal, Sidebar.horizontalPadding)
        .frame(height: Sidebar.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 && action != nil }
        .modifier(TapAction(action: action))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var foreground: Color {
        SidebarRowStyle.foreground(isSelected: isSelected, isInteractive: action != nil)
    }

    private var background: Color {
        SidebarRowStyle.background(isSelected: isSelected, isHovering: isHovering)
    }
}

/// 사이드바 행의 색 결정. 뷰에서 떼어 놓은 이유는 **활성 항목이 잉크 반전인지**를
/// 렌더 없이 단언하기 위해서다 — 이게 이 셸의 완료 기준 중 하나다.
enum SidebarRowStyle {
    static func foreground(isSelected: Bool, isInteractive: Bool) -> Color {
        if isSelected { return Palette.paper }
        return isInteractive ? Palette.ink : Palette.secondary
    }

    static func background(isSelected: Bool, isHovering: Bool) -> Color {
        if isSelected { return Palette.ink }
        // 호버도 무채색 한 단계로만. 반투명 하이라이트를 쓰지 않는다.
        return isHovering ? Palette.card : Palette.paper
    }
}

/// `onTapGesture` 를 조건부로 붙이기 위한 얇은 래퍼. `if` 로 뷰를 갈라 놓으면
/// 선택 상태가 바뀔 때 행이 통째로 재생성되면서 호버가 끊긴다.
private struct TapAction: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        content.onTapGesture { action?() }
    }
}
