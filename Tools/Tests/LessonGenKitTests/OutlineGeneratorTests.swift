import Foundation
import LearnCore
import LessonGenKit
import LLMKit
import TestSupport
import Testing

@Suite("개요 생성 — 요청 조립과 왕복")
struct OutlineGeneratorTests {
    /// 이 스위트는 HTTP 를 세우지 않는다. 공급자 추상화가 값을 하는 지점이 여기다 —
    /// 도메인 로직은 전선을 몰라도 전량 검증된다.
    private func makeProvider(_ steps: [FakeProvider.Step]) -> FakeProvider {
        FakeProvider(steps: steps)
    }

    private func success(_ text: String, finishReason: FinishReason = .stop) -> FakeProvider.Step {
        .success(
            CompletionResponse(
                id: "gen-1",
                model: "vendor/actual-model",
                upstreamProvider: "TestUpstream",
                text: text,
                finishReason: finishReason,
                usage: TokenUsage(inputTokens: 100, outputTokens: 567)
            )
        )
    }

    @Test("요청이 구조화 출력 1회 호출로 조립된다")
    func requestShape() {
        let request = OutlineGenerator.makeRequest(
            for: .init(language: .python, lessonCount: 24, effort: .high, maxTokens: 16000)
        )
        #expect(request.maxOutputTokens == 16000)
        #expect(request.messages.count == 1)
        #expect(request.reasoningEffort == .high)
        guard case .jsonSchema(let name, let schema, let strict) = request.responseFormat else {
            Issue.record("구조화 출력이 아닙니다: \(request.responseFormat)")
            return
        }
        #expect(name == "track_outline")
        #expect(schema == OutlineDraft.jsonSchema)
        #expect(strict)
    }

    @Test("모델은 요청이 아니라 공급자가 정한다 — 단계별 오버라이드가 살아 있게")
    func requestCarriesNoModel() {
        // 요청 타입에 모델이 없다는 것이 이 설계의 요점이다. 어느 모델을 쓸지는
        // ModelSelection 이 정하고 공급자가 들고 있다.
        let python = OutlineGenerator.makeRequest(for: .init(language: .python))
        let swift = OutlineGenerator.makeRequest(for: .init(language: .swift))
        #expect(python.system == swift.system)
        #expect(OutlineGenerator.stage == .outline)
    }

    @Test("시스템 프롬프트에 캐시 경계가 걸리고 가변부는 사용자 메시지에만 있다")
    func cacheBoundary() {
        let python = OutlineGenerator.makeRequest(for: .init(language: .python, lessonCount: 24))
        let swift = OutlineGenerator.makeRequest(for: .init(language: .swift, lessonCount: 18))

        #expect(python.system.count == 1)
        #expect(python.system[0].cacheHint != nil)
        // 트랙이 달라도 캐시 접두사는 바이트 단위로 같아야 한다.
        #expect(python.system == swift.system)
        #expect(python.messages != swift.messages)

        let systemText = python.system[0].text
        #expect(systemText.contains("6블록"))
        #expect(!systemText.contains("python"))
        #expect(!systemText.contains("24"))

        let userText = python.messages[0].text
        #expect(userText.contains("python"))
        #expect(userText.contains("24"))
    }

    @Test("추가 요구사항은 사용자 메시지에만 붙는다")
    func notesGoToUserMessage() {
        let request = OutlineGenerator.makeRequest(
            for: .init(language: .sql, lessonCount: 22, notes: "SQLite 방언만 쓴다.")
        )
        #expect(request.messages[0].text.contains("SQLite 방언만 쓴다."))
        #expect(request.system[0].text.contains("SQLite") == false)
    }

    @Test("왕복 1회로 개요가 나온다")
    func generatesOutline() async throws {
        let provider = makeProvider([success(Fixtures.outlineDraftJSON)])
        let outline = try await OutlineGenerator(provider: provider)
            .generate(.init(language: .python, lessonCount: 2))

        #expect(provider.requests.count == 1)
        #expect(outline.lessons.count == 2)
        #expect(outline.lessons[0].stableID == LessonID("python.hello-stdout"))
        #expect(outline.trackTitle == "파이썬 입문")
        #expect(OutlineValidator.validate(outline).isEmpty)
    }

    /// 라우터가 갈아탈 수 있으므로 요청한 모델이 아니라 답한 모델을 남겨야 한다 —
    /// 아니면 재현 기록이 거짓이 된다 (`{#lessongen-runlog}`).
    @Test("생성 모델로 요청값이 아니라 실제로 답한 모델을 남긴다")
    func recordsTheModelThatActuallyAnswered() async throws {
        let provider = makeProvider([success(Fixtures.outlineDraftJSON)])
        let outline = try await OutlineGenerator(provider: provider)
            .generate(.init(language: .python, lessonCount: 2))
        #expect(outline.generatorModel == "vendor/actual-model")
        #expect(outline.generatorModel != provider.identity.model.rawValue)
    }

    @Test("max_tokens 에 걸려 잘리면 무엇을 바꿔야 하는지 말해 준다")
    func truncatedOutput() throws {
        let response = CompletionResponse(
            id: "gen-1",
            model: "m",
            text: "{\"trackTitle\":\"잘",
            finishReason: .length,
            usage: TokenUsage(outputTokens: 567)
        )
        #expect(throws: OutlineGenerationError.truncated(outputTokens: 567)) {
            try OutlineGenerator.decodeDraft(from: response)
        }
        let message = String(describing: OutlineGenerationError.truncated(outputTokens: 567))
        #expect(message.contains("--max-tokens"))
    }

    @Test("빈 응답은 파싱 실패가 아니라 빈 응답으로 보고한다")
    func emptyResponse() {
        let response = CompletionResponse(id: "g", model: "m", text: "   ", usage: .unknown)
        #expect(throws: OutlineGenerationError.emptyResponse) {
            try OutlineGenerator.decodeDraft(from: response)
        }
    }

    @Test("스키마와 어긋난 JSON 은 파일을 쓰기 전에 걸린다")
    func undecodableDraft() async throws {
        let provider = makeProvider([success("{\"trackTitle\":1}")])
        await #expect(throws: OutlineGenerationError.self) {
            try await OutlineGenerator(provider: provider).generate(.init(language: .python))
        }
    }

    @Test("검증에 걸리는 개요는 생성 단계에서 던진다")
    func invalidOutlineIsRejected() async throws {
        // 조립은 통과하지만 검증(추정 시간 범위)에 걸리는 초안.
        let draft = """
            {"trackTitle":"t","trackSummary":"s","lessons":[{"slug":"a","title":"제목",
            "summary":"요약","objectives":["할 수 있다."],"prerequisiteSlugs":[],
            "concepts":["c"],"estimatedMinutes":9999}]}
            """
        let provider = makeProvider([success(draft)])

        do {
            _ = try await OutlineGenerator(provider: provider).generate(.init(language: .python))
            Issue.record("던졌어야 합니다.")
        } catch let error as OutlineGenerationError {
            guard case .invalidOutline(let issues) = error else {
                Issue.record("invalidOutline 이 아닙니다: \(error)")
                return
            }
            #expect(issues.contains { $0.path == "lessons[0].estimatedMinutes" })
        }
    }

    @Test("구조화 출력을 못 하는 공급자에는 아예 보내지 않는다")
    func refusesProviderWithoutStructuredOutputs() async throws {
        let provider = FakeProvider(capabilities: [.usageTokens], alwaysReturning: Fixtures.outlineDraftJSON)
        await #expect(throws: LLMError.unsupported(.structuredOutputs)) {
            _ = try await OutlineGenerator(provider: provider).generate(.init(language: .python))
        }
    }

    @Test("공급자 오류는 그대로 올라온다 — 감싸서 원인을 흐리지 않는다")
    func providerErrorsPropagate() async throws {
        let provider = makeProvider([.failure(.insufficientCredits(.init(message: "크레딧 부족")))])
        await #expect(throws: LLMError.self) {
            _ = try await OutlineGenerator(provider: provider).generate(.init(language: .python))
        }
    }
}
