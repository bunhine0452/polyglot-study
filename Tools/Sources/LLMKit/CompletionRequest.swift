/// 공급자에게 보내는 요청. **와이어 포맷이 아니다** — 공급자가 자기 모양으로 옮긴다.
///
/// 여기 없는 것에 의미가 있다. 벤더 전용 파라미터(`anthropic-beta`, `provider.order`,
/// `transforms`)는 전부 공급자 설정으로 밀어 두었다. 요청은 **무엇을 원하는가**만
/// 말하고, **어떻게 부탁하는가**는 공급자가 안다.
public struct CompletionRequest: Sendable, Hashable {
    /// 캐시 접두사가 될 안정 부분. 여러 요청에 걸쳐 바이트가 같아야 의미가 있다.
    public var system: [PromptSegment]
    public var messages: [ChatMessage]
    public var maxOutputTokens: Int
    public var responseFormat: ResponseFormat
    public var sampling: SamplingParameters?
    /// 사고 모델에만 의미가 있다. 지원하지 않는 공급자는 무시한다 — 400 을 만들지
    /// 않는 쪽이 낫다. 사고 자체가 없는 모델에 노력 수준은 틀린 요구가 아니라 무의미한
    /// 요구이기 때문이다.
    public var reasoningEffort: ReasoningEffort?

    public init(
        system: [PromptSegment] = [],
        messages: [ChatMessage],
        maxOutputTokens: Int,
        responseFormat: ResponseFormat = .text,
        sampling: SamplingParameters? = nil,
        reasoningEffort: ReasoningEffort? = nil
    ) {
        self.system = system
        self.messages = messages
        self.maxOutputTokens = maxOutputTokens
        self.responseFormat = responseFormat
        self.sampling = sampling
        self.reasoningEffort = reasoningEffort
    }
}

/// 시스템 프롬프트 한 토막.
///
/// 조각으로 나눠 두는 이유는 **캐시 경계가 조각 사이에 놓이기** 때문이다. 하나의 큰
/// 문자열로 두면 명시적 캐시를 쓰는 공급자에게 경계를 알려 줄 수가 없다.
public struct PromptSegment: Sendable, Hashable {
    public var text: String
    /// 이 조각까지를 캐시 접두사로 잡아 달라는 요청.
    ///
    /// 자동 캐싱 공급자는 무시한다 — 그쪽은 접두사를 알아서 잡는다. 힌트를 주는 쪽이
    /// 손해가 아닌 이유는, 힌트 자체가 "여기까지가 안정 접두사" 라는 **문서**이기
    /// 때문이다.
    public var cacheHint: CacheHint?

    public init(text: String, cacheHint: CacheHint? = nil) {
        self.text = text
        self.cacheHint = cacheHint
    }
}

/// 캐시 경계 힌트.
public struct CacheHint: Sendable, Hashable {
    /// 얼마나 오래 붙들어 둘지. `nil` 이면 공급자 기본값.
    public var ttl: Duration?

    public init(ttl: Duration? = nil) { self.ttl = ttl }

    /// 공급자 기본 TTL 로 경계만 찍는다.
    public static let `default` = CacheHint()
}

public struct ChatMessage: Sendable, Hashable {
    public enum Role: String, Sendable, Hashable {
        case user, assistant
    }

    public var role: Role
    public var text: String
    public var cacheHint: CacheHint?

    public init(role: Role, text: String, cacheHint: CacheHint? = nil) {
        self.role = role
        self.text = text
        self.cacheHint = cacheHint
    }

    public static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, text: text)
    }
}

/// 응답을 어떤 모양으로 받을지.
public enum ResponseFormat: Sendable, Hashable {
    /// 그냥 텍스트.
    case text
    /// 유효한 JSON 이기만 하면 된다. 스키마 강제는 없다.
    case jsonObject
    /// 이 스키마를 만족하는 JSON.
    ///
    /// - Parameters:
    ///   - name: 스키마 이름. OpenAI 호환 API 가 요구한다.
    ///   - schema: JSON Schema 본문. 모든 객체에 `additionalProperties: false` 와
    ///     `required` 를 채워야 `strict` 가 통과한다.
    ///   - strict: 스키마를 **강제**할지. 끄면 모델에게 힌트로만 간다.
    case jsonSchema(name: String, schema: JSONValue, strict: Bool = true)

    /// 이 형식을 내려면 공급자가 무엇을 할 수 있어야 하는가.
    public var requiredCapability: ProviderCapabilities? {
        switch self {
        case .text: nil
        case .jsonObject: .jsonObjectMode
        case .jsonSchema: .structuredOutputs
        }
    }
}

/// 샘플링 파라미터.
///
/// 통째로 선택인 이유: 사고 모델 중에는 `temperature` 를 받으면 400 을 내는 것이 있고
/// (Anthropic Opus 5 가 그랬다), 로컬 백엔드는 반대로 항상 받는다. 안 주면 공급자
/// 기본값이다.
public struct SamplingParameters: Sendable, Hashable {
    public var temperature: Double?
    public var topP: Double?
    /// 결정적 샘플링 시드.
    ///
    /// **받는다고 재현이 보장되지는 않는다.** 라우터가 다른 업스트림으로 보내거나
    /// 배치 구성이 달라지면 같은 시드도 다른 결과를 낸다. 그래서 실행 로그는 시드와
    /// **실제로 답한 모델·업스트림**을 함께 남긴다 (`{#lessongen-runlog}`).
    public var seed: Int?

    public init(temperature: Double? = nil, topP: Double? = nil, seed: Int? = nil) {
        self.temperature = temperature
        self.topP = topP
        self.seed = seed
    }

    /// 재현을 노리는 설정 — 온도 0, 시드 고정.
    public static func deterministic(seed: Int) -> SamplingParameters {
        SamplingParameters(temperature: 0, seed: seed)
    }
}

/// 사고 노력 수준.
///
/// **모델마다 받아 주는 값이 다르다.** 사고가 필수인 모델은 ``none`` 을 거절하고,
/// ``medium`` 이 없는 모델도 있다 (실측: `z-ai/glm-5.3-flash` 는 low·high·max 만).
/// 어떤 값이 유효한지는 모델 카탈로그가 알려 주므로 여기서 좁히지 않는다 — 좁히면
/// 새 모델이 나올 때마다 이 열거형을 고쳐야 한다.
public enum ReasoningEffort: String, Sendable, Hashable, CaseIterable, Codable {
    /// 사고를 끈다. 사고가 필수인 모델은 이 값을 거절할 수 있다.
    case none
    case low, medium, high
    /// 최대. 사고 예산이 큰 모델에만 있다.
    case max
}
