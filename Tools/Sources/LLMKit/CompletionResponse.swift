import Foundation

/// 공급자가 돌려준 완성 하나.
public struct CompletionResponse: Sendable, Hashable {
    /// 공급자가 준 생성 ID. 사후에 비용·로그를 되짚는 열쇠다.
    public let id: String
    /// **실제로 답한 모델.** 요청한 모델과 다를 수 있다 — 라우터가 갈아탈 수 있기
    /// 때문이다. 실행 로그에는 요청값이 아니라 이 값을 남겨야 재현이 된다.
    public let model: String
    /// 실제로 서빙한 업스트림. 같은 모델도 업스트림이 다르면 결과가 달라진다.
    /// 공급자가 알려 주지 않으면 `nil`.
    public let upstreamProvider: String?
    public let text: String
    /// 사고 과정. 공급자가 노출할 때만.
    public let reasoning: String?
    public let finishReason: FinishReason?
    public let usage: TokenUsage

    public init(
        id: String,
        model: String,
        upstreamProvider: String? = nil,
        text: String,
        reasoning: String? = nil,
        finishReason: FinishReason? = nil,
        usage: TokenUsage
    ) {
        self.id = id
        self.model = model
        self.upstreamProvider = upstreamProvider
        self.text = text
        self.reasoning = reasoning
        self.finishReason = finishReason
        self.usage = usage
    }
}

/// 왜 멈췄는가.
///
/// 열거형이 아니라 래퍼다 — 공급자가 새 값을 만들어도 디코딩이 깨지지 않게.
public struct FinishReason: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// 정상 종료.
    public static let stop = FinishReason("stop")
    /// 출력이 상한에 걸려 잘렸다. **구조화 출력이라면 JSON 이 깨져 있다.**
    public static let length = FinishReason("length")
    /// 도구 호출로 멈췄다. 이 도구는 도구를 쓰지 않으므로 오면 이상한 것이다.
    public static let toolCalls = FinishReason("tool_calls")
    /// 콘텐츠 필터가 잘랐다.
    public static let contentFilter = FinishReason("content_filter")
    /// 오류로 끝났다.
    public static let error = FinishReason("error")
}

/// 이번 호출이 쓴 것.
///
/// 필드가 전부 선택인 이유: 공급자마다 알려 주는 것이 다르고, 모르는 값을 0 으로 채우면
/// 비용 가드가 조용히 틀린 합계를 낸다 (`{#lessongen-runlog}`). "0 토큰" 과 "모른다" 는
/// 다른 사실이다.
public struct TokenUsage: Sendable, Hashable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    /// 사고에 쓴 토큰. 출력 토큰에 포함될 수도, 따로일 수도 있다 — 공급자마다 다르므로
    /// 합산하지 말고 그대로 남긴다.
    public let reasoningTokens: Int?
    /// 캐시에서 읽은 입력 토큰. `{#lessongen-prompt-caching}` 의 검증 지점 —
    /// 2회차부터 여기가 0 이 아니어야 한다.
    public let cachedInputTokens: Int?
    /// 캐시에 새로 쓴 토큰. 캐시 쓰기에 웃돈이 붙는 공급자만 알려 준다.
    public let cacheWriteTokens: Int?
    /// 이번 호출의 실제 청구 금액(USD). 공급자가 알려 줄 때만.
    public let costUSD: Double?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        cachedInputTokens: Int? = nil,
        cacheWriteTokens: Int? = nil,
        costUSD: Double? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.cachedInputTokens = cachedInputTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.costUSD = costUSD
    }

    public static let unknown = TokenUsage()

    /// 로그 한 줄. 모르는 값은 `?` 로 남긴다 — 0 으로 위장하지 않는다.
    public var logLine: String {
        func show(_ value: Int?) -> String { value.map(String.init) ?? "?" }
        var line = "in=\(show(inputTokens)) out=\(show(outputTokens)) cached=\(show(cachedInputTokens))"
        if let reasoningTokens { line += " reasoning=\(reasoningTokens)" }
        if let costUSD { line += String(format: " cost=$%.6f", costUSD) }
        return line
    }
}
