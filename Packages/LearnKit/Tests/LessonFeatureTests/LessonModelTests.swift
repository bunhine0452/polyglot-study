import ContentKit
import DesignSystem
import Foundation
import LearnCore
import Testing

@testable import LessonFeature

@Suite("레슨 모델 · 스텝바와 본문 행")
struct LessonModelTests {
    @Test("스텝은 여섯 개이고 번호가 01…06 이다")
    func sixSteps() throws {
        let model = try SampleLesson.model()
        #expect(model.steps.count == 6)
        #expect(model.steps.map(\.ordinal) == ["01", "02", "03", "04", "05", "06"])
        #expect(model.steps.map(\.kind) == LessonBlockKind.requiredSequence)
        #expect(
            model.steps.map(\.name) == ["개념", "실행 예제", "빈칸", "테스트 과제", "퀴즈", "회고"])
    }

    @Test("스텝 요약이 레슨 산문에서 나온다 — 빈 줄이 없다", arguments: SampleLesson.all)
    func summariesComeFromProse(_ id: LessonID) throws {
        let model = try SampleLesson.model(id)
        for step in model.steps {
            #expect(!step.summary.isEmpty, "\(step.ordinal) \(step.name) 요약이 비었다")
            // 요약은 평문이어야 한다 — 마크업이 새어 나오면 접힌 행이 깨진다.
            #expect(!step.summary.contains("**"), "\(step.summary)")
            #expect(!step.summary.contains("`"), "\(step.summary)")
        }
    }

    @Test("어느 블록에 있든 활성 스텝은 정확히 하나다")
    func exactlyOneActiveStep() throws {
        let model = try SampleLesson.model()
        for index in 0..<6 {
            while model.activeIndex < index { model.advance() }
            let states = model.steps.map(\.state)
            #expect(states.count(where: { $0 == .active }) == 1, "블록 \(index)")
            #expect(states.count(where: { $0 == .done }) == index)
            #expect(states.count(where: { $0 == .upcoming }) == 5 - index)
            #expect(model.steps[index].state == .active)
        }
    }

    @Test("펼쳐진 본문 행은 언제나 하나다")
    func exactlyOneExpandedRow() throws {
        let model = try SampleLesson.model()
        for index in 0..<6 {
            model.revisit(0)
            while model.activeIndex < index { model.advance() }
            let expanded = model.bodyRows.filter {
                if case .expanded = $0 { return true }
                return false
            }
            #expect(expanded.count == 1, "블록 \(index)")
            #expect(expanded.first == .expanded(index: index))
        }
    }

    @Test("본문 행이 6블록을 빠짐없이, 한 번씩만 덮는다")
    func rowsCoverEveryBlockOnce() throws {
        let model = try SampleLesson.model()
        for index in 0..<6 {
            model.revisit(0)
            while model.activeIndex < index { model.advance() }
            let covered = model.bodyRows.flatMap(\.indices)
            #expect(covered.sorted() == Array(0..<6), "블록 \(index): \(covered)")
            #expect(Set(covered).count == covered.count, "블록 \(index) 에서 중복")
        }
    }

    @Test("행 구성이 디자인 그대로다 — 완료 낱개 · 카드 · 다음 하나 · 나머지 묶음")
    func rowShapeMatchesDesign() throws {
        let model = try SampleLesson.model()
        model.advance()  // 블록 02 실행 예제
        #expect(
            model.bodyRows == [
                .collapsed(index: 0),
                .expanded(index: 1),
                .upcoming(index: 2),
                .remaining(first: 3, last: 5),
            ]
        )
    }

    @Test("끝에서 두 번째 블록에는 묶음 행이 없다")
    func noRemainingRowNearTheEnd() throws {
        let model = try SampleLesson.model()
        for _ in 0..<4 { model.advance() }  // 블록 05 퀴즈
        #expect(
            model.bodyRows == [
                .collapsed(index: 0), .collapsed(index: 1), .collapsed(index: 2),
                .collapsed(index: 3),
                .expanded(index: 4),
                .upcoming(index: 5),
            ]
        )
    }

    @Test("마지막 블록에는 예고 행이 없다")
    func lastBlockHasNoPreview() throws {
        let model = try SampleLesson.model()
        for _ in 0..<5 { model.advance() }
        #expect(model.activeIndex == 5)
        #expect(!model.canAdvance)
        #expect(model.advanceTitle == nil)
        #expect(model.bodyRows.last == .expanded(index: 5))
    }

    @Test("다음 블록 버튼 제목이 실제 다음 블록 이름을 쓴다")
    func advanceTitleNamesNextBlock() throws {
        let model = try SampleLesson.model()
        #expect(model.advanceTitle == "다음 블록 · 실행 예제")
        model.advance()
        #expect(model.advanceTitle == "다음 블록 · 빈칸")
    }

    @Test("앞으로 건너뛰기는 없다 — revisit 는 지나온 블록으로만 간다")
    func revisitOnlyGoesBack() throws {
        let model = try SampleLesson.model()
        model.revisit(4)
        #expect(model.activeIndex == 0)
        model.advance()
        model.advance()
        model.revisit(0)
        #expect(model.activeIndex == 0)
        model.revisit(-1)
        #expect(model.activeIndex == 0)
    }

    @Test("지금 블록을 다시 눌러도 적어 둔 답이 사라지지 않는다")
    func revisitingTheCurrentBlockIsInert() throws {
        let model = try SampleLesson.model()
        model.advance()
        model.advance()  // 03 빈칸
        model.blankEntries[1] = "??"
        model.revisit(2)
        #expect(model.activeIndex == 2)
        #expect(model.blankEntries[1] == "??")
    }

    @Test("마지막에서 더 나아가지 않는다")
    func advanceStopsAtTheEnd() throws {
        let model = try SampleLesson.model()
        for _ in 0..<20 { model.advance() }
        #expect(model.activeIndex == 5)
    }

    @Test("헤더 문구가 매니페스트 값에서 조립된다")
    func captions() throws {
        let model = try SampleLesson.model()
        #expect(model.trackCaption == "Swift · 레슨 01 / 1")
        #expect(model.blockCaption == "블록 1 / 6")
        model.advance()
        #expect(model.blockCaption == "블록 2 / 6")
    }

    @Test("블록을 옮기면 앞 블록의 임시 상태가 남지 않는다")
    func movingResetsTransientState() async throws {
        let model = try SampleLesson.model(events: FakeRunner.succeeding(stdout: "parsed 42\n"))
        model.advance()
        await model.runExample()
        #expect(!model.transcript.isEmpty)

        model.advance()
        #expect(model.transcript.isEmpty)
        #expect(model.runState == .idle)
        #expect(model.blankEntries.isEmpty)
        #expect(model.selectedChoiceID == nil)
        #expect(!model.quizRevealed)
    }
}

@Suite("레슨 모델 · 블록별 주 동작")
struct LessonPrimaryActionTests {
    @Test("블록마다 주 동작이 정해져 있다")
    func actionPerBlock() throws {
        let model = try SampleLesson.model(onOpenEditor: { _ in })
        let expected: [LessonModel.PrimaryAction?] = [
            nil, .run, .checkBlanks, .openEditor, .revealQuiz, nil,
        ]
        for (index, action) in expected.enumerated() {
            model.revisit(0)
            while model.activeIndex < index { model.advance() }
            #expect(model.primaryAction == action, "블록 \(index)")
        }
    }

    @Test("에디터 콜백이 없으면 과제 블록에 주 동작이 없다")
    func noEditorCallbackMeansNoAction() throws {
        let model = try SampleLesson.model()
        for _ in 0..<3 { model.advance() }
        #expect(model.primaryAction == nil)
        #expect(!model.canOpenEditor)
    }

    @Test("주 동작 네 개의 제목이 서로 다르고, 단축키는 실행에만 붙는다")
    func actionTitles() {
        let titles = LessonModel.PrimaryAction.allCases.map(\.title)
        #expect(Set(titles).count == 4)
        #expect(LessonModel.PrimaryAction.run.shortcutHint == "⌘↩")
        for action in LessonModel.PrimaryAction.allCases where action != .run {
            #expect(action.shortcutHint == nil)
        }
    }

    @Test("에디터 열기가 실제 과제 블록을 넘긴다")
    func openEditorPassesTask() async throws {
        var opened: TaskBlock?
        let model = try SampleLesson.model(onOpenEditor: { opened = $0 })
        for _ in 0..<3 { model.advance() }
        await model.performPrimaryAction()
        #expect(opened?.id == "safe-divide")
        #expect(opened?.starterPath.rawValue == "starters/swift-0001-safe-divide.swift")
    }
}
