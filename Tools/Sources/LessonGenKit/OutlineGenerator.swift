public import AnthropicKit
import Foundation
public import LearnCore

/// 한 트랙의 개요를 구조화 출력 **한 번**으로 뽑는다.
///
/// 왕복은 ``AnthropicClient`` 에 맡기고, 여기서는 요청 조립과 응답 해석만 한다.
/// 요청 조립(``makeRequest(for:)``)은 순수 함수라 키 없이 검증된다.
public struct OutlineGenerator: Sendable {
    public struct Request: Sendable, Hashable {
        public var language: LanguageID
        public var lessonCount: Int
        public var notes: String?
        public var model: AnthropicModel
        public var effort: Effort
        public var maxTokens: Int

        public init(
            language: LanguageID,
            lessonCount: Int = 24,
            notes: String? = nil,
            model: AnthropicModel = .opus5,
            effort: Effort = .high,
            maxTokens: Int = 16000
        ) {
            self.language = language
            self.lessonCount = lessonCount
            self.notes = notes
            self.model = model
            self.effort = effort
            self.maxTokens = maxTokens
        }
    }

    private let client: AnthropicClient

    public init(client: AnthropicClient) {
        self.client = client
    }

    /// 보낼 Messages 요청. 순수 함수.
    public static func makeRequest(for request: Request) -> MessagesRequest {
        MessagesRequest(
            model: request.model,
            maxTokens: request.maxTokens,
            // 시스템 프롬프트는 트랙과 무관하게 고정이라 여기에 캐시 경계를 건다.
            // 트랙 10개를 연달아 돌리면 2번째부터 캐시 읽기가 잡혀야 한다.
            system: [SystemBlock(text: OutlinePrompt.system, cacheControl: CacheControl())],
            messages: [
                .user(
                    OutlinePrompt.user(
                        language: request.language,
                        lessonCount: request.lessonCount,
                        notes: request.notes
                    )
                )
            ],
            // Opus 5 는 사고가 기본으로 켜져 있다. 명시해 두어 의도를 남긴다.
            thinking: Thinking(type: .adaptive),
            outputConfig: OutputConfig(
                effort: request.effort,
                format: OutputFormat(schema: OutlineDraft.jsonSchema)
            )
        )
    }

    /// 응답 본문에서 초안을 꺼낸다. 순수 함수.
    public static func decodeDraft(from response: MessagesResponse) throws(OutlineGenerationError) -> OutlineDraft {
        if response.stopReason == .maxTokens {
            throw .truncated(outputTokens: response.usage.outputTokens)
        }
        let text = response.text
        guard !text.isEmpty else { throw .emptyResponse }
        do {
            return try JSONDecoder().decode(OutlineDraft.self, from: Data(text.utf8))
        } catch {
            throw .undecodableDraft(String(describing: error))
        }
    }

    /// 왕복 1회 → 초안 → 조립 → 검증. 검증에 걸리면 파일을 쓰기 전에 던진다.
    public func generate(_ request: Request) async throws -> TrackOutline {
        let response = try await client.send(Self.makeRequest(for: request))
        let draft = try Self.decodeDraft(from: response)
        let outline = try OutlineAssembler.assemble(
            draft: draft,
            language: request.language,
            generatorModel: request.model.rawValue
        )
        let issues = OutlineValidator.validate(outline)
        guard issues.isEmpty else { throw OutlineGenerationError.invalidOutline(issues) }
        return outline
    }
}

public enum OutlineGenerationError: Error, Sendable, Hashable {
    /// `max_tokens` 에 걸려 JSON 이 잘렸다.
    case truncated(outputTokens: Int)
    case emptyResponse
    case undecodableDraft(String)
    case invalidOutline([OutlineIssue])
}

extension OutlineGenerationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .truncated(let outputTokens):
            "출력이 max_tokens 에 걸려 잘렸습니다 (출력 \(outputTokens) 토큰). --max-tokens 를 올리거나 --lessons 를 줄이십시오."
        case .emptyResponse:
            "응답에 텍스트 블록이 없습니다."
        case .undecodableDraft(let detail):
            "구조화 출력이 스키마와 맞지 않습니다 — \(detail)"
        case .invalidOutline(let issues):
            "개요 검증 실패 (\(issues.count)건)\n" + issues.map { "  - \($0)" }.joined(separator: "\n")
        }
    }
}
