public import SwiftUI

internal import DesignSystem

/// 연습장 화면. 48px 헤더 + 파일 목록 · 코드 · 결과 3분할.
///
/// Swift Playgrounds 의 배치를 빌렸지만 **오른쪽 칸이 다르다.** 저쪽은 돌아가는 앱을
/// 그대로 보여준다(SwiftUI 뷰를 같은 프로세스에서 그린다). 여기서는 학습자 코드가
/// `sandbox-exec` 로 가둔 별도 프로세스에서 도므로 돌려받는 것은 stdout 과 종료 코드뿐이다.
/// 그래서 오른쪽은 콘솔이고, SQL 만 결과표다. 이건 타협이 아니라 이 앱의 실행 모델이
/// 그것을 요구한다 — 학습자 코드를 앱 안에서 돌리면 격리가 사라진다.
///
/// 레슨의 에디터(`EditorView`)와 나란히 두되 **제출 버튼이 없다.** 채점이 없는 것이 이
/// 화면의 요점이다.
public struct ScratchView: View {
    @State private var model: ScratchModel
    @State private var isAddingFile = false
    @State private var newFileName = ""
    @State private var fileError: String?

    public init(model: ScratchModel) {
        _model = State(wrappedValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Rule(.hard)
            HStack(spacing: 0) {
                ScratchFileList(
                    model: model,
                    isAddingFile: $isAddingFile,
                    newFileName: $newFileName,
                    fileError: $fileError
                )
                Rule(.hard, axis: .vertical)
                codePanel
                ScratchResultPanel(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.paper)
        // `{#sourcekit-lsp-swift}` — Swift 연습장에서만 언어 서버가 뜬다. 서버가 없는
        // 머신에서는 조용히 아무 일도 일어나지 않고 나머지는 그대로 동작한다.
        .task(id: model.language) {
            await model.stopLanguageSupport()
            await model.startLanguageSupport()
        }
        .onDisappear { Task { await model.stopLanguageSupport() } }
    }

    // MARK: - 상단 바

    private var topBar: some View {
        HStack(spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: 0) {
                LabelText("연습장")
                Text("채점하지 않습니다 — 마음껏 고쳐 보세요")
                    .font(AppFont.sans(.caption))
                    .foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: Spacing.l)
            languagePicker
            FlatButton("되돌리기", emphasis: .secondary, action: model.resetEntryFile)
            FlatButton(
                model.runState.isBusy ? "실행 중" : "실행",
                isEnabled: model.canRun
            ) {
                Task { await model.run() }
            }
        }
        .padding(.horizontal, EditorLayout.barPadding)
        .frame(height: EditorLayout.topBarHeight)
    }

    /// 언어 고르기. `Picker` 를 쓰지 않는 이유는 디자인 때문이다 — 시스템 피커는 라운딩과
    /// 강조색을 들고 오는데 이 앱은 둘 다 쓰지 않는다(`{#ds-primitives}`).
    private var languagePicker: some View {
        HStack(spacing: 0) {
            ForEach(ScratchLanguage.allCases) { language in
                let isActive = language == model.language
                Text(language.displayName)
                    .font(AppFont.sans(.label))
                    .foregroundStyle(isActive ? Palette.paper : Palette.secondary)
                    .padding(.horizontal, Spacing.s)
                    .frame(height: Spacing.l)
                    .background(isActive ? Palette.ink : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !model.runState.isBusy else { return }
                        model.switchLanguage(to: language)
                    }
                    .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
        }
        .overlay { Rectangle().strokeBorder(Palette.ruleSoft, lineWidth: 1) }
    }

    // MARK: - 코드

    private var codePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorCodePanel(
                fileName: model.selectedFileName,
                engineLabel: engineLabel,
                language: model.language.languageID,
                code: Binding(get: { model.code }, set: { model.code = $0 }),
                isEditable: !model.runState.isBusy,
                completionDelegate: model.languageSupport
            )
            if let failure = model.saveFailure {
                saveFailureRow(failure)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var engineLabel: String {
        switch model.language {
        case .python: "python3"
        case .swift: "swiftc"
        case .sql: "sqlite3"
        case .rust: "rustc"
        case .cpp: "clang++"
        }
    }

    /// 저장이 실패했을 때만 나온다. 학습자가 쓴 것을 조용히 잃지 않게 하는 자리다.
    ///
    /// **빨강을 쓰지 않는다** (`{#red-budget-guard}`). 드물게 나오고 문구가 그 자체로
    /// 명확해서, 색을 쓰지 않아도 읽힌다.
    private func saveFailureRow(_ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            StatusDot(.emptyInk)
            Text(text)
                .font(AppFont.sans(.caption))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, EditorLayout.panelPadding)
        .frame(height: EditorLayout.panelRowHeight)
        .overlay(alignment: .top) { Rule(.hard) }
    }
}
