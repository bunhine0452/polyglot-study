public import SwiftUI

/// 앱 셸. 왼쪽 232px 사이드바 + 1px 룰 + 오른쪽 본문.
///
/// **`NavigationSplitView` 를 쓰지 않는다.** 그 컨테이너는 사이드바에 반투명 머티리얼과
/// 둥근 선택 캡슐을 강제하고, 본문 배경에도 시스템 색을 깐다. 끄는 API 가 없다.
/// 여기서는 `HStack` 두 칸이 전부라 잃는 것도 없다 — 접기·리사이즈는 디자인에 없다.
public struct AppShell<Detail: View>: View {
    @Binding private var selection: ShellDestination
    /// 화면 계층이 넣어 준 배지 공급자. 렌더 없이 단언하기 위해 모듈 안에 열어 둔다.
    let badge: (ShellDestination) -> String?
    private let detail: (ShellDestination) -> Detail

    /// - Parameter badge: 내비 항목 오른쪽의 모노 숫자(`10`, `7 / 10`). 데이터가 없으면 `nil`.
    ///   셸은 카운트를 스스로 계산하지 않는다 — 화면 계층이 넣어 준다.
    public init(
        selection: Binding<ShellDestination>,
        badge: @escaping (ShellDestination) -> String? = { _ in nil },
        @ViewBuilder detail: @escaping (ShellDestination) -> Detail
    ) {
        self._selection = selection
        self.badge = badge
        self.detail = detail
    }

    public var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: selection, badge: badge) { selection = $0 }
            detail(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper)
        // 시스템이 어디선가 강조색을 끼워 넣지 못하게 앱 전체에서 잉크로 못 박는다.
        .tint(Palette.ink)
    }
}

/// 본문 상단 헤더 — 큰 제목, 오른쪽 라벨, 그 아래 굵은 룰.
/// 7개 화면이 전부 이 형태로 시작하므로 셸이 들고 있는다.
public struct ShellHeader: View {
    private let title: String
    private let trailing: String?

    public init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppFont.sans(.display, weight: .semibold))
                    .tracking(-0.28)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.m)
                if let trailing {
                    LabelText(trailing)
                }
            }
            .padding(.bottom, Spacing.unit + Spacing.xs)
            Rule(.hard)
        }
    }
}

/// 본문 영역의 표준 여백. 디자인 실측 `28px 40px 24px`.
public struct ShellContent<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Sidebar.topPadding)
        .padding(.horizontal, Spacing.xl + Spacing.unit)
        .padding(.bottom, Spacing.l)
    }
}
