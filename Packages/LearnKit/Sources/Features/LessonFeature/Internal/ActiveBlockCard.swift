internal import ContentKit
internal import DesignSystem
internal import SwiftUI

/// 지금 열려 있는 블록 하나. 상단 2px 잉크 룰 + 흰 카드.
///
/// 카드는 한 화면에 **언제나 하나**다. 그 규칙은 ``LessonModel/bodyRows`` 가 지키고,
/// 이 뷰는 그 하나를 그리기만 한다.
struct ActiveBlockCard: View {
    @Bindable var model: LessonModel
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            Rule(.emphasis)
            VStack(alignment: .leading, spacing: LessonLayout.rowGap) {
                LabelText(header, color: Palette.ink)
                Text(model.content.title)
                    .font(AppFont.sans(.title, weight: .semibold))
                    .tracking(-0.24)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                blockBody
                footer
            }
            .padding(.top, LessonLayout.cardPaddingTop)
            .padding(.horizontal, LessonLayout.cardPaddingHorizontal)
            .padding(.bottom, LessonLayout.cardPaddingBottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
        }
    }

    private var header: String {
        let step = model.steps[index]
        return "\(step.ordinal) \(step.name) · 지금"
    }

    @ViewBuilder
    private var blockBody: some View {
        switch model.blocks[index] {
        case .concept(let block):
            ProseView(block.prose)
        case .example(let block):
            ExampleBlockBody(model: model, block: block)
        case .blank(let block):
            BlankBlockBody(model: model, block: block)
        case .task(let block):
            TaskBlockBody(model: model, block: block)
        case .quiz(let block):
            QuizBlockBody(model: model, block: block)
        case .reflection(let block):
            ReflectionBlockBody(model: model, block: block)
        }
    }

    /// 카드 하단 — 주 동작 하나 + 다음 블록. 오른쪽은 안내 한 줄.
    private var footer: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                if let action = model.primaryAction {
                    FlatButton(
                        action.title,
                        emphasis: .primary,
                        shortcutHint: action.shortcutHint,
                        isEnabled: model.primaryActionIsEnabled
                    ) {
                        Task { await model.performPrimaryAction() }
                    }
                    .keyboardShortcut(
                        action == .run ? KeyboardShortcut(.return, modifiers: .command) : nil)
                }
                if let title = model.advanceTitle {
                    FlatButton(title, emphasis: .secondary) { model.advance() }
                }
                // 마지막 블록에만 뜬다. 이게 없으면 레슨이 끝나는 길이 없다.
                if let title = model.finishTitle {
                    FlatButton(title, emphasis: .primary) { model.finish() }
                }
            }
            Spacer(minLength: Spacing.m)
            Text(footerNote)
                .font(AppFont.sans(.label))
                .foregroundStyle(Palette.faint)
                .multilineTextAlignment(.trailing)
        }
    }

    private var footerNote: String {
        switch model.blocks[index].kind {
        case .example: "실행하지 않아도 넘어갈 수 있습니다"
        case .blank: "채점은 앞뒤 공백과 끝의 세미콜론만 무시합니다"
        case .task: "과제는 에디터에서 숨은 테스트로 채점됩니다"
        case .quiz: "선택은 한 번만 확인할 수 있습니다"
        case .reflection: "회고는 채점하지 않습니다"
        case .concept: "읽었으면 다음으로 넘어가세요"
        }
    }
}
