import Foundation
import LearnCore
import LessonGenKit
import LLMKit
import Testing
import TestSupport

@Suite("레슨 생성 — 요청 조립과 캐시 접두사")
struct LessonGeneratorTests {
    private func request(slug: String = "fstring") -> LessonGenerator.Request {
        LessonGenerator.Request(
            outline: LessonFixtures.outline(slug: slug),
            language: .python,
            trackTitle: "파이썬 입문")
    }

    @Test("구조화 출력을 스키마로 요구한다 — 산문이 오면 라우팅이 틀린 것이다")
    func requiresStructuredOutput() {
        let completion = LessonGenerator.makeRequest(for: request())
        guard case .jsonSchema(let name, _, let strict) = completion.responseFormat else {
            Issue.record("구조화 출력이 아니다")
            return
        }
        #expect(name == "lesson_content")
        #expect(strict)
    }

    @Test("시스템 프롬프트는 레슨·언어와 무관하게 바이트가 같다 — 캐시 접두사의 전제")
    func stableSystemPrefix() {
        let python = LessonGenerator.makeRequest(for: request(slug: "a"))
        var swiftRequest = request(slug: "b")
        swiftRequest.language = .swift
        let swift = LessonGenerator.makeRequest(for: swiftRequest)

        #expect(python.system.count == 1)
        #expect(python.system == swift.system)
        #expect(python.system[0].cacheHint != nil)
        #expect(python.messages != swift.messages)
    }

    @Test("시스템 프롬프트에 시각·실행 id 처럼 매번 달라지는 것이 없다")
    func systemPromptHasNoVariables() {
        let first = LessonPrompt.system
        let second = LessonPrompt.system
        #expect(first == second)
        #expect(!first.contains("2026"))
        // 언어별 계약이 셋 다 들어 있어야 트랙이 바뀌어도 접두사가 그대로다.
        for language in LessonLanguage.allCases {
            #expect(first.contains("## \(language.rawValue)"))
        }
    }

    @Test("사용자 메시지에 개요의 제목·목표·앞선 레슨이 실린다")
    func userMessageCarriesOutline() {
        var lessonRequest = request()
        lessonRequest.precedingTitles = ["앞 레슨"]
        let text = LessonGenerator.makeRequest(for: lessonRequest).messages[0].text
        #expect(text.contains("f-string 으로 문자열 만들기"))
        #expect(text.contains("앞 레슨"))
        #expect(text.contains("python"))
    }

    @Test("출력이 잘리면 조용히 넘기지 않고 던진다")
    func rejectsTruncated() {
        let response = CompletionResponse(
            id: "x", model: "m", text: "{", finishReason: .length,
            usage: TokenUsage(outputTokens: 24000))
        #expect(throws: LessonGenerationError.self) {
            try LessonGenerator.decodeDraft(from: response)
        }
    }

    @Test("스키마와 다른 JSON 은 던진다")
    func rejectsUndecodable() {
        #expect(throws: LessonGenerationError.self) {
            try LessonGenerator.decodeDraft(from: LessonFixtures.response(text: "{\"a\":1}"))
        }
    }

    @Test("왕복 한 번으로 레슨이 조립된다 — 실제로 답한 모델이 기록된다")
    func generatesFromProvider() async throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let provider = FakeProvider(
            capabilities: [.structuredOutputs, .usageTokens],
            steps: [.success(LessonFixtures.response(text: LessonFixtures.draftJSON()))])
        let log = try LessonFixtures.runLog(directory: directory)
        let generator = LessonGenerator(client: MeteredClient(provider: provider, log: log))

        let lesson = try await generator.generate(request())
        #expect(lesson.stableID == LessonID("python-fstring"))
        #expect(lesson.generatorModel == "z-ai/glm-5.3-flash")
        #expect(lesson.upstreamProvider == "TestUpstream")
        #expect(lesson.markdown.contains("@Concept(id: fstring-basics)"))
    }

    @Test("직렬화가 거부하면 사유를 붙여 다시 묻고, 그때도 접두사는 그대로다")
    func retriesWithFeedback() async throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        var broken = LessonFixtures.draft()
        broken.concept.prose = "설명.\n\n}\n\n계속."
        let provider = FakeProvider(
            capabilities: [.structuredOutputs, .usageTokens],
            steps: [
                .success(LessonFixtures.response(text: LessonFixtures.draftJSON(broken))),
                .success(LessonFixtures.response(text: LessonFixtures.draftJSON())),
            ])
        let log = try LessonFixtures.runLog(directory: directory)
        let generator = LessonGenerator(client: MeteredClient(provider: provider, log: log))

        let lesson = try await generator.generate(request())
        #expect(lesson.markdown.contains("@Reflection"))

        let requests = provider.requests
        #expect(requests.count == 2)
        // 재요청도 같은 시스템 접두사를 쓴다. 대화만 길어진다.
        #expect(requests[0].system == requests[1].system)
        #expect(requests[1].messages.count == 3)
        #expect(requests[1].messages[2].text.contains("`}` 로 시작"))
    }

    @Test("재시도를 다 써도 안 되면 마지막 사유를 들고 던진다")
    func givesUpAfterRetries() async throws {
        let directory = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        var broken = LessonFixtures.draft()
        broken.quiz.answerChoiceID = "nope"
        let provider = FakeProvider(
            capabilities: [.structuredOutputs, .usageTokens],
            alwaysReturning: LessonFixtures.draftJSON(broken))
        let log = try LessonFixtures.runLog(directory: directory)
        let generator = LessonGenerator(client: MeteredClient(provider: provider, log: log))

        var lessonRequest = request()
        lessonRequest.serializationRetries = 1
        await #expect(throws: LessonGenerationError.self) {
            try await generator.generate(lessonRequest)
        }
        #expect(provider.requests.count == 2)
    }
}
