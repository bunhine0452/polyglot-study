public import SwiftUI
internal import DesignSystem

/// 레슨 화면. 6블록 스텝바 + 접힌 완료 블록 + 펼쳐진 블록 하나 + 예고 한 줄.
///
/// 목 데이터가 없다 — ``LessonModel`` 이 콘텐츠 팩을 `LessonParser` 로 실제 파싱한
/// ``LessonContent`` 만 받는다. 실행 예제도 진짜 러너를 태운다.
public struct LessonView: View {
    @State private var model: LessonModel
    private let onBack: (() -> Void)?

    public init(model: LessonModel, onBack: (() -> Void)? = nil) {
        _model = State(wrappedValue: model)
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 0) {
            LessonTopBar(
                trackCaption: model.trackCaption,
                title: model.content.title,
                blockCaption: model.blockCaption,
                onBack: onBack
            )
            Rule(.hard)
            // 언어가 하나인 레슨에서는 이 줄이 통째로 사라진다.
            if model.languages.count > 1 {
                HStack {
                    LanguagePicker(
                        languages: model.languages,
                        selected: model.language
                    ) { model.selectLanguage($0) }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, LessonLayout.horizontalPadding)
                .padding(.vertical, Spacing.s)
                Rule(.soft)
            }
            LessonStepBar(steps: model.steps) { model.revisit($0) }
            Rule(.soft)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: LessonLayout.rowGap) {
                    ForEach(model.bodyRows) { row in
                        rowView(row)
                    }
                }
                .frame(maxWidth: LessonLayout.columnMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LessonLayout.horizontalPadding)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.paper)
    }

    @ViewBuilder
    private func rowView(_ row: LessonModel.BodyRow) -> some View {
        switch row {
        case .collapsed(let index):
            CollapsedBlockRow(
                ordinal: model.steps[index].ordinal,
                name: model.steps[index].name,
                summary: model.steps[index].summary,
                tone: .done,
                onRevisit: { model.revisit(index) }
            )
        case .expanded(let index):
            ActiveBlockCard(model: model, index: index)
        case .upcoming(let index):
            CollapsedBlockRow(
                ordinal: model.steps[index].ordinal,
                name: model.steps[index].name,
                summary: model.steps[index].summary,
                tone: .next,
                onRevisit: nil
            )
        case .remaining(let first, let last):
            CollapsedBlockRow(
                ordinal: "\(model.steps[first].ordinal) – \(model.steps[last].ordinal)",
                name: (first...last).map { model.steps[$0].name }.joined(separator: " · "),
                summary: "순서대로 열립니다",
                tone: .remaining,
                onRevisit: nil
            )
        }
    }
}
