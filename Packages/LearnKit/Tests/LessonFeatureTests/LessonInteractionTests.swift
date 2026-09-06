import ContentKit
import DesignSystem
import Foundation
import LearnCore
import Testing

@testable import LessonFeature

@Suite("레슨 상호작용 · 빈칸")
struct LessonBlankTests {
    /// 빈칸 블록(03)으로 옮긴 SQL 레슨 모델. 슬롯이 둘이라 부분 정답을 볼 수 있다.
    static func sqlBlankModel() throws -> LessonModel {
        let model = try SampleLesson.model(SampleLesson.sql)
        model.advance()
        model.advance()
        return model
    }

    @Test("채점 전에는 결과가 없다")
    func nothingBeforeChecking() throws {
        let model = try Self.sqlBlankModel()
        #expect(model.blankResults.isEmpty)
        #expect(!model.blanksAreComplete)
        #expect(!model.primaryActionIsEnabled)
    }

    @Test("모든 슬롯을 채워야 채점 버튼이 열린다")
    func completionGatesTheButton() throws {
        let model = try Self.sqlBlankModel()
        model.blankEntries[1] = "SUM"
        #expect(!model.blanksAreComplete)
        model.blankEntries[2] = "product"
        #expect(model.blanksAreComplete)
        #expect(model.primaryActionIsEnabled)
    }

    @Test("팩의 실제 정답으로 채점한다")
    func gradesAgainstPackAnswers() throws {
        let model = try Self.sqlBlankModel()
        model.blankEntries = [1: "SUM", 2: "product"]
        model.checkBlanks()
        #expect(model.blankResults == [1: true, 2: true])
        #expect(model.blanksAreCorrect)
    }

    @Test("틀린 슬롯만 실패로 표시된다")
    func partialFailure() throws {
        let model = try Self.sqlBlankModel()
        model.blankEntries = [1: "COUNT", 2: "product"]
        model.checkBlanks()
        #expect(model.blankResults == [1: false, 2: true])
        #expect(!model.blanksAreCorrect)
    }

    @Test("앞뒤 공백과 끝 세미콜론만 봐준다")
    func lenientOnlyOnWhitespaceAndSemicolon() {
        #expect(LessonModel.matches("SUM", "  SUM  "))
        #expect(LessonModel.matches("product", "product;"))
        // 알파벳 정답은 대소문자를 봐준다 — SQL 키워드가 그렇다.
        #expect(LessonModel.matches("SUM", "sum"))
        // 기호가 섞인 정답은 글자 그대로여야 한다.
        #expect(LessonModel.matches("??", "??"))
        #expect(!LessonModel.matches("??", "?"))
        #expect(!LessonModel.matches("SUM", "SUM(price)"))
    }

    @Test("Swift 레슨의 한 칸짜리 빈칸도 같은 규칙으로 채점된다")
    func swiftSingleSlot() throws {
        let model = try SampleLesson.model()
        model.advance()
        model.advance()
        model.blankEntries[1] = "??"
        model.checkBlanks()
        #expect(model.blanksAreCorrect)
    }

    @Test("채점하면 채운 코드가 보인다 — 표식이 남지 않는다")
    func filledTemplateReplacesMarkers() throws {
        let model = try Self.sqlBlankModel()
        let blank = try #require(model.content.document.blank)
        #expect(blank.template.contains("___1___"))
        model.blankEntries = [1: "SUM", 2: "product"]
        model.checkBlanks()
        #expect(model.blanksAreCorrect)
        #expect(!blank.filledTemplate().contains("___"))
        #expect(blank.filledTemplate().contains("SUM(price * quantity)"))
    }
}

@Suite("레슨 상호작용 · 퀴즈")
struct LessonQuizTests {
    static func quizModel() throws -> LessonModel {
        let model = try SampleLesson.model()
        for _ in 0..<4 { model.advance() }
        return model
    }

    @Test("고르기 전에는 확인할 수 없다")
    func selectionGatesReveal() throws {
        let model = try Self.quizModel()
        #expect(model.selectedChoiceID == nil)
        #expect(!model.primaryActionIsEnabled)
        model.revealQuiz()
        #expect(!model.quizRevealed)
    }

    @Test("팩의 실제 정답 id 로 채점한다")
    func gradesAgainstPackAnswer() throws {
        let model = try Self.quizModel()
        model.selectChoice("force-unwrap-crashes")
        #expect(model.quizIsCorrect == true)
        model.revealQuiz()
        #expect(model.quizRevealed)
    }

    @Test("오답을 고르면 오답이다")
    func wrongChoice() throws {
        let model = try Self.quizModel()
        model.selectChoice("returns-zero")
        #expect(model.quizIsCorrect == false)
    }

    @Test("확인한 뒤에는 선택을 바꿀 수 없다")
    func selectionIsLockedAfterReveal() throws {
        let model = try Self.quizModel()
        model.selectChoice("returns-zero")
        model.revealQuiz()
        model.selectChoice("force-unwrap-crashes")
        #expect(model.selectedChoiceID == "returns-zero")
        #expect(!model.primaryActionIsEnabled)
    }

    @Test("정답 id 가 실제 선택지 중 하나다 — 팩이 가리키는 곳이 있어야 한다")
    func answerIDResolves() throws {
        for id in SampleLesson.all {
            let quiz = try #require(SampleLesson.content(id).document.quiz)
            #expect(quiz.answer != nil, "\(id.rawValue) 의 정답 id 가 선택지를 못 찾는다")
        }
    }
}

@Suite("레슨 상호작용 · 회고")
struct LessonReflectionTests {
    @Test("회고는 채점하지 않고 프롬프트별로 답을 들고 있는다")
    func notesArePerPrompt() throws {
        let model = try SampleLesson.model()
        for _ in 0..<5 { model.advance() }
        let reflection = try #require(model.content.document.reflection)
        #expect(model.primaryAction == nil)

        model.reflectionNotes[reflection.prompts[0].id] = "첫 답"
        model.reflectionNotes[reflection.prompts[1].id] = "둘째 답"
        #expect(model.reflectionNotes["api-design"] == "첫 답")
        #expect(model.reflectionNotes["chaining"] == "둘째 답")
    }
}
