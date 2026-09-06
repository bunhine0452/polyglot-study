internal import DesignSystem
internal import LearnCore
internal import SwiftUI

/// 10행 트랙 표.
struct TrackTable: View {
    let rows: [TrackRow]
    let onOpen: (TrackRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(rows) { row in
                TrackTableRow(row: row, onOpen: onOpen)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                LabelText("트랙").dashboardColumn(.track)
                LabelText("진도").dashboardColumn(.progress)
                LabelText("이어서").dashboardColumn(.resume)
                LabelText("오늘 복습").dashboardColumn(.due)
                LabelText("툴체인").dashboardColumn(.toolchain)
            }
            .padding(.bottom, Spacing.s)
            Rule(.hard)
        }
    }
}

/// 표의 한 행. 활성 트랙은 잉크, 준비 중 트랙은 흐림 — 그 대비가 이 표의 완료 기준이다.
struct TrackTableRow: View {
    let row: TrackRow
    let onOpen: (TrackRow) -> Void

    var body: some View {
        HStack(spacing: 0) {
            nameCell.dashboardColumn(.track)
            progressCell.dashboardColumn(.progress)
            resumeCell.dashboardColumn(.resume)
            dueCell.dashboardColumn(.due)
            toolchainCell.dashboardColumn(.toolchain)
        }
        .frame(height: DashboardLayout.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rule(.soft) }
        .contentShape(Rectangle())
        .onTapGesture { if !row.stage.isDimmed { onOpen(row) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(row.stage.isDimmed ? [] : .isButton)
    }

    /// 준비 중 트랙은 이름까지 흐리다. 색 하나로 "지금 할 수 있는 것" 이 갈린다.
    private var primaryColor: Color { row.stage.isDimmed ? Palette.faint : Palette.ink }

    private var nameCell: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(row.name)
                .font(AppFont.sans(.label, weight: .medium))
                .foregroundStyle(primaryColor)
            LabelText(row.stage.label, color: row.stage.isDimmed ? Palette.faint : Palette.secondary)
        }
    }

    @ViewBuilder
    private var progressCell: some View {
        if row.stage == .comingSoon {
            Text(row.pendingContentLabel)
                .font(AppFont.sans(.label))
                .foregroundStyle(Palette.faint)
        } else {
            HStack(spacing: DashboardLayout.cardSpacing) {
                // 칸 수는 `row.cells.count` == 레슨 총수다. `LazyHGrid` 가 아니라 고정
                // 컨테이너라 폭이 변해도 2px 간격이 그대로 유지된다.
                SegmentedProgress(row.cells, height: .tall)
                // `fixedSize` 가 `frame` **앞**에 와야 한다. 뒤에 붙이면 44px 폭 안에서
                // 이상 높이를 다시 계산해 "11 / 22" 가 두 줄로 접힌다(실측).
                MonoText(row.progressLabel, size: .label, color: Palette.secondary)
                    .fixedSize()
                    .frame(width: DashboardLayout.progressValueWidth, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var resumeCell: some View {
        if let resume = row.resume {
            VStack(alignment: .leading, spacing: 0) {
                Text(resume.headline)
                    .font(AppFont.sans(.label))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let caption = row.resumeCaption {
                    LabelText(caption)
                }
            }
        } else {
            Text(row.stage == .notStarted ? "아직 시작 안 함" : "—")
                .font(AppFont.sans(.label))
                .foregroundStyle(Palette.faint)
        }
    }

    private var dueCell: some View {
        MonoText(
            row.dueToday.map(String.init) ?? "—",
            size: .label,
            color: row.stage.isDimmed ? Palette.faint : Palette.ink
        )
    }

    private var toolchainCell: some View {
        HStack(spacing: Spacing.s) {
            StatusDot(row.toolchain.dot, label: row.toolchain.label)
            MonoText(row.toolchain.label, size: .label, color: primaryColor)
                .lineLimit(1)
        }
    }
}
