import AnthropicKit
import Foundation
import LearnCore
import LessonGenKit
import TestSupport
import Testing

@Suite("개요 생성 — 요청 조립과 왕복")
struct OutlineGeneratorTests {
    private func makeClient(
        _ steps: [StubTransport.Step],
        log: any ClientLogSink = DiscardLog()
    ) throws -> (AnthropicClient, StubTransport) {
        let transport = StubTransport(steps)
        let client = try AnthropicClient(
            apiKey: APIKey(rawValue: Fixtures.fakeAPIKeyString),
            configuration: .init(retry: RetryPolicy(maxAttempts: 2, baseDelay: .milliseconds(1), jitterFraction: 0)),
            transport: transport,
            sleeper: RecordingSleeper(),
            log: log
        )
        return (client, transport)
    }

    @Test("요청이 구조화 출력 1회 호출로 조립된다")
    func requestShape() {
        let request = OutlineGenerator.makeRequest(
            for: .init(language: .python, lessonCount: 24, model: .opus5, effort: .high, maxTokens: 16000)
        )
        #expect(request.model == .opus5)
        #expect(request.maxTokens == 16000)
        #expect(request.messages.count == 1)
        #expect(request.outputConfig?.effort == .high)
        #expect(request.outputConfig?.format?.schema == OutlineDraft.jsonSchema)
        // Opus 5 는 사고가 기본으로 켜져 있고 budget_tokens 는 400 이다 — adaptive 만 쓴다.
        #expect(request.thinking?.type == .adaptive)
    }

    @Test("시스템 프롬프트에 캐시 경계가 걸리고 가변부는 사용자 메시지에만 있다")
    func cacheBoundary() {
        let python = OutlineGenerator.makeRequest(for: .init(language: .python, lessonCount: 24))
        let swift = OutlineGenerator.makeRequest(for: .init(language: .swift, lessonCount: 18))

        #expect(python.system?.count == 1)
        #expect(python.system?[0].cacheControl != nil)
        // 트랙이 달라도 캐시 접두사는 바이트 단위로 같아야 한다.
        #expect(python.system == swift.system)
        #expect(python.messages != swift.messages)

        let systemText = python.system?[0].text ?? ""
        #expect(systemText.contains("6블록"))
        #expect(!systemText.contains("python"))
        #expect(!systemText.contains("24"))

        let userText = python.messages[0].content[0].text
        #expect(userText.contains("python"))
        #expect(userText.contains("24"))
    }

    @Test("추가 요구사항은 사용자 메시지에만 붙는다")
    func notesGoToUserMessage() {
        let request = OutlineGenerator.makeRequest(
            for: .init(language: .sql, lessonCount: 22, notes: "SQLite 방언만 쓴다.")
        )
        #expect(request.messages[0].content[0].text.contains("SQLite 방언만 쓴다."))
        #expect(request.system?[0].text.contains("SQLite") == false)
    }

    @Test("왕복 1회로 개요가 나온다")
    func generatesOutline() async throws {
        let (client, transport) = try makeClient([
            .response(
                HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: Fixtures.outlineDraftJSON))
            )
        ])
        let outline = try await OutlineGenerator(client: client)
            .generate(.init(language: .python, lessonCount: 2))

        #expect(transport.requests.count == 1)
        #expect(outline.lessons.count == 2)
        #expect(outline.lessons[0].stableID == LessonID("python.hello-stdout"))
        #expect(outline.trackTitle == "파이썬 입문")
        #expect(OutlineValidator.validate(outline).isEmpty)
    }

    @Test("max_tokens 에 걸려 잘리면 무엇을 바꿔야 하는지 말해 준다")
    func truncatedOutput() throws {
        let response = try ResponseParser.parse(
            status: 200,
            headers: [:],
            data: Fixtures.messagesResponseJSON(text: "{\"trackTitle\":\"잘", stopReason: "max_tokens")
        ).get()

        #expect(throws: OutlineGenerationError.truncated(outputTokens: 567)) {
            try OutlineGenerator.decodeDraft(from: response)
        }
        let message = String(describing: OutlineGenerationError.truncated(outputTokens: 567))
        #expect(message.contains("--max-tokens"))
    }

    @Test("스키마와 어긋난 JSON 은 파일을 쓰기 전에 걸린다")
    func undecodableDraft() async throws {
        let (client, _) = try makeClient([
            .response(HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: "{\"trackTitle\":1}")))
        ])
        await #expect(throws: OutlineGenerationError.self) {
            try await OutlineGenerator(client: client).generate(.init(language: .python))
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
        let (client, _) = try makeClient([
            .response(HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: draft)))
        ])

        do {
            _ = try await OutlineGenerator(client: client).generate(.init(language: .python))
            Issue.record("던졌어야 합니다.")
        } catch let error as OutlineGenerationError {
            guard case .invalidOutline(let issues) = error else {
                Issue.record("invalidOutline 이 아닙니다: \(error)")
                return
            }
            #expect(issues.contains { $0.path == "lessons[0].estimatedMinutes" })
        }
    }

    @Test("생성 경로의 로그에도 키가 0건이다")
    func generationLogsAreClean() async throws {
        let log = CapturingLog()
        let (client, _) = try makeClient(
            [
                .response(HTTPResponse(status: 529, body: Fixtures.errorJSON(type: "overloaded_error", message: "과부하"))),
                .response(HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: Fixtures.outlineDraftJSON))),
            ],
            log: log
        )
        _ = try await OutlineGenerator(client: client).generate(.init(language: .python, lessonCount: 2))

        #expect(!log.lines.isEmpty)
        for line in log.lines {
            #expect(!line.contains(Fixtures.fakeAPIKeyString))
            #expect(!line.contains("sk-ant-"))
        }
    }
}
