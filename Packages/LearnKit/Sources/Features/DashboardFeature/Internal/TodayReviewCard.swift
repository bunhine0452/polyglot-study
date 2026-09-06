internal import DesignSystem
internal import SwiftUI

/// 오늘의 복습 카드.
///
/// **축적 프레이밍** — 오른쪽 아래 "연속 복습 14일째" 가 이 카드의 유일한 동기 장치다.
/// 만료 시각도, "내일 안 하면 끊깁니다" 도 없다. 쌓인 날수만 센다. 오늘 아직 복습을 안
/// 했어도 숫자는 그대로 서 있는다(`DashboardModel.streak(days:today:)`).
struct TodayReviewCard: View {
    let summary: ReviewSummary
    let onStart: () -> Void

    var body: some View {
        DashboardCard(label: "오늘의 복습") {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.unit - 2) {
                    Text("\(summary.total)")
                        .font(.dashSans(.hero, weight: .semibold))
                        .tracking(-0.64)
                        .monospacedDigit()
                        .foregroundStyle(summary.total > 0 ? Palette.ink : Palette.faint)
                    Text("장")
                        .font(.dashSans(.body))
                        .foregroundStyle(summary.total > 0 ? Palette.ink : Palette.faint)
                }
                Text(summary.breakdownLine ?? "오늘 도착한 복습이 없습니다.")
                    .font(.dashSans(.label))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }

            // 왼쪽 카드의 블록 진도 막대 자리를 비워 둔다 — 두 카드의 버튼 행이 같은
            // 높이에 서게 하는 것이 디자인의 `<div style="height:6px">` 다.
            Color.clear.frame(height: Rules.progressCellSize)

            HStack(alignment: .center, spacing: Spacing.l) {
                FlatButton("복습 시작", emphasis: .secondary, isEnabled: summary.total > 0, action: onStart)
                if let streakLabel = summary.streakLabel {
                    VStack(alignment: .leading, spacing: 0) {
                        LabelText("연속 복습")
                        Text(streakLabel)
                            .font(.dashSans(.body, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
            .padding(.top, Spacing.xs)
        }
    }
}
