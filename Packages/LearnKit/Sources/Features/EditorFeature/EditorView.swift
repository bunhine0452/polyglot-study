public import SwiftUI
internal import DesignSystem

/// 에디터 화면. 48px 헤더 + 56px 과제 바 + 언어별 본문.
///
/// 본문은 두 갈래다 — `{#screen-editor-console}`(콘솔 프리젠터, 대부분의 언어)와
/// `{#screen-sql-result}`(표 프리젠터, SQL). 어느 쪽을 그릴지는 화면이 정하지 않고
/// `model.presenter.route` 가 정한다 — `LessonPresentation` 과 같은 원칙이다.
///
/// 목 데이터가 없다 — ``EditorModel`` 이 기본으로 진짜 백엔드(`swiftc`·`InProcessRunner`)
/// 를 태운다.
public struct EditorView: View {
    @State private var model: EditorModel
    private let onBack: (() -> Void)?

    public init(model: EditorModel, onBack: (() -> Void)? = nil) {
        _model = State(wrappedValue: model)
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 0) {
            EditorTopBar(
                trackCaption: model.task.trackCaption,
                title: model.task.lessonTitle,
                blockCaption: model.task.blockCaption,
                onBack: onBack,
                canRun: model.canRun,
                canSubmit: model.canSubmit,
                onRun: { Task { await model.run() } },
                onSubmit: { Task { await model.submit() } }
            )
            EditorTaskBar(
                ordinalLabel: model.task.taskOrdinalLabel,
                prose: model.task.prose,
                trailingLabel: taskBarTrailingLabel
            )
            body(for: model.presenter.route)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.paper)
        // `{#sourcekit-lsp-swift}` — Swift 과제에서만 언어 서버가 뜬다. 서버가 없는
        // 머신에서는 조용히 아무 일도 일어나지 않고 나머지 화면은 그대로 동작한다.
        .task {
            await model.startLanguageSupport()
        }
        // 편집기 본문이 바뀌면 서버에 알린다. 알림이라 왕복이 없다 —
        // 진단은 서버가 스스로 다시 계산해 `publishDiagnostics` 로 보낸다.
        .onChange(of: model.code) {
            Task { await model.codeDidChange() }
        }
        .onDisappear {
            // 프로세스를 거둔다. 화면을 여닫을 때마다 sourcekit-lsp 가 하나씩 쌓이면
            // 그게 곧 이 저장소가 러너에서 이미 겪은 "잔존 프로세스" 문제다.
            Task { await model.stopLanguageSupport() }
        }
    }

    private var taskBarTrailingLabel: String {
        if model.presenter.route == .table { return "채점 기준 · 결과셋 비교" }
        guard model.task.testCount > 0 else { return "" }
        return "테스트 \(model.task.testCount)개 통과 시 완료"
    }

    @ViewBuilder
    private func body(for route: PresenterRoute) -> some View {
        switch route {
        case .console:
            ConsoleEditorLayout(model: model)
        case .table:
            SQLResultLayout(model: model)
        case .preparing:
            EditorPendingLayout(reason: model.presenter.pendingReason)
        }
    }
}

/// 아직 실행기가 없는 언어(브라우저·레지스터 프리젠터)의 자리. 실제 뷰가 붙기 전까지
/// 아무 것도 약속하지 않는다 — `DesignSystem.PendingPresenterView` 와 같은 태도다.
struct EditorPendingLayout: View {
    let reason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            LabelText("준비중")
            if let reason {
                Text(reason)
                    .font(AppFont.sans(.label))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(EditorLayout.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
