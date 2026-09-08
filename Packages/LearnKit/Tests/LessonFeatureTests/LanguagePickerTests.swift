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
            packID: PackID("polyglot-algorithms"),
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

/// {#progress-per-lesson-not-language} — 레슨 화면이 블록을 끝낼 때마다 진도를 적는다.
/// 이전에는 `completeBlock` 호출처가 한 곳도 없어 진도가 테스트 시드로만 존재했다.
@Suite("레슨 화면 · 진도 저장")
@MainActor
struct LessonProgressRecordingTests {
    /// 기록된 것을 그대로 모아 두는 수집기. 스토어를 통째로 세우지 않는 이유는 여기서
    /// 검증하려는 것이 **화면이 무엇을 언제 부르는가**이지 저장소의 동작이 아니기 때문이다.
    private final class Recorder: @unchecked Sendable {
        private let box = Box()
        var succeeds = true

        /// `nonisolated` 상자. 모듈 기본 격리가 `MainActor` 라(uiSettings) 그냥 두면
        /// `@Sendable` 클로저 안에서 저장 프로퍼티를 건드릴 수 없다.
        private nonisolated final class Box: @unchecked Sendable {
            private let mutex = NSLock()
            private var entries: [(LessonRef, LanguageID, Int)] = []

            nonisolated func append(_ entry: (LessonRef, LanguageID, Int)) {
                mutex.lock()
                entries.append(entry)
                mutex.unlock()
            }

            nonisolated func all() -> [(LessonRef, LanguageID, Int)] {
                mutex.lock()
                defer { mutex.unlock() }
                return entries
            }
        }

        var recorded: [(LessonRef, LanguageID, Int)] { box.all() }

        func callback() -> @Sendable (LessonRef, LanguageID, Int) async -> Bool {
            let box = self.box
            let succeeds = self.succeeds
            return { ref, language, index in
                box.append((ref, language, index))
                return succeeds
            }
        }
    }


    /// 기록이 `count` 건에 이를 때까지 기다린다. 고정 시간 대기는 부하가 걸릴 때 깨진다 —
    /// 전체 스위트를 함께 돌리면 실측으로 그랬다.
    private func waitForRecords(_ recorder: Recorder, count: Int) async throws {
        for _ in 0..<200 {
            if recorder.recorded.count >= count { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("기록 \(count)건을 기다렸지만 \(recorder.recorded.count)건에서 멈췄다")
    }

    private func model(_ recorder: Recorder) throws -> LessonModel {
        LessonModel(
            content: try SampleLesson.content(SampleLesson.swift),
            recordBlock: recorder.callback())
    }

    @Test("블록을 넘길 때마다 **방금 끝낸** 블록이 기록된다")
    func advanceRecordsTheFinishedBlock() async throws {
        let recorder = Recorder()
        let model = try model(recorder)

        model.advance()
        model.advance()
        try await waitForRecords(recorder, count: 2)

        // 넘어간 자리가 아니라 **떠난 자리**를 적는다 — 다음 블록은 아직 안 끝났다.
        #expect(recorder.recorded.map(\.2) == [0, 1])
        #expect(recorder.recorded.allSatisfy { $0.1 == .swift })
        #expect(recorder.recorded.allSatisfy { $0.0.lessonID == SampleLesson.swift })
    }

    @Test("마지막 블록에는 마치기가 뜨고, 그것이 마지막 블록을 기록한다")
    func finishRecordsTheLastBlock() async throws {
        let recorder = Recorder()
        let model = try model(recorder)

        #expect(model.finishTitle == nil, "중간 블록에서는 마치기가 없다")
        while model.canAdvance { model.advance() }
        #expect(model.finishTitle != nil)

        // 기록은 비동기다 — 앞선 `advance()` 들이 다 도착한 뒤에 세야 한다.
        let advanced = model.blocks.count - 1
        try await waitForRecords(recorder, count: advanced)
        model.finish()
        try await waitForRecords(recorder, count: advanced + 1)

        // 마치기가 없으면 마지막 블록이 영영 기록되지 않아 레슨이 완료로 전이하지 못한다.
        #expect(recorder.recorded.count == advanced + 1)
        #expect(recorder.recorded.last?.2 == model.blocks.count - 1)
    }

    @Test("진도 쓰기가 실패하면 조용히 넘어가지 않는다")
    func failureIsVisible() async throws {
        let recorder = Recorder()
        recorder.succeeds = false
        let model = try model(recorder)

        #expect(!model.progressFailed)
        model.advance()
        try await waitForRecords(recorder, count: 1)
        for _ in 0..<200 where !model.progressFailed {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.progressFailed)
    }

    @Test("기록기를 안 주면 아무것도 적지 않는다 — 화면은 그대로 돈다")
    func withoutRecorderNothingBreaks() throws {
        let model = LessonModel(content: try SampleLesson.content(SampleLesson.swift))
        model.advance()
        #expect(model.activeIndex == 1)
        #expect(!model.progressFailed)
    }
}
