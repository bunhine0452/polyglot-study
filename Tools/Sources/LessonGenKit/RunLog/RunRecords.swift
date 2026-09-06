import Foundation
import LLMKit

/// 실행 로그에 남는 호출 한 건.
///
/// 무엇을 남기는가가 이 타입의 전부다. **요청한 모델이 아니라 답한 모델**, 그리고
/// ``upstreamProvider`` — 같은 모델 id 뒤에 업스트림이 스물 몇 곳 서 있고 양자화가
/// 갈리기 때문에(fp4/fp8), 재현이 어긋났을 때 진짜 변수는 시드가 아니라 여기다.
public struct CallRecord: Codable, Hashable, Sendable {
    public var sequence: Int
    /// `lesson`·`repair`·`outline`. 어느 단계가 어느 모델을 썼는지가 여기서 나온다.
    public var stage: String
    /// 무엇에 대한 호출인가. 보통 레슨 stableID.
    public var subject: String
    /// 같은 subject 에 대한 몇 번째 시도인가. 1부터.
    public var attempt: Int
    /// 요청에 실은 모델.
    public var requestedModel: String
    /// 응답이 자기라고 말한 모델.
    public var respondedModel: String?
    public var upstreamProvider: String?
    public var generationID: String?
    public var finishReason: String?
    public var temperature: Double?
    public var seed: Int?
    /// 캐시 친화 라우팅 키. 비밀이 아니다.
    public var sessionID: String?
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var reasoningTokens: Int?
    /// 캐시에서 읽은 입력 토큰. `{#lessongen-prompt-caching}` 의 검증 지점.
    public var cachedInputTokens: Int?
    public var costUSD: Double?
    public var startedAt: String
    public var durationMilliseconds: Int
    /// 실패했으면 정규화된 오류 문자열. 성공이면 nil.
    public var error: String?

    public init(
        sequence: Int,
        stage: String,
        subject: String,
        attempt: Int,
        requestedModel: String,
        respondedModel: String? = nil,
        upstreamProvider: String? = nil,
        generationID: String? = nil,
        finishReason: String? = nil,
        temperature: Double? = nil,
        seed: Int? = nil,
        sessionID: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        costUSD: Double? = nil,
        startedAt: String,
        durationMilliseconds: Int,
        error: String? = nil
    ) {
        self.sequence = sequence
        self.stage = stage
        self.subject = subject
        self.attempt = attempt
        self.requestedModel = requestedModel
        self.respondedModel = respondedModel
        self.upstreamProvider = upstreamProvider
        self.generationID = generationID
        self.finishReason = finishReason
        self.temperature = temperature
        self.seed = seed
        self.sessionID = sessionID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.cachedInputTokens = cachedInputTokens
        self.costUSD = costUSD
        self.startedAt = startedAt
        self.durationMilliseconds = durationMilliseconds
        self.error = error
    }
}

/// 실행 하나의 머리말과 결산. `run.json` 이 된다.
public struct RunManifest: Codable, Hashable, Sendable {
    public var runID: String
    public var startedAt: String
    public var finishedAt: String?
    public var command: String
    /// 단계 → 모델. **오버라이드가 없는 단계까지 전부** 적는다. 나중에 "이 레슨은 어느
    /// 모델이 썼나" 를 되짚을 때 기본값이 무엇이었는지도 필요하다.
    public var stageModels: [String: String]
    public var sessionID: String?
    public var budgetUSD: Double?
    public var calls: Int
    public var failedCalls: Int
    public var spentUSD: Double
    /// 비용을 알려 주지 않은 호출 수. 합계를 믿을 수 있는가의 척도다 — 0 이 아니면
    /// `spentUSD` 는 하한이지 총액이 아니다.
    public var callsWithUnknownCost: Int
    public var cachedInputTokens: Int
    public var inputTokens: Int
    public var outputTokens: Int
    /// 실제로 답한 업스트림들. 하나가 아니면 결과가 흔들릴 수 있다는 신호다.
    public var upstreamProviders: [String]
    public var respondedModels: [String]

    public init(
        runID: String,
        startedAt: String,
        finishedAt: String? = nil,
        command: String,
        stageModels: [String: String],
        sessionID: String?,
        budgetUSD: Double?,
        calls: Int = 0,
        failedCalls: Int = 0,
        spentUSD: Double = 0,
        callsWithUnknownCost: Int = 0,
        cachedInputTokens: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        upstreamProviders: [String] = [],
        respondedModels: [String] = []
    ) {
        self.runID = runID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.command = command
        self.stageModels = stageModels
        self.sessionID = sessionID
        self.budgetUSD = budgetUSD
        self.calls = calls
        self.failedCalls = failedCalls
        self.spentUSD = spentUSD
        self.callsWithUnknownCost = callsWithUnknownCost
        self.cachedInputTokens = cachedInputTokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.upstreamProviders = upstreamProviders
        self.respondedModels = respondedModels
    }

    /// 사람이 읽는 결산 한 문단.
    public var summaryText: String {
        var lines = [
            "실행 \(runID) — 호출 \(calls)건(실패 \(failedCalls)건)",
            String(format: "비용 $%.6f", spentUSD)
                + (callsWithUnknownCost > 0 ? " (비용 미상 \(callsWithUnknownCost)건 제외 — 하한값)" : ""),
            "토큰 in=\(inputTokens) out=\(outputTokens) cached=\(cachedInputTokens)",
        ]
        if cachedInputTokens > 0 {
            let ratio = inputTokens > 0 ? Double(cachedInputTokens) / Double(inputTokens) * 100 : 0
            lines.append(String(format: "프롬프트 캐시 적중 — 입력의 %.1f%% 가 캐시에서 왔다", ratio))
        } else if calls > 1 {
            lines.append("프롬프트 캐시 적중 없음 — session_id 라우팅과 접두사 안정성을 확인하라")
        }
        if upstreamProviders.count > 1 {
            lines.append("업스트림이 \(upstreamProviders.count)곳으로 갈렸다: \(upstreamProviders.joined(separator: ", "))")
        } else if let only = upstreamProviders.first {
            lines.append("업스트림: \(only)")
        }
        if respondedModels.count > 1 {
            lines.append("응답 모델이 갈렸다: \(respondedModels.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }
}

/// 요청·응답 전문을 남기는 자리. **키가 실릴 수 없는 모양**이다 — 도메인 요청만 담고
/// HTTP 헤더는 아예 다루지 않는다.
struct CallTranscript: Codable, Sendable {
    struct Message: Codable, Sendable {
        var role: String
        var text: String
    }

    var stage: String
    var subject: String
    var attempt: Int
    var requestedModel: String
    var system: [String]
    var messages: [Message]
    var maxOutputTokens: Int
    var responseFormat: String
    var reasoningEffort: String?
    var responseText: String?
    var reasoning: String?

    init(
        stage: String,
        subject: String,
        attempt: Int,
        requestedModel: String,
        request: CompletionRequest,
        response: CompletionResponse?
    ) {
        self.stage = stage
        self.subject = subject
        self.attempt = attempt
        self.requestedModel = requestedModel
        self.system = request.system.map(\.text)
        self.messages = request.messages.map { Message(role: $0.role.rawValue, text: $0.text) }
        self.maxOutputTokens = request.maxOutputTokens
        self.responseFormat =
            switch request.responseFormat {
            case .text: "text"
            case .jsonObject: "json_object"
            case .jsonSchema(let name, _, let strict): "json_schema:\(name)(strict=\(strict))"
            }
        self.reasoningEffort = request.reasoningEffort?.rawValue
        self.responseText = response?.text
        self.reasoning = response?.reasoning
    }
}
