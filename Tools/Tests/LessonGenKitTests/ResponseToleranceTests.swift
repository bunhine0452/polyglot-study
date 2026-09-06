import ContentKit
import Foundation
import LearnCore
import LessonGenKit
import LLMKit
import Testing
import TestSupport

/// 구조화 출력을 걸어도 업스트림이 문법을 유도만 하는 경우가 있다. 실측한 것만 관대하게
/// 받아 넘기고, 그 밖은 그대로 거부한다.
@Suite("응답 관용 — 실측된 것만")
struct ResponseToleranceTests {
    @Test("스키마를 만족한 뒤 중괄호가 하나 더 붙어 와도 살린다 — 실측된 실패")
    func trailingBrace() throws {
        let response = LessonFixtures.response(text: LessonFixtures.draftJSON() + "}")
        let draft = try LessonGenerator.decodeDraft(from: response)
        #expect(draft.concept.id == "fstring-basics")
    }

    @Test("코드펜스로 감싸 보내도 살린다")
    func fencedJSON() throws {
        let response = LessonFixtures.response(
            text: "```json\n" + LessonFixtures.draftJSON() + "\n```")
        let draft = try LessonGenerator.decodeDraft(from: response)
        #expect(draft.quiz.answerChoiceID == "repr-conversion")
    }

    @Test("앞에 한 줄 설명을 붙여 보내도 살린다")
    func prefixedProse() throws {
        let response = LessonFixtures.response(
            text: "요청하신 레슨입니다.\n\n" + LessonFixtures.draftJSON())
        #expect(throws: Never.self) { try LessonGenerator.decodeDraft(from: response) }
    }

    @Test("문자열 안의 중괄호는 세지 않는다")
    func bracesInsideStrings() throws {
        var draft = LessonFixtures.draft()
        draft.example.code = "print(f\"{{literal}} {name}\")"
        draft.example.expectedStdout = "{literal} x\n"
        let response = LessonFixtures.response(text: LessonFixtures.draftJSON(draft) + "\n\n끝.")
        let decoded = try LessonGenerator.decodeDraft(from: response)
        #expect(decoded.example.code.contains("{{literal}}"))
    }

    @Test("JSON 이 아예 없으면 거부한다 — 관용은 여기까지다")
    func rejectsProse() {
        #expect(throws: LessonGenerationError.self) {
            try LessonGenerator.decodeDraft(
                from: LessonFixtures.response(text: "죄송하지만 그 요청은 도와드릴 수 없습니다."))
        }
    }

    @Test("스키마를 못 맞추면 사유를 붙여 다시 묻는다")
    func retriesOnSchemaMiss() async throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = FakeProvider(
            capabilities: [.structuredOutputs, .usageTokens],
            steps: [
                .success(LessonFixtures.response(text: "{\"concept\": {\"id\": \"a\"}}")),
                .success(LessonFixtures.response(text: LessonFixtures.draftJSON())),
            ])
        let log = try LessonFixtures.runLog(directory: directory)
        let generator = LessonGenerator(client: MeteredClient(provider: provider, log: log))

        let lesson = try await generator.generate(
            LessonGenerator.Request(
                outline: LessonFixtures.outline(), language: .python, trackTitle: "t"))
        #expect(lesson.stableID == LessonID("python-fstring"))
        #expect(provider.requests.count == 2)
        #expect(provider.requests[1].messages[2].text.contains("JSON 객체 하나만"))
    }

    @Test("잘린 응답은 다시 묻지 않는다 — 같은 요청은 또 잘린다")
    func doesNotRetryTruncation() async throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let truncated = CompletionResponse(
            id: "x", model: "m", text: "{\"concept\"", finishReason: .length,
            usage: TokenUsage(outputTokens: 100))
        let provider = FakeProvider(
            capabilities: [.structuredOutputs, .usageTokens],
            steps: [.success(truncated), .success(truncated)])
        let log = try LessonFixtures.runLog(directory: directory)
        let generator = LessonGenerator(client: MeteredClient(provider: provider, log: log))

        await #expect(throws: LessonGenerationError.self) {
            try await generator.generate(
                LessonGenerator.Request(
                    outline: LessonFixtures.outline(), language: .python, trackTitle: "t"))
        }
        #expect(provider.requests.count == 1)
    }
}

@Suite("매달린 선수 관계")
struct DanglingPrerequisiteTests {
    @Test("팩에 없는 레슨을 가리키는 선수 관계는 떼어 내고 무엇을 뗐는지 알린다")
    func dropsAndReports() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 1편이 실패하고 2편만 성공한 상황.
        let second = try LessonAssembler.assemble(
            draft: LessonFixtures.draft(),
            outline: LessonFixtures.outline(
                slug: "second", ordinal: 2, prerequisites: [LessonID("python.first")]),
            language: .python,
            generatorModel: "m")

        let writer = PackWriter(directory: directory)
        let written = try writer.write(
            lessons: [second],
            header: PackWriter.Header(
                packID: PackID("p"), displayName: "p", generatedAt: "2026-09-06T00:00:00Z"))

        #expect(written.droppedPrerequisites.count == 1)
        #expect(written.droppedPrerequisites[0].prerequisite == LessonID("python-first"))
        #expect(written.manifest.lessons[0].prerequisites.isEmpty)
        // 떼지 않았으면 여기서 매니페스트 검증이 통째로 실패한다.
        try writer.verify()
    }

    @Test("선수 레슨이 팩에 있으면 그대로 남는다")
    func keepsResolvedPrerequisites() throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try LessonAssembler.assemble(
            draft: LessonFixtures.draft(),
            outline: LessonFixtures.outline(slug: "first", ordinal: 1),
            language: .python, generatorModel: "m")
        let second = try LessonAssembler.assemble(
            draft: LessonFixtures.draft(),
            outline: LessonFixtures.outline(
                slug: "second", ordinal: 2, prerequisites: [LessonID("python.first")]),
            language: .python, generatorModel: "m")

        let writer = PackWriter(directory: directory)
        let written = try writer.write(
            lessons: [first, second],
            header: PackWriter.Header(
                packID: PackID("p"), displayName: "p", generatedAt: "2026-09-06T00:00:00Z"))
        #expect(written.droppedPrerequisites.isEmpty)
        #expect(
            written.manifest.lesson(LessonID("python-second"))?.prerequisites
                == [LessonID("python-first")])
    }
}
