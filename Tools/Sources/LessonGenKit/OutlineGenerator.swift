import Foundation
public import LearnCore
public import LLMKit

/// 한 트랙의 개요를 구조화 출력 **한 번**으로 뽑는다.
///
/// 왕복은 ``LLMProvider`` 에 맡기고, 여기서는 요청 조립과 응답 해석만 한다. 요청
/// 조립(``makeRequest(for:)``)은 순수 함수라 키 없이, 공급자 없이 검증된다.
///
/// 공급자를 프로토콜로 받는 것이 요점이다 — OpenRouter 든 나중의 로컬 MLX 든 이 타입은
/// 바뀌지 않는다.
public struct OutlineGenerator: Sendable {
    public struct Request: Sendable, Hashable {
        public var language: LanguageID
        public var lessonCount: Int
        public var notes: String?
        public var effort: ReasoningEffort?
        public var maxTokens: Int
        /// 재현을 노릴 때 넣는다. `nil` 이면 공급자 기본 샘플링.
        public var sampling: SamplingParameters?

        public init(
            language: LanguageID,
            lessonCount: Int = 24,
            notes: String? = nil,
            effort: ReasoningEffort? = .high,
            maxTokens: Int = 16000,
            sampling: SamplingParameters? = nil
        ) {
            self.language = language
            self.lessonCount = lessonCount
            self.notes = notes
            self.effort = effort
            self.maxTokens = maxTokens
            self.sampling = sampling
        }
    }

    /// 이 생성기가 속한 파이프라인 단계. 모델 선택과 실행 로그가 읽는다.
    public static let stage: GenerationStage = .outline

    private let provider: any LLMProvider

    public init(provider: any LLMProvider) {
        self.provider = provider
    }

    /// 보낼 요청. 순수 함수.
    public static func makeRequest(for request: Request) -> CompletionRequest {
        CompletionRequest(
            // 시스템 프롬프트는 트랙과 무관하게 고정이라 여기에 캐시 경계를 건다.
            // 트랙 10개를 연달아 돌리면 2번째부터 캐시 읽기가 잡혀야 한다.
            system: [PromptSegment(text: OutlinePrompt.system, cacheHint: .default)],
            messages: [
                .user(
                    OutlinePrompt.user(
                        language: request.language,
                        lessonCount: request.lessonCount,
                        notes: request.notes
                    )
                )
            ],
            maxOutputTokens: request.maxTokens,
            responseFormat: .jsonSchema(name: "track_outline", schema: OutlineDraft.jsonSchema),
            sampling: request.sampling,
            reasoningEffort: request.effort
        )
    }

    /// 응답 본문에서 초안을 꺼낸다. 순수 함수.
    public static func decodeDraft(from response: CompletionResponse) throws(OutlineGenerationError) -> OutlineDraft {
        if response.finishReason == .length {
            throw .truncated(outputTokens: response.usage.outputTokens)
        }
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw .emptyResponse }
        do {
            return try JSONDecoder().decode(OutlineDraft.self, from: Data(text.utf8))
        } catch {
            throw .undecodableDraft(String(describing: error))
        }
    }

    /// 왕복 1회 → 초안 → 조립 → 검증. 검증에 걸리면 파일을 쓰기 전에 던진다.
    public func generate(_ request: Request) async throws -> TrackOutline {
        let response = try await provider.complete(Self.makeRequest(for: request))
        let draft = try Self.decodeDraft(from: response)
        let outline = try OutlineAssembler.assemble(
            draft: draft,
            language: request.language,
            // 요청한 모델이 아니라 **실제로 답한 모델**을 남긴다 — 라우터가 갈아탈 수
            // 있으므로 요청값을 적으면 재현 기록이 거짓이 된다.
            generatorModel: response.model
        )
        let issues = OutlineValidator.validate(outline)
        guard issues.isEmpty else { throw OutlineGenerationError.invalidOutline(issues) }
        return outline
    }
}

public enum OutlineGenerationError: Error, Sendable, Hashable {
    /// 출력 상한에 걸려 JSON 이 잘렸다.
    case truncated(outputTokens: Int?)
    case emptyResponse
    case undecodableDraft(String)
    case invalidOutline([OutlineIssue])
}

extension OutlineGenerationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .truncated(let outputTokens):
            let tokens = outputTokens.map { " (출력 \($0) 토큰)" } ?? ""
            return "출력이 max_tokens 에 걸려 잘렸습니다\(tokens). --max-tokens 를 올리거나 --lessons 를 줄이십시오."
        case .emptyResponse:
            return "응답에 텍스트가 없습니다."
        case .undecodableDraft(let detail):
            return "구조화 출력이 스키마와 맞지 않습니다 — \(detail)"
        case .invalidOutline(let issues):
            return "개요 검증 실패 (\(issues.count)건)\n" + issues.map { "  - \($0)" }.joined(separator: "\n")
        }
    }
}
