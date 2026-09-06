internal import ContentKit
internal import DesignSystem
internal import LearnCore
internal import SwiftUI

// MARK: - 실행 예제

/// 읽고 실행만 하는 블록. 편집하지 않는다.
///
/// 출력 영역은 **실행 전에도 자리를 잡는다**(``ResultSlot``). 실행 버튼을 눌렀을 때
/// 결과가 0에서 커지면 그 위의 코드가 통째로 밀려 올라가고, 학습자가 방금 읽던 줄이
/// 눈앞에서 움직인다.
struct ExampleBlockBody: View {
    let model: LessonModel
    let block: ExampleBlock

    var body: some View {
        VStack(alignment: .leading, spacing: LessonLayout.rowGap) {
            ProseView(block.prose)
            ProseCodeBlock(block.code, language: block.codeFenceLanguage)
            ResultSlot(.lessonOutput) {
                ResultPresenterView(
                    model.presenter,
                    transcript: model.transcript,
                    resultSet: model.resultSet
                )
            }
            if !model.diagnostics.isEmpty {
                DiagnosticList(diagnostics: model.diagnostics)
            }
            if let matches = model.matchesExpectedOutput {
                HStack(spacing: Spacing.s) {
                    StatusDot(matches ? .pass : .fail, label: matches ? "기대와 같음" : "기대와 다름")
                    Text(matches ? "기대 출력과 같습니다." : "기대 출력과 다릅니다.")
                        .font(AppFont.sans(.label))
                        .foregroundStyle(matches ? Palette.pass : Palette.fail)
                }
            }
        }
    }
}

/// 러너가 낸 진단. 색은 심각도가 아니라 **실패 여부**에만 쓴다.
struct DiagnosticList: View {
    let diagnostics: [Diagnostic]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                HStack(alignment: .top, spacing: Spacing.s) {
                    StatusDot(
                        diagnostic.severity == .error ? .fail : .empty,
                        size: .gutterMark
                    )
                    .padding(.top, Spacing.xs)
                    MonoText(location(diagnostic), size: .micro, color: Palette.faint)
                    Text(diagnostic.message)
                        .font(AppFont.sans(.label))
                        .foregroundStyle(
                            diagnostic.severity == .error ? Palette.fail : Palette.secondary
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func location(_ diagnostic: Diagnostic) -> String {
        guard let line = diagnostic.line else { return diagnostic.file ?? "—" }
        let file = diagnostic.file ?? ""
        return diagnostic.column.map { "\(file):\(line):\($0)" } ?? "\(file):\(line)"
    }
}

// MARK: - 빈칸

/// 슬롯 표식이 박힌 코드를 보여 주고, 슬롯마다 한 줄 입력을 받는다.
///
/// 코드 안에 입력 상자를 끼워 넣지 않는 이유는 정렬 때문이다 — 모노 코드 한가운데
/// 가변 폭 입력이 들어가면 그 줄만 어긋나고, 학습자가 읽어야 할 것은 코드 모양이다.
struct BlankBlockBody: View {
    @Bindable var model: LessonModel
    let block: BlankBlock

    var body: some View {
        VStack(alignment: .leading, spacing: LessonLayout.rowGap) {
            ProseView(block.prose)
            ProseCodeBlock(displayedTemplate, language: block.codeFenceLanguage)
            VStack(alignment: .leading, spacing: Spacing.s) {
                ForEach(block.slots, id: \.index) { slot in
                    slotRow(slot)
                }
            }
        }
    }

    /// 채점을 통과했으면 채워진 코드를, 아니면 표식이 그대로인 템플릿을 보여 준다.
    private var displayedTemplate: String {
        model.blanksAreCorrect ? block.filledTemplate() : block.template
    }

    private func slotRow(_ slot: BlankBlock.Slot) -> some View {
        HStack(spacing: Spacing.s) {
            MonoText(BlankSlotMarker.marker(slot.index), size: .micro, color: Palette.faint)
                .frame(width: 72, alignment: .leading)
            TextField(
                "",
                text: Binding(
                    get: { model.blankEntries[slot.index] ?? "" },
                    set: { model.blankEntries[slot.index] = $0 }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: Typography.Mono.code.rawValue, design: .monospaced))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.s)
            .frame(height: Spacing.xl, alignment: .leading)
            .frame(minWidth: 160, maxWidth: 320, alignment: .leading)
            .overlay {
                Rectangle().strokeBorder(borderColor(slot), lineWidth: Rules.thickness)
            }
            if let correct = model.blankResults[slot.index] {
                HStack(spacing: Spacing.xs) {
                    StatusDot(correct ? .pass : .fail)
                    if !correct {
                        MonoText(slot.answer, size: .code, color: Palette.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func borderColor(_ slot: BlankBlock.Slot) -> Color {
        guard let correct = model.blankResults[slot.index] else { return Palette.ruleSoft }
        return correct ? Palette.pass : Palette.fail
    }
}

// MARK: - 테스트 과제

/// 편집은 에디터 화면에서 한다. 여기서는 무엇을 만들어야 하는지와 시작 코드만 보여 준다.
struct TaskBlockBody: View {
    let model: LessonModel
    let block: TaskBlock
    @State private var revealedHints = 0

    var body: some View {
        VStack(alignment: .leading, spacing: LessonLayout.rowGap) {
            ProseView(block.prose)
            if let starter = model.content.starterSource {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    LabelText("시작 코드 · \(block.starterPath.rawValue)")
                    ProseCodeBlock(starter)
                }
            }
            if !block.hints.isEmpty {
                hints
            }
        }
    }

    private var hints: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(block.hints.prefix(revealedHints), id: \.order) { hint in
                HStack(alignment: .top, spacing: Spacing.s) {
                    LabelText("힌트 \(hint.order)")
                        .frame(width: 56, alignment: .leading)
                    ProseView(hint.prose, scale: .compact)
                }
            }
            if revealedHints < block.hints.count {
                Button {
                    revealedHints += 1
                } label: {
                    Text("힌트 보기 (\(revealedHints) / \(block.hints.count))")
                        .font(AppFont.sans(.label))
                        .foregroundStyle(Palette.ink)
                        .overlay(alignment: .bottom) {
                            Rule(.hard).offset(y: Rules.thickness)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 퀴즈

struct QuizBlockBody: View {
    let model: LessonModel
    let block: QuizBlock

    var body: some View {
        VStack(alignment: .leading, spacing: LessonLayout.rowGap) {
            ProseView(block.question)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(block.choices, id: \.id) { choice in
                    choiceRow(choice)
                    Rule(.soft)
                }
            }
            if model.quizRevealed, let explanation = block.explanation {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(spacing: Spacing.s) {
                        StatusDot(model.quizIsCorrect == true ? .pass : .fail)
                        Text(model.quizIsCorrect == true ? "정답입니다." : "정답이 아닙니다.")
                            .font(AppFont.sans(.label, weight: .medium))
                            .foregroundStyle(
                                model.quizIsCorrect == true ? Palette.pass : Palette.fail)
                    }
                    ProseView(explanation, scale: .compact)
                }
                .padding(.top, Spacing.xs)
            }
        }
    }

    private func choiceRow(_ choice: QuizBlock.Choice) -> some View {
        let isSelected = model.selectedChoiceID == choice.id
        let isAnswer = choice.id == block.answerID
        return Button {
            model.selectChoice(choice.id)
        } label: {
            HStack(alignment: .top, spacing: Spacing.s) {
                StatusDot(marker(isSelected: isSelected, isAnswer: isAnswer))
                    .padding(.top, Spacing.xs + 1)
                ProseView(choice.prose, scale: .compact)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.quizRevealed)
    }

    /// 확인 전에는 선택 여부만 보인다. 색이 답을 미리 흘리면 퀴즈가 아니다.
    private func marker(isSelected: Bool, isAnswer: Bool) -> StatusDot.Style {
        guard model.quizRevealed else { return isSelected ? .ink : .emptyInk }
        if isAnswer { return .pass }
        return isSelected ? .fail : .empty
    }
}

// MARK: - 회고

/// 채점하지 않는 열린 질문. 답은 나중에 오답 노트로 간다.
struct ReflectionBlockBody: View {
    @Bindable var model: LessonModel
    let block: ReflectionBlock

    var body: some View {
        VStack(alignment: .leading, spacing: LessonLayout.rowGap) {
            ForEach(block.prompts, id: \.id) { prompt in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ProseView(prompt.prose)
                    TextField(
                        "여기에 적어 두면 나중에 복습에서 다시 만납니다",
                        text: Binding(
                            get: { model.reflectionNotes[prompt.id] ?? "" },
                            set: { model.reflectionNotes[prompt.id] = $0 }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(AppFont.sans(.note))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(3...6)
                    .padding(Spacing.s)
                    .overlay {
                        Rectangle().strokeBorder(Palette.ruleSoft, lineWidth: Rules.thickness)
                    }
                }
            }
        }
    }
}
