import ContentKit
import PackReport
import LearnCore
import Testing

@testable import PackValidate

/// 의미 단계는 **파서와 독립적으로** 값에 대고 단언해야 한다.
///
/// 그래서 여기서는 마크다운을 거치지 않고 ``LessonDocument`` 를 직접 조립한다 —
/// 파서가 언젠가 느슨해져도 이 게이트는 느슨해지지 않는다는 것이 검사 대상이다.
@Suite("의미 단계")
struct SemanticStageTests {
    private static func document(_ blocks: [LessonBlock]) -> LessonDocument {
        LessonDocument(stableID: LessonID("t"), language: .python, blocks: blocks)
    }

    private static func at(_ line: Int, _ column: Int) -> SourceSpan {
        SourceSpan(
            start: SourcePosition(line: line, column: column),
            end: SourcePosition(line: line, column: column))
    }

    @Test("정답 키가 선택지에 없으면 line:column 과 함께 보고한다")
    func answerNotAChoice() {
        let quiz = QuizBlock(
            id: "q", question: "왜?",
            choices: [
                .init(id: "a", prose: "가", span: Self.at(12, 1)),
                .init(id: "b", prose: "나", span: Self.at(16, 1)),
            ],
            answerID: "c", span: Self.at(10, 1))
        let failures = SemanticStage.failures(in: Self.document([.quiz(quiz)]))
        #expect(failures.count == 1)
        let failure = failures[0]
        #expect(failure.stage == .semantic)
        #expect(failure.kind == .inconsistentAnswer)
        #expect(failure.blockID == "q")
        #expect(failure.line == 10)
        #expect(failure.column == 1)
        #expect(failure.summary.contains("`c`"))
    }

    @Test("선택지가 하나뿐이면 보고한다")
    func tooFewChoices() {
        let quiz = QuizBlock(
            id: "q", question: "왜?",
            choices: [.init(id: "a", prose: "가", span: Self.at(12, 1))],
            answerID: "a", span: Self.at(10, 1))
        let failures = SemanticStage.failures(in: Self.document([.quiz(quiz)]))
        #expect(failures.count == 1)
        #expect(failures[0].summary.contains("2개 이상"))
    }

    @Test("선택지 본문이 비어 있으면 그 선택지의 위치로 보고한다")
    func emptyChoiceProse() {
        let quiz = QuizBlock(
            id: "q", question: "왜?",
            choices: [
                .init(id: "a", prose: "  \n ", span: Self.at(12, 3)),
                .init(id: "b", prose: "나", span: Self.at(16, 3)),
            ],
            answerID: "b", span: Self.at(10, 1))
        let failures = SemanticStage.failures(in: Self.document([.quiz(quiz)]))
        #expect(failures.count == 1)
        #expect(failures[0].line == 12)
        #expect(failures[0].column == 3)
    }

    @Test("빈칸 정답 본문이 비어 있으면 보고한다")
    func emptyAnswerBody() {
        let blank = BlankBlock(
            id: "b", language: .python, prose: "채워라",
            template: "print(___1___)",
            slots: [.init(index: 1, answer: "   ", span: Self.at(20, 1))],
            span: Self.at(18, 1))
        let failures = SemanticStage.failures(in: Self.document([.blank(blank)]))
        #expect(failures.count == 1)
        #expect(failures[0].line == 20)
        #expect(failures[0].summary.contains("slot: 1"))
    }

    @Test("표식과 정답 슬롯이 어긋나면 보고한다")
    func slotCoverageMismatch() {
        let blank = BlankBlock(
            id: "b", language: .python, prose: "채워라",
            template: "print(___1___, ___2___)",
            slots: [.init(index: 1, answer: "x", span: Self.at(20, 1))],
            span: Self.at(18, 1))
        let failures = SemanticStage.failures(in: Self.document([.blank(blank)]))
        #expect(failures.count == 1)
        #expect(failures[0].line == 18)
        #expect(failures[0].evidence?.contains("표식 1,2") == true)
    }

    @Test("앞뒤가 맞는 퀴즈·빈칸은 아무것도 보고하지 않는다")
    func consistentBlocksAreSilent() {
        let quiz = QuizBlock(
            id: "q", question: "왜?",
            choices: [.init(id: "a", prose: "가"), .init(id: "b", prose: "나")],
            answerID: "a")
        let blank = BlankBlock(
            id: "b", language: .python, prose: "채워라",
            template: "print(___1___)", slots: [.init(index: 1, answer: "x")])
        let reflection = ReflectionBlock(id: "r", prompts: [.init(id: "p", prose: "생각해라")])
        #expect(
            SemanticStage.failures(
                in: Self.document([.quiz(quiz), .blank(blank), .reflection(reflection)])
            ).isEmpty)
    }
}
