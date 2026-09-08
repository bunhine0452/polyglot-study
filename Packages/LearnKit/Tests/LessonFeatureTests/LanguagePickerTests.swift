import ContentKit
import Foundation
import LearnCore
import Testing

@testable import DesignSystem

@testable import LessonFeature

/// {#lesson-language-picker} — 알고리즘 레슨은 한 편을 여러 언어로 풀 수 있어야 하고,
/// 언어를 바꿔도 개념·퀴즈·돌아보기는 그대로여야 한다.
@Suite("레슨 화면 · 풀이 언어 선택")
@MainActor
struct LanguagePickerTests {
    /// 예제·빈칸·과제만 언어별인 두 언어짜리 레슨. 개념·퀴즈·돌아보기는 공용이다.
    private func twoLanguageContent() throws -> LessonContent {
        let source = ReferenceLessonSource.twoLanguages
        let blocks = try LessonParser.parse(source: source)
        let document = LessonDocument(
            stableID: LessonID("algo-binary-search"),
            languages: LessonParser.orderedLanguages(in: blocks),
            blocks: blocks)
        return LessonContent(
            document: document,
            title: "이진 탐색",
            trackName: "알고리즘",
            order: 1,
            totalInTrack: 32)
    }

    @Test("언어가 하나면 고를 것이 없다 — 기존 레슨은 선택이 뜨지 않는다")
    func singleLanguageHasNoChoice() throws {
        let model = try SampleLesson.model(SampleLesson.swift)
        #expect(model.languages == [.swift])
        #expect(model.languages.count == 1)
    }

    @Test("언어를 바꾸면 예제·빈칸·과제만 갈아탄다")
    func switchingSwapsOnlyLanguageBlocks() throws {
        let model = LessonModel(content: try twoLanguageContent())
        #expect(model.languages == [.swift, .python])
        #expect(model.language == .swift)

        let conceptBefore = model.content.document.concept?.id
        let quizBefore = model.content.document.quiz?.id

        model.selectLanguage(.python)

        #expect(model.language == .python)
        // 공용 블록은 그대로다 — 이진 탐색이 무엇인지는 언어와 무관하다.
        #expect(model.content.document.concept?.id == conceptBefore)
        #expect(model.content.document.quiz?.id == quizBefore)
        // 언어별 블록은 갈아탔다.
        #expect(model.blocks.compactMap(\.language).allSatisfy { $0 == .python })
        // 블록 수와 순서는 언어와 무관하다.
        #expect(model.blocks.map(\.kind) == LessonBlockKind.requiredSequence)
    }

    @Test("언어를 바꾸면 빈칸 답과 실행 결과가 지워진다 — 다른 코드의 것이기 때문")
    func switchingClearsLanguageScopedState() throws {
        let model = LessonModel(content: try twoLanguageContent())
        model.blankEntries[1] = "??"

        model.selectLanguage(.python)

        #expect(model.blankEntries.isEmpty)
        #expect(model.transcript == .empty)
        #expect(model.resultSet == nil)
        #expect(model.diagnostics.isEmpty)
    }

    @Test("보고 있던 블록 자리는 지킨다 — 순서가 언어와 무관하기 때문")
    func switchingKeepsActiveBlock() throws {
        let model = LessonModel(content: try twoLanguageContent())
        model.revisit(3)
        let before = model.activeIndex

        model.selectLanguage(.python)

        #expect(model.activeIndex == before)
    }

    @Test("선언되지 않은 언어는 무시한다 — 모델이 스스로를 지킨다")
    func unknownLanguageIsIgnored() throws {
        let model = LessonModel(content: try twoLanguageContent())
        model.selectLanguage(.rust)
        #expect(model.language == .swift)
    }
}
