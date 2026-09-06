import Foundation
import LearnCore
public import LLMKit

/// 레슨 한 편을 만든다.
///
/// 왕복은 ``MeteredClient`` 에 맡기고, 여기서는 요청 조립과 응답 해석과 **직렬화
/// 재시도**만 한다. 요청 조립(``makeRequest(for:)``)은 순수 함수라 키 없이 검증된다.
///
/// 직렬화 실패는 네트워크 실패와 다르게 다룬다. 429 는 같은 요청을 다시 걸면 되지만
/// "산문에 `}` 로 시작하는 줄이 있다" 는 같은 요청을 다시 걸어도 같은 결과가 온다.
/// 그래서 **거부 사유를 대화에 붙여** 다시 묻는다 — 시스템 접두사가 그대로라 캐시도
/// 살아 있다.
public struct LessonGenerator: Sendable {
    public struct Request: Sendable {
        public var outline: LessonOutline
        public var language: LessonLanguage
        public var trackTitle: String
        /// 앞선 레슨 제목들. 모델이 무엇을 전제해도 되는지 알려 준다.
        public var precedingTitles: [String]
        public var notes: String?
        public var effort: ReasoningEffort?
        public var maxTokens: Int
        public var sampling: SamplingParameters?
        /// 직렬화가 거부했을 때 다시 물어볼 횟수. 0 이면 한 번만 시도한다.
        public var serializationRetries: Int

        public init(
            outline: LessonOutline,
            language: LessonLanguage,
            trackTitle: String,
            precedingTitles: [String] = [],
            notes: String? = nil,
            effort: ReasoningEffort? = .high,
            maxTokens: Int = 24000,
            sampling: SamplingParameters? = nil,
            serializationRetries: Int = 1
        ) {
            self.outline = outline
            self.language = language
            self.trackTitle = trackTitle
            self.precedingTitles = precedingTitles
            self.notes = notes
            self.effort = effort
            self.maxTokens = maxTokens
            self.sampling = sampling
            self.serializationRetries = serializationRetries
        }
    }

    public static let stage: GenerationStage = .lesson

    private let client: MeteredClient

    public init(client: MeteredClient) {
        self.client = client
    }

    /// 보낼 요청. 순수 함수.
    ///
    /// - Parameter followUps: 직렬화 거부 뒤 이어 붙일 (모델 답변, 재요청) 쌍.
    public static func makeRequest(
        for request: Request,
        followUps: [(assistant: String, user: String)] = []
    ) -> CompletionRequest {
        var messages: [ChatMessage] = [
            .user(
                LessonPrompt.user(
                    outline: request.outline,
                    language: request.language,
                    trackTitle: request.trackTitle,
                    precedingTitles: request.precedingTitles,
                    notes: request.notes))
        ]
        for followUp in followUps {
            messages.append(ChatMessage(role: .assistant, text: followUp.assistant))
            messages.append(.user(followUp.user))
        }
        return CompletionRequest(
            // 안정 접두사. 트랙·레슨과 무관하게 바이트가 같아야 캐시가 붙는다.
            system: [PromptSegment(text: LessonPrompt.system, cacheHint: .default)],
            messages: messages,
            maxOutputTokens: request.maxTokens,
            responseFormat: .jsonSchema(name: "lesson_content", schema: LessonContentDraft.jsonSchema),
            sampling: request.sampling,
            reasoningEffort: request.effort)
    }

    /// 응답 본문에서 초안을 꺼낸다. 순수 함수.
    ///
    /// 본문을 통째로 디코딩하지 않고 **균형 잡힌 첫 JSON 객체**만 도려낸다. 이유는
    /// ``JSONExtraction`` 주석에 있다 — 스키마를 만족하는 객체 뒤에 중괄호 하나가 더
    /// 붙어 오는 것을 실측했고, 그것 때문에 멀쩡한 응답을 버릴 이유가 없다.
    public static func decodeDraft(from response: CompletionResponse) throws(LessonGenerationError)
        -> LessonContentDraft
    {
        if response.finishReason == .length {
            throw .truncated(outputTokens: response.usage.outputTokens)
        }
        let text = response.text.trimmedOuterWhitespace()
        guard !text.isEmpty else { throw .emptyResponse }
        guard let object = JSONExtraction.balancedObject(in: text) else {
            throw .undecodableDraft("응답에서 JSON 객체를 찾지 못했습니다.")
        }
        do {
            return try JSONDecoder().decode(LessonContentDraft.self, from: Data(object.utf8))
        } catch {
            throw .undecodableDraft(String(describing: error))
        }
    }

    /// 왕복 → 초안 → 직렬화 → 왕복 검사. 실패하면 사유를 붙여 다시 묻는다.
    public func generate(_ request: Request) async throws -> GeneratedLesson {
        try await DraftLoop.run(
            client: client,
            stage: Self.stage,
            subject: PackLessonID.fromOutline(request.outline.stableID).rawValue,
            retries: request.serializationRetries,
            makeRequest: { followUps in Self.makeRequest(for: request, followUps: followUps) },
            assemble: { draft, completion in
                try LessonAssembler.assemble(
                    draft: draft,
                    outline: request.outline,
                    language: request.language,
                    generatorModel: completion.model,
                    upstreamProvider: completion.upstreamProvider)
            })
    }
}

public enum LessonGenerationError: Error, Sendable, CustomStringConvertible {
    case truncated(outputTokens: Int?)
    case emptyResponse
    case undecodableDraft(String)
    case serializationFailed(attempts: Int, last: LessonSerializationError)

    public var description: String {
        switch self {
        case .truncated(let outputTokens):
            let tokens = outputTokens.map { " (출력 \($0) 토큰)" } ?? ""
            return "출력이 max_tokens 에 걸려 잘렸습니다\(tokens). --max-tokens 를 올리십시오."
        case .emptyResponse:
            return "응답에 텍스트가 없습니다."
        case .undecodableDraft(let detail):
            return "구조화 출력이 스키마와 맞지 않습니다 — \(detail)"
        case .serializationFailed(let attempts, let last):
            return "레슨을 \(attempts)번 시도했지만 문법 검사를 통과하지 못했습니다 — \(last)"
        }
    }
}
