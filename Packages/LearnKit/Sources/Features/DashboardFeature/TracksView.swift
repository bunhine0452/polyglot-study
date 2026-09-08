public import LearnCore
public import SwiftUI
internal import DesignSystem

/// 트랙 화면 — 왼쪽에 트랙 목록, 오른쪽에 그 트랙의 레슨 전부.
///
/// **디자인 아트보드가 없는 화면이다.** `design/` 의 7종 중 트랙 화면은 없고, 계획
/// 항목(`{#screen-tracks}`)도 "대시보드의 트랙 표를 확장할지, 별도 화면을 그릴지부터
/// 정한다" 로 열려 있었다. 별도 화면으로 정한 근거는 기능이다 — 대시보드의 표는 트랙마다
/// **한 줄**이라 "이어서" 한 곳만 가리킬 수 있고, 그래서 임의의 레슨으로 들어갈 길이
/// 앱 어디에도 없었다. 5번 레슨을 다시 보려면 목록이 있어야 한다.
///
/// 새 토큰을 만들지 않는다. 두 단 레이아웃·행 높이·룰·진도 칸이 전부 기존 프리미티브와
/// 8px 그리드 위에 있다.
///
/// 헤더는 셸이 그린다(`ShellHeader`) — 대시보드와 같다.
public struct TracksView: View {
    @State private var model: TracksModel
    private let onOpen: (LessonRef) -> Void

    public init(
        model: TracksModel = TracksModel(),
        onOpen: @escaping (LessonRef) -> Void = { _ in }
    ) {
        _model = State(wrappedValue: model)
        self.onOpen = onOpen
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            trackList
                .frame(width: TracksLayout.listWidth, alignment: .leading)
            lessonPanel
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.paper)
        .task { await model.load() }
    }

    // MARK: - 왼쪽 · 트랙 목록

    private var trackList: some View {
        VStack(alignment: .leading, spacing: 0) {
            LabelText("트랙")
                .padding(.bottom, Spacing.s)
            Rule(.hard)
            ForEach(model.tracks) { track in
                TrackListRow(
                    track: track,
                    isSelected: track.trackID == model.selectedTrack?.trackID,
                    onSelect: { model.select(track.trackID) }
                )
            }
        }
    }

    // MARK: - 오른쪽 · 레슨 목록

    @ViewBuilder
    private var lessonPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.lastLoadFailed {
                MonoText("진도를 읽지 못했습니다 — 저장소를 확인하십시오.", color: Palette.fail)
                    .padding(.bottom, Spacing.m)
            }
            if let track = model.selectedTrack {
                lessonHeader(track)
                if track.lessons.isEmpty {
                    LabelText(
                        track.hasContent
                            ? "이 트랙의 레슨 목록을 읽지 못했습니다."
                            : "\(track.name) 트랙은 콘텐츠 준비 중입니다."
                    )
                    .padding(.top, Spacing.m)
                } else {
                    ForEach(track.lessons) { lesson in
                        LessonListRow(lesson: lesson) { onOpen(lesson.ref) }
                    }
                }
            } else {
                LabelText("열 수 있는 트랙이 없습니다 — 콘텐츠 팩을 확인하십시오.")
            }
            Spacer(minLength: 0)
        }
    }

    private func lessonHeader(_ track: TracksModel.Track) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(track.name)
                    .font(AppFont.sans(.subtitle, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                MonoText(track.progressLabel, color: Palette.secondary)
                Spacer(minLength: Spacing.m)
                LabelText("블록").frame(width: TracksLayout.blocksWidth, alignment: .leading)
                LabelText("상태").frame(width: TracksLayout.statusWidth, alignment: .leading)
            }
            .padding(.bottom, Spacing.s)
            Rule(.hard)
        }
    }
}

// MARK: - 행

private struct TrackListRow: View {
    let track: TracksModel.Track
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text(track.name)
                .font(AppFont.sans(.note, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(foreground)
            Spacer(minLength: Spacing.s)
            MonoText(track.progressLabel, size: .micro, color: secondaryForeground)
        }
        .padding(.horizontal, Spacing.s)
        .frame(height: TracksLayout.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Palette.ink : Color.clear)
        .overlay(alignment: .bottom) { Rule(.soft) }
        .contentShape(Rectangle())
        .onTapGesture { if track.hasContent { onSelect() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(track.hasContent ? .isButton : [])
    }

    /// 선택된 행은 반전이다 — 셸 사이드바의 활성 항목과 같은 규칙.
    private var foreground: Color {
        if isSelected { return Palette.paper }
        return track.hasContent ? Palette.ink : Palette.faint
    }

    private var secondaryForeground: Color {
        isSelected ? Palette.paper : Palette.faint
    }
}

private struct LessonListRow: View {
    let lesson: TracksModel.LessonRow
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            MonoText(lesson.ordinalLabel, color: Palette.faint)
                .frame(width: TracksLayout.ordinalWidth, alignment: .leading)
            Text(lesson.title)
                .font(AppFont.sans(.note))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: Spacing.m)
            // 막대는 열보다 좁다 — 상태 열에 붙지 않게 오른쪽 여백을 남긴다.
            SegmentedProgress(lesson.blockCells)
                .frame(width: TracksLayout.blocksWidth - Spacing.m)
                .frame(width: TracksLayout.blocksWidth, alignment: .leading)
            LabelText(lesson.statusLabel, color: statusColor)
                .frame(width: TracksLayout.statusWidth, alignment: .leading)
        }
        .frame(height: TracksLayout.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rule(.soft) }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// 색은 상태 표시에만 쓴다 — 완료만 잉크, 나머지는 무채색 2차 텍스트다.
    private var statusColor: Color {
        switch lesson.status {
        case .completed: Palette.ink
        case .inProgress: Palette.secondary
        case .skipped, .notStarted: Palette.faint
        }
    }
}

enum TracksLayout {
    /// 왼쪽 트랙 목록 폭. 사이드바(232)보다 좁게 두어 두 목록이 겹쳐 보이지 않게 한다.
    static let listWidth: CGFloat = 200
    /// 행 높이 40px = 8 × 5. 표(48)보다 한 칸 낮다 — 12행이 한 화면에 들어와야 한다.
    static let rowHeight: CGFloat = Spacing.collapsedBlockHeight
    static let ordinalWidth: CGFloat = 28
    static let blocksWidth: CGFloat = 120
    static let statusWidth: CGFloat = 96
}
