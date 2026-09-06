/// 모델 식별자.
///
/// 가격은 2026-09-06 기준 100만 토큰당 입력/출력이다. `lessongen` 의 비용 가드
/// (`{#lessongen-runlog}`) 가 이 표를 쓰게 된다.
public struct AnthropicModel: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    /// $5 / $25. 컨텍스트 1M, 최대 출력 128K. 기본값.
    ///
    /// 사고(thinking)가 기본으로 켜져 있고 `temperature`·`top_p`·`top_k` 는 400 으로
    /// 거절된다 — **시드로 생성물을 재현할 수 없다**. 그래서 재현성은 샘플링 파라미터가
    /// 아니라 전량 감사 로그로 대체한다.
    public static let opus5 = AnthropicModel("claude-opus-5")
    /// $2 / $10. 값싼 재생성·수리 루프용 후보.
    public static let sonnet5 = AnthropicModel("claude-sonnet-5")
    /// $1 / $5. 컨텍스트 200K.
    public static let haiku45 = AnthropicModel("claude-haiku-4-5")
}

/// 사고 노력 수준. 생략하면 서버 기본값 `high`.
public enum Effort: String, Sendable, Codable, CaseIterable {
    case low, medium, high, xhigh, max
}

/// `POST /v1/messages` 요청 본문.
///
/// 필요한 만큼만 담는다. `tools`·`stream` 은 이 도구가 쓰지 않으므로 없다.
public struct MessagesRequest: Encodable, Sendable, Hashable {
    public var model: AnthropicModel
    public var maxTokens: Int
    /// 안정 접두사. 프롬프트 캐시를 걸 자리다 (`{#lessongen-prompt-caching}`).
    public var system: [SystemBlock]?
    public var messages: [Message]
    public var thinking: Thinking?
    public var outputConfig: OutputConfig?
    /// 거절(`stop_reason: "refusal"`) 시 서버가 대체 모델로 같은 호출 안에서 재시도한다.
    public var fallbacks: Fallbacks?

    public init(
        model: AnthropicModel,
        maxTokens: Int,
        system: [SystemBlock]? = nil,
        messages: [Message],
        thinking: Thinking? = nil,
        outputConfig: OutputConfig? = nil,
        fallbacks: Fallbacks? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.messages = messages
        self.thinking = thinking
        self.outputConfig = outputConfig
        self.fallbacks = fallbacks
    }

    // 와이어 키는 손으로 적는다. `.convertToSnakeCase` 를 쓰면 ``JSONValue`` 의 동적
    // 키까지 함께 변환돼 JSON Schema 의 `additionalProperties` 가 망가진다.
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
        case thinking
        case outputConfig = "output_config"
        case fallbacks
    }
}

/// 시스템 프롬프트 블록.
public struct SystemBlock: Encodable, Sendable, Hashable {
    public var text: String
    /// 이 블록까지를 캐시 접두사로 잡는다.
    public var cacheControl: CacheControl?

    public init(text: String, cacheControl: CacheControl? = nil) {
        self.text = text
        self.cacheControl = cacheControl
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("text", forKey: .type)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(cacheControl, forKey: .cacheControl)
    }
}

/// 프롬프트 캐시 지시자.
///
/// 접두사 일치라서 **앞쪽 바이트가 하나라도 바뀌면 뒤가 전부 무효**가 된다. 시스템
/// 프롬프트에 타임스탬프·실행 ID 를 절대 넣지 말 것. 적중 여부는 응답의
/// ``Usage/cacheReadInputTokens`` 로 확인한다.
public struct CacheControl: Encodable, Sendable, Hashable {
    /// `"1h"` 를 주면 1시간 TTL. 생략하면 기본 5분.
    public var ttl: String?

    public init(ttl: String? = nil) { self.ttl = ttl }

    enum CodingKeys: String, CodingKey { case type, ttl }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("ephemeral", forKey: .type)
        try container.encodeIfPresent(ttl, forKey: .ttl)
    }
}

public struct Message: Encodable, Sendable, Hashable {
    public enum Role: String, Encodable, Sendable { case user, assistant }

    public var role: Role
    public var content: [ContentBlock]

    public init(role: Role, content: [ContentBlock]) {
        self.role = role
        self.content = content
    }

    public static func user(_ text: String) -> Message {
        Message(role: .user, content: [ContentBlock(text: text)])
    }
}

/// 텍스트 블록. 이 도구는 이미지도 문서도 보내지 않으므로 텍스트만 있다.
public struct ContentBlock: Encodable, Sendable, Hashable {
    public var text: String
    public var cacheControl: CacheControl?

    public init(text: String, cacheControl: CacheControl? = nil) {
        self.text = text
        self.cacheControl = cacheControl
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("text", forKey: .type)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(cacheControl, forKey: .cacheControl)
    }
}

/// 사고 설정.
///
/// Opus 5 에서는 `budget_tokens` 가 제거되어 보내면 400 이다. 깊이는
/// ``OutputConfig/effort`` 로 조절한다.
public struct Thinking: Encodable, Sendable, Hashable {
    public enum Kind: String, Encodable, Sendable {
        case adaptive
        /// Opus 5 에서는 effort 가 `high` 이하일 때만 받아 준다.
        case disabled
    }

    /// 사고 내용을 응답에 어떻게 실을지. Opus 5 기본값은 `omitted`.
    public enum Display: String, Encodable, Sendable {
        case omitted, summarized
    }

    public var type: Kind
    public var display: Display?

    public init(type: Kind = .adaptive, display: Display? = nil) {
        self.type = type
        self.display = display
    }
}

public struct OutputConfig: Encodable, Sendable, Hashable {
    public var effort: Effort?
    /// 구조화 출력. 있으면 응답의 첫 텍스트 블록이 스키마를 만족하는 JSON 임이 보장된다.
    public var format: OutputFormat?

    public init(effort: Effort? = nil, format: OutputFormat? = nil) {
        self.effort = effort
        self.format = format
    }
}

public struct OutputFormat: Encodable, Sendable, Hashable {
    /// JSON Schema. 모든 객체에 `additionalProperties: false` 와 `required` 가 있어야 한다.
    public var schema: JSONValue

    public init(schema: JSONValue) { self.schema = schema }

    enum CodingKeys: String, CodingKey { case type, schema }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("json_schema", forKey: .type)
        try container.encode(schema, forKey: .schema)
    }
}

/// 거절 시 서버측 대체 모델 라우팅.
///
/// `.default` 는 거절 사유에 따라 서버가 알아서 고른다 — 모델 목록을 우리가 유지하지
/// 않아도 된다. **Batch API 에서는 거절되는 파라미터**이므로
/// `{#lessongen-batch-fanout}` 을 붙일 때는 빼야 한다.
public enum Fallbacks: Encodable, Sendable, Hashable {
    case `default`
    case models([AnthropicModel])

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .default:
            var container = encoder.singleValueContainer()
            try container.encode("default")
        case .models(let models):
            var container = encoder.unkeyedContainer()
            for model in models {
                var entry = container.nestedContainer(keyedBy: ModelKey.self)
                try entry.encode(model, forKey: .model)
            }
        }
    }

    enum ModelKey: String, CodingKey { case model }

    /// 각 형태가 요구하는 베타 플래그. 서로 바꿔 쓰면 400 이다.
    public var betaFlag: String {
        switch self {
        case .default: "server-side-fallback-2026-07-01"
        case .models: "server-side-fallback-2026-06-01"
        }
    }
}
