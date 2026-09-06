internal import DesignSystem
internal import SwiftUI

/// 트랙 표의 열 기하.
///
/// 디자인 실측은 `176 / 300 / 328 / 96 / 228` 이고 합이 정확히 1128 = 1440 − 사이드바 232
/// − 좌우 여백 80 이다. **그 다섯 값을 고정 폭으로 쓰면 안 된다** — 아트보드 폭에서만
/// 맞고, 창이 조금만 좁아져도 마지막 열이 잘린다(온보딩 표에서 실제로 겪었다).
/// 그래서 이름 · 오늘 복습 두 열만 고정하고, 진도 · 이어서는 최소 폭 + 신축으로 둔다.
/// 두 신축 열은 남는 폭을 반씩 나눠 갖는데, 디자인의 300:328 도 거의 반반이라 1440 에서
/// 아트보드와 같은 모양이 된다.
enum DashboardLayout {
    /// 표의 다섯 열.
    enum Column {
        case track, progress, resume, due, toolchain
    }

    static let trackWidth: CGFloat = 152
    static let progressMinWidth: CGFloat = 220
    static let resumeMinWidth: CGFloat = 220
    static let dueWidth: CGFloat = 72
    static let toolchainMinWidth: CGFloat = 168
    static let toolchainMaxWidth: CGFloat = 228

    /// 행 높이 48px = 8 × 6.
    static let rowHeight: CGFloat = Spacing.unit * 6
    /// "12 / 22" 가 들어가는 폭. 자릿수가 바뀌어도 진도 칸의 오른쪽 끝이 움직이면 안 된다.
    static let progressValueWidth: CGFloat = 44
    /// 진도 칸 묶음과 다음 열 사이 여백(디자인 실측 32px).
    static let progressTrailingGap: CGFloat = Spacing.xl
    /// 2단 카드의 상단 룰과 내용 사이. 디자인 실측 14px — 8px 그리드 밖이라 여기서 고정한다.
    static let cardTopPadding: CGFloat = 14
    /// 카드 안 요소 간격 12px.
    static let cardSpacing: CGFloat = Spacing.s + Spacing.xs
    /// "이어서" 카드의 블록 진도 막대 최대 폭(디자인 실측 360px 중 막대 몫).
    static let blockBarMaxWidth: CGFloat = 240
}

extension View {
    /// 표의 열 하나에 맞춘 프레임. 헤더 행과 본문 행이 **같은 함수**를 거쳐야 열이 어긋나지 않는다.
    @ViewBuilder
    func dashboardColumn(_ column: DashboardLayout.Column) -> some View {
        switch column {
        case .track:
            frame(width: DashboardLayout.trackWidth, alignment: .leading)
        case .progress:
            frame(
                minWidth: DashboardLayout.progressMinWidth,
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(.trailing, DashboardLayout.progressTrailingGap)
        case .resume:
            frame(
                minWidth: DashboardLayout.resumeMinWidth,
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(.trailing, Spacing.l)
        case .due:
            frame(width: DashboardLayout.dueWidth, alignment: .leading)
        case .toolchain:
            frame(
                minWidth: DashboardLayout.toolchainMinWidth,
                maxWidth: DashboardLayout.toolchainMaxWidth,
                alignment: .leading
            )
        }
    }
}
