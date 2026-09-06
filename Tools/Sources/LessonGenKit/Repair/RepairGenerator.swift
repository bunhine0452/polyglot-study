public import LLMKit
public import PackReport

/// 실패한 레슨 하나를 다시 만든다.
///
/// 생성기와 같은 루프를 쓰고 프롬프트만 다르다. 시스템 프롬프트의 **첫 조각이 생성과
/// 완전히 같다** — 캐시는 접두사 일치라서, 수리가 자기만의 시스템 프롬프트를 쓰면
/// 생성에서 데워 둔 것을 통째로 버리게 된다. 수리 전용 지시는 두 번째 조각으로 뒤에
/// 붙는다.
public struct RepairGenerator: Sendable {
    public struct Request: Sendable {
        public var lesson: PackValidationReport.LessonResult
        public var current: LessonDraftReader.ReadLesson
        public var effort: ReasoningEffort?
        public var maxTokens: Int
        public var sampling: SamplingParameters?
        public var serializationRetries: Int

        public init(
            lesson: PackValidationReport.LessonResult,
            current: LessonDraftReader.ReadLesson,
            effort: ReasoningEffort? = .high,
            maxTokens: Int = 24000,
            sampling: SamplingParameters? = nil,
            serializationRetries: Int = 1
        ) {
            self.lesson = lesson
            self.current = current
            self.effort = effort
            self.maxTokens = maxTokens
            self.sampling = sampling
            self.serializationRetries = serializationRetries
        }
    }

    public static let stage: GenerationStage = .repair

    private let client: MeteredClient

    public init(client: MeteredClient) {
        self.client = client
    }

    /// 보낼 요청. 순수 함수 — 키도 네트워크도 없이 검증된다.
    public static func makeRequest(
        for request: Request,
        currentDraftJSON: String,
        followUps: [(assistant: String, user: String)] = []
    ) -> CompletionRequest {
        var messages: [ChatMessage] = [
            .user(
                RepairPrompt.user(
                    lesson: request.lesson,
                    currentDraftJSON: currentDraftJSON,
                    language: request.current.language))
        ]
        for followUp in followUps {
            messages.append(ChatMessage(role: .assistant, text: followUp.assistant))
            messages.append(.user(followUp.user))
        }
        return CompletionRequest(
            system: [
                // 첫 조각은 생성과 바이트가 같다. 이 순서를 바꾸면 캐시가 죽는다.
                PromptSegment(text: LessonPrompt.system, cacheHint: .default),
                PromptSegment(text: RepairPrompt.systemSuffix),
            ],
            messages: messages,
            maxOutputTokens: request.maxTokens,
            responseFormat: .jsonSchema(
                name: "lesson_content", schema: LessonContentDraft.jsonSchema),
            sampling: request.sampling,
            reasoningEffort: request.effort)
    }

    public func repair(_ request: Request) async throws -> GeneratedLesson {
        let currentJSON = try LessonDraftReader.json(request.current.draft)
        return try await DraftLoop.run(
            client: client,
            stage: Self.stage,
            subject: request.lesson.stableID,
            retries: request.serializationRetries,
            makeRequest: { followUps in
                Self.makeRequest(
                    for: request, currentDraftJSON: currentJSON, followUps: followUps)
            },
            assemble: { draft, completion in
                try LessonAssembler.assemble(
                    draft: draft,
                    outline: request.current.outline,
                    language: request.current.language,
                    generatorModel: completion.model,
                    upstreamProvider: completion.upstreamProvider)
            })
    }
}
