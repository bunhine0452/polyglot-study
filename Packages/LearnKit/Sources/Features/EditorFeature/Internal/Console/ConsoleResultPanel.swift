internal import DesignSystem
internal import LearnCore
internal import SwiftUI

/// 결과 패널 — 폭 고정 520px(`Spacing.resultPanelWidth`), 출력·테스트 탭 + 상태 행 +
/// stderr 원문 + stdout + 테스트 결과.
///
/// `{#red-budget-guard}`: 이 화면(에디터 콘솔) 소스 전체에서 `Palette.fail` 을 쓰는
/// 지점은 ``ExitCodeBadge`` **한 곳뿐**이다 — 종료 코드 옆 8px 사각. 진단 심각도도,
/// 테스트 실패도 여기서는 색이 아니라 텍스트로만 구별한다.
struct ConsoleResultPanel: View {
    @Bindable var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            switch model.activeTab {
            case .output:
                outputContent
            case .tests:
                testContent
            }
        }
        .frame(width: Spacing.resultPanelWidth, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .leading) { Rule(.hard, axis: .vertical) }
    }

    // MARK: - 탭

    private var tabBar: some View {
        HStack(spacing: Spacing.l) {
            tab("출력", isActive: model.activeTab == .output) { model.activeTab = .output }
            HStack(spacing: Spacing.xs) {
                Text("테스트")
                MonoText("\(testOutcomes.count)", size: .micro)
            }
            .font(AppFont.sans(.label))
            .foregroundStyle(model.activeTab == .tests ? Palette.ink : Palette.secondary)
            .contentShape(Rectangle())
            .onTapGesture { model.activeTab = .tests }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, EditorLayout.panelPadding)
        .frame(height: EditorLayout.panelRowHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Rule(.soft) }
    }

    private func tab(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.sans(.label, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Palette.ink : Palette.secondary)
                .padding(.bottom, Spacing.xs)
                .overlay(alignment: .bottom) {
                    if isActive { Rule(.emphasis) }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 출력 탭

    private var outputContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
            streamSection(label: "stderr", text: model.transcript.hasErrorOutput ? stderrText : nil)
            streamSection(label: "stdout", text: model.transcript.standardOutputText.isEmpty ? nil : model.transcript.standardOutputText)
        }
    }

    private var statusRow: some View {
        HStack {
            Text(statusHeadline)
                .font(AppFont.sans(.note, weight: .medium))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: Spacing.m)
            HStack(spacing: Spacing.m) {
                if let durationText {
                    MonoText(durationText, size: .label, color: Palette.secondary)
                }
                if let exitCode = model.transcript.exitCode {
                    ExitCodeBadge(exitCode: exitCode)
                }
            }
        }
        .padding(.horizontal, EditorLayout.panelPadding)
        .frame(height: EditorLayout.panelRowHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Rule(.soft) }
    }

    private var statusHeadline: String {
        switch model.runState {
        case .idle: "실행 전"
        case .preparing: "준비 중"
        case .compiling: "컴파일 중"
        case .running: "실행 중"
        case .finished(let succeeded, _, _):
            succeeded ? "실행 완료" : (model.diagnostics.contains { $0.severity == .error } ? "컴파일 실패" : "실행 실패")
        case .failed(let reason): reason
        }
    }

    private var durationText: String? {
        guard case .finished(_, _, let ms) = model.runState else { return nil }
        return String(format: "%.2f s", Double(ms) / 1000)
    }

    private var stderrText: String {
        model.transcript.lines
            .filter { $0.stream == .error }
            .map(\.text)
            .joined(separator: "\n")
    }

    private func streamSection(label: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            LabelText(label)
            if let text {
                Text(text)
                    .font(AppFont.mono(.micro))
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                MonoText("출력 없음", size: .label, color: Palette.faint)
            }
        }
        .padding(EditorLayout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rule(.soft) }
    }

    // MARK: - 테스트 탭

    private var testOutcomes: [GradeResult.TestOutcome] {
        model.gradeState.result?.tests ?? []
    }

    private var testContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                LabelText("테스트")
                Spacer(minLength: Spacing.m)
                LabelText(testCaption)
            }
            .padding(.horizontal, EditorLayout.panelPadding)
            .padding(.top, EditorLayout.panelPadding)
            .padding(.bottom, Spacing.s)
            .overlay(alignment: .bottom) { Rule(.hard) }

            ForEach(Array(testRows.enumerated()), id: \.offset) { _, row in
                testRow(row)
            }
        }
    }

    private var testCaption: String {
        switch model.gradeState {
        case .notSubmitted: "컴파일 후 실행됩니다"
        case .grading: "채점 중"
        case .graded(let result): result.passed ? "전부 통과" : "\(result.failedTests.count)개 실패"
        case .failed: "채점 실패"
        }
    }

    /// 표시용 행. 채점 전에는 과제가 예고한 개수만큼 "미실행" 자리를 채운다 — 숨은
    /// 테스트 이름은 채점 전까지 학습자에게 보이면 안 되기 때문이다.
    private struct TestRow { let name: String; let status: String }

    private var testRows: [TestRow] {
        if let result = model.gradeState.result, !result.tests.isEmpty {
            return result.tests.map { TestRow(name: $0.name, status: $0.passed ? "통과" : ($0.message ?? "실패")) }
        }
        guard model.task.testCount > 0 else { return [] }
        return (0..<model.task.testCount).map { _ in TestRow(name: "", status: "미실행") }
    }

    private func testRow(_ row: TestRow) -> some View {
        HStack(spacing: Spacing.m) {
            MonoText("–", size: .label, color: Palette.faint)
                .frame(width: 12, alignment: .center)
            Text(row.name.isEmpty ? "테스트" : row.name)
                .font(AppFont.sans(.note))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: Spacing.s)
            LabelText(row.status)
        }
        .padding(.horizontal, EditorLayout.panelPadding)
        .frame(height: EditorLayout.testRowHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Rule(.soft) }
    }
}

/// 종료 코드 옆 8px 사각. **이 화면에서 `Palette.fail` 을 쓰는 유일한 지점** —
/// `RedBudgetTests` 가 grep 으로 못박는다.
struct ExitCodeBadge: View {
    let exitCode: Int32

    var body: some View {
        HStack(spacing: Spacing.s) {
            MonoText("종료 코드 \(exitCode)", size: .label, color: Palette.secondary)
            Rectangle()
                .fill(exitCode == 0 ? Palette.pass : Palette.fail)
                .frame(width: Rules.statusDotSize, height: Rules.statusDotSize)
        }
    }
}
