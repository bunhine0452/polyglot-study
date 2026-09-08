internal import DesignSystem
internal import SwiftUI

/// 연습장 오른쪽 칸 — 실행 결과.
///
/// `ConsoleResultPanel` 을 쓰지 않고 따로 둔 이유는 **탭이 없어서**다. 저쪽은 출력과
/// 테스트 둘을 오가지만 연습장에는 테스트가 없다. 탭 하나짜리 탭 바는 화면에 거짓
/// 선택지를 그린다.
///
/// 폭은 `Spacing.resultPanelWidth` 로 에디터와 같다. 실행 전에도 같은 자리를 차지하도록
/// 고정한다(`{#fixed-height-reservation}`) — 실행할 때마다 코드 칸이 움찔거리면 읽던
/// 자리를 잃는다.
struct ScratchResultPanel: View {
    let model: ScratchModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 제목("출력"/"결과")과 상태는 `ResultPresenterView` 가 이미 그린다
            // (`PresenterHeader`). 여기서 또 그리면 화면에 "출력" 이 두 번 나온다 —
            // 실제로 그렇게 만들었다가 스냅샷에서 잡았다. 이 줄은 프리젠터가 모르는 것,
            // 즉 **종료 코드와 소요 시간**만 덧붙인다.
            content
            runDetail
            Spacer(minLength: 0)
        }
        .frame(width: Spacing.resultPanelWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .leading) { Rule(.hard, axis: .vertical) }
    }

    /// 실행이 끝났을 때만 나오는 한 줄.
    ///
    /// **빨강을 쓰지 않는다** (`{#red-budget-guard}`). 실패는 프리젠터가 이미 두 번
    /// 말한다 — 머리줄의 `statusLabel` 과 실패색으로 그려지는 stderr 다. 여기서 또
    /// 칠하면 한 화면에 빨강이 셋이 되고, 그러면 어느 것이 진짜 신호인지 흐려진다.
    /// 이 줄이 덧붙이는 것은 프리젠터가 모르는 값, 즉 **종료 코드와 소요 시간**뿐이다.
    @ViewBuilder
    private var runDetail: some View {
        switch runState {
        case .finished(let succeeded, let exitCode, let milliseconds):
            detailRow {
                StatusDot(succeeded ? .pass : .empty)
                MonoText(
                    exitCode.map { "종료 \($0) · \(milliseconds)ms" } ?? "\(milliseconds)ms",
                    size: .micro, color: Palette.secondary)
            }
        case .failed(let reason):
            // 실행기 자체가 실패한 경우(툴체인 없음 등). 같은 문구가 콘솔에도 남는다.
            detailRow {
                StatusDot(.empty)
                Text(reason)
                    .font(AppFont.sans(.caption))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(2)
            }
        case .idle, .preparing, .running:
            EmptyView()
        }
    }

    private func detailRow<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        HStack(spacing: Spacing.xs) {
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, EditorLayout.panelPadding)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: EditorLayout.panelRowHeight, alignment: .leading)
        .overlay(alignment: .top) { Rule(.soft) }
    }

    private var runState: ScratchModel.RunState { model.runState }

    @ViewBuilder
    private var content: some View {
        ResultPresenterView(
            model.presenter,
            transcript: model.transcript,
            resultSet: model.resultSet
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
