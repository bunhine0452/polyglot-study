internal import LLMKit

/// `POST /api/v1/chat/completions` 요청 본문.
///
/// OpenAI 호환 스키마에 OpenRouter 전용 필드(`provider`, `reasoning`, `usage`)가 얹혀
/// 있다. 이 타입은 **와이어 모양 그대로**다 — 도메인 타입(``CompletionRequest``)에서
/// 여기로 옮기는 일은 ``OpenRouterRequestBuilder`` 가 한다.
///
/// 필요한 것만 담는다. `tools`·`stream`·`transforms` 는 이 도구가 쓰지 않으므로 없다.
struct ChatCompletionsBody: Encodable, Sendable, Hashable {
    var model: String
    var messages: [WireMessage]
    var maxTokens: Int
    var temperature: Double?
    var topP: Double?
    var seed: Int?
    var responseFormat: WireResponseFormat?
    var reasoning: WireReasoning?
    var provider: WireProviderRouting?
    /// 캐시 친화 라우팅 키. 같은 값을 보내면 라우터가 같은 업스트림에 붙여 준다
    /// (10분 무활동으로 만료). 캐시 적중이 **공급자에 붙어 있기** 때문에, 이게 없으면
    /// 트랙마다 다른 업스트림으로 흩어져 캐시가 매번 차갑다.
    var sessionID: String?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, seed, reasoning, provider
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case responseFormat = "response_format"
        case sessionID = "session_id"
    }

    // `usage: {include: true}` 는 **보내지 않는다.** 2026년에 폐기되어 아무 효과가 없고,
    // 사용량·비용은 이제 모든 응답에 자동으로 실린다. 보내면 죽은 필드가 캐시 접두사
    // 바이트만 흔든다.
}

/// 메시지 하나.
///
/// `content` 가 문자열이거나 파트 배열이다. 파트 배열은 **명시적 캐시 경계**를 걸 때만
/// 쓴다 — Anthropic 계열은 `cache_control` 을 파트에 붙여야 캐시가 걸리고, 자동 캐싱
/// 공급자는 그냥 문자열이면 된다. 필요 없을 때 배열을 쓰지 않는 이유는, 파트 배열을
/// 받지 못하는 업스트림이 섞여 있기 때문이다.
struct WireMessage: Encodable, Sendable, Hashable {
    enum Content: Encodable, Sendable, Hashable {
        case text(String)
        case parts([WireContentPart])

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let value): try container.encode(value)
            case .parts(let value): try container.encode(value)
            }
        }
    }

    var role: String
    var content: Content
}

struct WireContentPart: Encodable, Sendable, Hashable {
    var text: String
    var cacheControl: WireCacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("text", forKey: .type)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(cacheControl, forKey: .cacheControl)
    }
}

/// 프롬프트 캐시 경계.
///
/// 접두사 일치라서 **앞쪽 바이트가 하나라도 바뀌면 뒤가 전부 무효**가 된다. 시스템
/// 프롬프트에 타임스탬프·실행 ID 를 절대 넣지 말 것. 적중 여부는 응답의
/// `usage.prompt_tokens_details.cached_tokens` 로 확인한다.
struct WireCacheControl: Encodable, Sendable, Hashable {
    /// `"5m"`·`"1h"`. 생략하면 공급자 기본값.
    var ttl: String?

    enum CodingKeys: String, CodingKey { case type, ttl }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("ephemeral", forKey: .type)
        try container.encodeIfPresent(ttl, forKey: .ttl)
    }
}

enum WireResponseFormat: Encodable, Sendable, Hashable {
    case jsonObject
    case jsonSchema(name: String, schema: JSONValue, strict: Bool)

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    enum SchemaKeys: String, CodingKey {
        case name, strict, schema
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .jsonObject:
            try container.encode("json_object", forKey: .type)
        case .jsonSchema(let name, let schema, let strict):
            try container.encode("json_schema", forKey: .type)
            var nested = container.nestedContainer(keyedBy: SchemaKeys.self, forKey: .jsonSchema)
            try nested.encode(name, forKey: .name)
            try nested.encode(strict, forKey: .strict)
            try nested.encode(schema, forKey: .schema)
        }
    }
}

/// 사고 설정. OpenRouter 가 벤더별 표현(`reasoning_effort`, `thinking`)으로 번역한다.
struct WireReasoning: Encodable, Sendable, Hashable {
    var effort: String
}

/// 업스트림 라우팅 정책.
///
/// ``requireParameters`` 가 이 구현에서 가장 중요한 한 줄이다. 같은 모델 ID 뒤에 여러
/// 업스트림이 서 있고 **지원 파라미터가 서로 다르다** — 실측: `z-ai/glm-5.3-flash` 는
/// 엔드포인트 23곳 중 6곳(Z.AI 자사 포함)이 `structured_outputs` 를 지원하지 않고,
/// `seed` 는 9곳이 지원하지 않는다.
///
/// `response_format` 은 이 플래그 없이도 **약한 선호**로 취급되어, 일부 업스트림만
/// 지원하면 그쪽으로 좁혀진다. 하지만 **하나도 지원하지 않으면 요청은 그대로 나가고
/// 파라미터만 조용히 버려진다** — 그러면 200 과 함께 산문이 돌아오고, 스키마 위반이
/// 아니라 JSON 이 아예 아닌 응답이라 파싱 실패로만 드러난다. `seed` 에는 그 약한 선호도
/// 없다. 이 플래그는 요청한 파라미터를 전부 지원하는 업스트림으로만 라우팅을 좁혀
/// 두 경우를 다 막는다.
struct WireProviderRouting: Encodable, Sendable, Hashable {
    var requireParameters: Bool

    enum CodingKeys: String, CodingKey {
        case requireParameters = "require_parameters"
    }
}
