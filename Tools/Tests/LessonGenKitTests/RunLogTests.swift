import Foundation
import LearnCore
import LessonGenKit
import LLMKit
import Testing
import TestSupport

@Suite("실행 로그와 비용 가드")
struct RunLogTests {
    private func request() -> CompletionRequest {
        CompletionRequest(
            system: [PromptSegment(text: "고정 접두사", cacheHint: .default)],
            messages: [.user("무엇을 만들어라")],
            maxOutputTokens: 100,
            responseFormat: .jsonSchema(name: "lesson_content", schema: ["type": "object"]),
            sampling: SamplingParameters(temperature: 0, seed: 7),
            reasoningEffort: .high)
    }

    @Test("호출 하나가 파일 셋에 남는다 — 머리말·한 줄 요약·전문")
    func writesFiles() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        try await log.record(
            stage: .lesson,
            subject: "python-fstring",
            attempt: 1,
            requestedModel: ModelID("z-ai/glm-5.3-flash"),
            request: request(),
            response: LessonFixtures.response(text: "{}"),
            startedAt: Date(timeIntervalSince1970: 1_787_752_741),
            duration: .milliseconds(1200))
        _ = try await log.finish()

        let directory = log.directory
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("run.json").path))
        let jsonl = try String(
            contentsOf: directory.appendingPathComponent("calls.jsonl"), encoding: .utf8)
        #expect(jsonl.contains("\"upstreamProvider\":\"TestUpstream\""))
        #expect(jsonl.contains("\"respondedModel\":\"z-ai\\/glm-5.3-flash\"") || jsonl.contains("\"respondedModel\":\"z-ai/glm-5.3-flash\""))
        #expect(jsonl.contains("\"seed\":7"))
        let transcript = try String(
            contentsOf: directory.appendingPathComponent("calls/0001-lesson-python-fstring.json"),
            encoding: .utf8)
        #expect(transcript.contains("고정 접두사"))
    }

    @Test("단계별로 어떤 모델이 쓰였는지 전부 남는다")
    func recordsStageModels() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try RunLog(
            rootDirectory: root,
            runID: "run",
            command: "lesson",
            startedAt: Date(timeIntervalSince1970: 0),
            models: ModelSelection(
                base: ModelID("cheap/model"), overrides: [.prose: ModelID("good/model")]),
            sessionID: "s",
            budgetUSD: nil)
        let manifest = try await log.finish()
        #expect(manifest.stageModels["lesson"] == "cheap/model")
        #expect(manifest.stageModels["prose"] == "good/model")
        #expect(manifest.stageModels["repair"] == "cheap/model")
        #expect(manifest.sessionID == "s")
    }

    @Test("예산을 넘으면 다음 호출을 시작하지 않는다")
    func budgetStopsNextCall() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root, budgetUSD: 0.001)
        try await log.ensureBudget()
        try await log.record(
            stage: .lesson,
            subject: "a",
            attempt: 1,
            requestedModel: ModelID("m"),
            request: request(),
            response: LessonFixtures.response(text: "{}", cost: 0.002),
            startedAt: Date(),
            duration: .seconds(1))
        await #expect(throws: RunLogError.self) { try await log.ensureBudget() }
    }

    @Test("비용을 모르는 호출은 합계에 섞지 않고 따로 센다 — 0 으로 위장하면 합계가 거짓이 된다")
    func unknownCostIsCounted() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        try await log.record(
            stage: .lesson, subject: "a", attempt: 1, requestedModel: ModelID("m"),
            request: request(),
            response: LessonFixtures.response(text: "{}", cost: nil),
            startedAt: Date(), duration: .seconds(1))
        let manifest = try await log.finish()
        #expect(manifest.callsWithUnknownCost == 1)
        #expect(manifest.spentUSD == 0)
        #expect(manifest.summaryText.contains("하한값"))
    }

    @Test("캐시 읽기 토큰이 결산에 잡힌다 — 적중 여부를 여기서 확인한다")
    func cacheHitShowsUp() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        for index in 1...2 {
            try await log.record(
                stage: .lesson, subject: "lesson-\(index)", attempt: 1,
                requestedModel: ModelID("m"), request: request(),
                response: LessonFixtures.response(
                    text: "{}", cachedTokens: index == 1 ? 0 : 900),
                startedAt: Date(), duration: .seconds(1))
        }
        let manifest = try await log.finish()
        #expect(manifest.cachedInputTokens == 900)
        #expect(manifest.summaryText.contains("캐시 적중"))
        #expect(!manifest.summaryText.contains("적중 없음"))
    }

    @Test("캐시가 한 번도 안 붙으면 결산이 그렇게 말한다")
    func coldCacheIsReported() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        for index in 1...2 {
            try await log.record(
                stage: .lesson, subject: "lesson-\(index)", attempt: 1,
                requestedModel: ModelID("m"), request: request(),
                response: LessonFixtures.response(text: "{}", cachedTokens: 0),
                startedAt: Date(), duration: .seconds(1))
        }
        let manifest = try await log.finish()
        #expect(manifest.summaryText.contains("session_id"))
    }

    @Test("업스트림이 갈리면 결산이 경고한다 — 진짜 변수는 시드가 아니다")
    func splitUpstreamIsReported() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        for upstream in ["Alpha", "Beta"] {
            try await log.record(
                stage: .lesson, subject: upstream, attempt: 1, requestedModel: ModelID("m"),
                request: request(),
                response: LessonFixtures.response(text: "{}", upstream: upstream),
                startedAt: Date(), duration: .seconds(1))
        }
        let manifest = try await log.finish()
        #expect(manifest.upstreamProviders == ["Alpha", "Beta"])
        #expect(manifest.summaryText.contains("갈렸다"))
    }

    /// 고정을 요청해 놓고 다른 곳이 답하면, 그 실행의 캐시 결과는 아무것도 증명하지
    /// 못한다. 조용히 넘어가면 "고정했는데도 캐시가 안 붙네" 라는 잘못된 결론에 이른다.
    @Test("업스트림 고정이 새면 결산이 그렇게 말한다")
    func strayedPinIsReported() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root, pinnedProviders: ["Alpha"])
        for upstream in ["Alpha", "Reka"] {
            try await log.record(
                stage: .lesson, subject: upstream, attempt: 1, requestedModel: ModelID("m"),
                request: request(),
                response: LessonFixtures.response(text: "{}", upstream: upstream),
                startedAt: Date(), duration: .seconds(1))
        }
        let manifest = try await log.finish()
        #expect(manifest.pinnedProviders == ["Alpha"])
        #expect(manifest.summaryText.contains("고정이 새었다"))
        #expect(manifest.summaryText.contains("Reka"))
    }

    @Test("고정이 지켜지면 결산이 그것도 말한다")
    func honoredPinIsReported() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root, pinnedProviders: ["Alpha"])
        for index in 1...2 {
            try await log.record(
                stage: .lesson, subject: "lesson-\(index)", attempt: 1,
                requestedModel: ModelID("m"), request: request(),
                response: LessonFixtures.response(text: "{}", upstream: "Alpha"),
                startedAt: Date(), duration: .seconds(1))
        }
        let manifest = try await log.finish()
        #expect(manifest.summaryText.contains("고정 지켜짐"))
        // 고정했는데도 캐시가 차가우면 원인은 라우팅이 아니라 접두사다 — 진단이 갈려야 한다.
        #expect(manifest.summaryText.contains("접두사 안정성"))
    }

    @Test("고정 없이 돈 실행은 캐시 미적중의 원인으로 라우팅을 먼저 지목한다")
    func unpinnedColdCacheBlamesRouting() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        for index in 1...2 {
            try await log.record(
                stage: .lesson, subject: "lesson-\(index)", attempt: 1,
                requestedModel: ModelID("m"), request: request(),
                response: LessonFixtures.response(text: "{}", cachedTokens: 0),
                startedAt: Date(), duration: .seconds(1))
        }
        let manifest = try await log.finish()
        #expect(manifest.summaryText.contains("--provider"))
    }

    @Test("실패한 호출도 남는다 — 빠지면 재시도 횟수가 어긋난다")
    func recordsFailures() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        try await log.recordFailure(
            stage: .repair, subject: "a", attempt: 2, requestedModel: ModelID("m"),
            request: request(), error: "레이트 리밋", startedAt: Date(), duration: .seconds(1))
        let manifest = try await log.finish()
        #expect(manifest.calls == 1)
        #expect(manifest.failedCalls == 1)
    }

    @Test("실행 로그 전문에 API 키가 실릴 자리가 없다")
    func transcriptHasNoKeyShape() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root)
        try await log.record(
            stage: .lesson, subject: "a", attempt: 1, requestedModel: ModelID("m"),
            request: request(), response: LessonFixtures.response(text: "{}"),
            startedAt: Date(), duration: .seconds(1))
        _ = try await log.finish()

        let contents = try FileManager.default.subpathsOfDirectory(atPath: log.directory.path)
        for path in contents {
            let url = log.directory.appendingPathComponent(path)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            #expect(!text.contains("sk-or-v1-"))
            #expect(!text.lowercased().contains("authorization"))
        }
    }

    @Test("MeteredClient 가 예산을 먼저 보고 호출한다")
    func clientChecksBudgetFirst() async throws {
        let root = try LessonFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = try LessonFixtures.runLog(directory: root, budgetUSD: 0.0001)
        let provider = FakeProvider(
            capabilities: [.structuredOutputs, .usageTokens],
            steps: [
                .success(LessonFixtures.response(text: "{}", cost: 0.001)),
                .success(LessonFixtures.response(text: "{}", cost: 0.001)),
            ])
        let client = MeteredClient(provider: provider, log: log)

        _ = try await client.complete(request(), stage: .lesson, subject: "a", attempt: 1)
        await #expect(throws: RunLogError.self) {
            _ = try await client.complete(request(), stage: .lesson, subject: "b", attempt: 1)
        }
        #expect(provider.requests.count == 1, "예산을 넘긴 뒤에도 요청이 나갔다")
    }
}
