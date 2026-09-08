import ContentKit
import Foundation
import LearnCore
import Testing

@testable import LessonFeature

/// 화면이 그리는 것이 **샘플 팩의 실제 레슨**인지 본다. 목 픽스처가 하나도 없다는 사실을
/// 여기서 고정한다 — 팩이 깨지면 화면 테스트가 먼저 빨개져야 한다.
@Suite("레슨 콘텐츠 · 샘플 팩 실제 파싱")
struct LessonContentTests {
    @Test("샘플 팩이 리포에 있고 세 레슨을 싣고 있다")
    func packExists() throws {
        #expect(FileManager.default.fileExists(atPath: RepoPaths.samplePack.path))
        let pack = try SampleLesson.pack()
        #expect(pack.manifest.lessons.count == 3)
        #expect(Set(pack.manifest.lessons.map(\.stableID)) == Set(SampleLesson.all))
    }

    @Test("세 레슨 모두 6블록이 규정 순서로 파싱된다", arguments: SampleLesson.all)
    func sixBlocksInOrder(_ id: LessonID) throws {
        let content = try SampleLesson.content(id)
        #expect(content.blocks.count == 6)
        #expect(content.blocks.map(\.kind) == LessonBlockKind.requiredSequence)
    }

    @Test("제목·트랙·순번이 매니페스트에서 온다", arguments: SampleLesson.all)
    func identityComesFromManifest(_ id: LessonID) throws {
        let pack = try SampleLesson.pack()
        let entry = try #require(pack.manifest.lesson(id))
        let content = try SampleLesson.content(id)
        #expect(content.title == entry.title)
        #expect(content.order == entry.order)
        #expect(content.language == entry.primaryLanguage)
        #expect(content.objectives == entry.objectives)
        #expect(content.totalInTrack >= 1)
    }

    @Test("Swift 레슨의 실제 내용이 그대로 실려 온다")
    func swiftLessonRoundTrip() throws {
        let content = try SampleLesson.content(SampleLesson.swift)
        #expect(content.title == "옵셔널 다루기")
        #expect(content.trackName == "Swift")

        let example = try #require(content.document.example(for: content.document.primaryLanguage))
        #expect(example.codeFenceLanguage == "swift")
        #expect(example.code.contains("if let text = raw"))
        // 기대 출력 사이드카가 실제로 읽힌다.
        #expect(content.expectedOutput?.trimmingCharacters(in: .whitespacesAndNewlines) == "parsed 42")

        let blank = try #require(content.document.blank(for: content.document.primaryLanguage))
        #expect(blank.slots.map(\.index) == [1])
        #expect(blank.slots[0].answer == "??")

        let task = try #require(content.document.task(for: content.document.primaryLanguage))
        #expect(task.hints.count == 1)
        #expect(content.starterSource?.isEmpty == false)

        let quiz = try #require(content.document.quiz)
        #expect(quiz.choices.count == 3)
        #expect(quiz.answerID == "force-unwrap-crashes")
        #expect(quiz.explanation?.isEmpty == false)

        let reflection = try #require(content.document.reflection)
        #expect(reflection.prompts.count == 2)
    }

    @Test("SQL 레슨은 빈칸이 둘이고 정답이 대문자 키워드다")
    func sqlLessonBlanks() throws {
        let content = try SampleLesson.content(SampleLesson.sql)
        let blank = try #require(content.document.blank(for: content.document.primaryLanguage))
        #expect(blank.slots.map(\.index) == [1, 2])
        #expect(blank.slots.map(\.answer) == ["SUM", "product"])
    }

    @Test("모르는 레슨 id 는 에러다 — 조용히 빈 화면이 되지 않는다")
    func unknownLessonThrows() throws {
        let pack = try SampleLesson.pack()
        #expect(throws: ContentPackError.self) {
            try LessonContent.load(pack: pack, lessonID: LessonID("does-not-exist"))
        }
    }

    @Test("트랙 이름이 10개 언어를 전부 덮는다")
    func trackNames() {
        let expected = [
            "python": "Python", "sql": "SQL", "swift": "Swift", "rust": "Rust",
            "cpp": "C++", "go": "Go", "java": "Java", "nextjs": "Next.js",
            "typescript": "TypeScript", "assembly": "Assembly",
        ]
        for (raw, name) in expected {
            #expect(LessonContent.trackName(for: LanguageID(raw)) == name)
        }
        // 모르는 언어는 raw 를 그대로 — 화면이 빈칸이 되지 않는다.
        #expect(LessonContent.trackName(for: LanguageID("cobol")) == "cobol")
    }
}
