internal import LLMKit

/// `POST /api/v1/chat/completions` 성공 응답.
///
/// OpenAI 호환 모양에 OpenRouter 가 ``provider`` 를 더한다. 그 필드가 재현 로그의
/// 핵심이다 — 같은 모델 ID 라도 어느 업스트림이 답했느냐로 결과가 달라지기 때문이다.
struct ChatCompletionsResponse: Decodable, Sendable, Hashable {
    let id: String?
    /// 실제로 답한 모델. 라우터가 갈아탈 수 있으므로 요청값과 다를 수 있다.
    let model: String?
    /// 실제로 서빙한 업스트림 이름 (`"DeepInfra"`, `"Fireworks"` …).
    let provider: String?
    let choices: [WireChoice]?
    let usage: WireUsage?
    /// **HTTP 200 인데 여기 오류가 실려 오는 경우가 있다.** 상태 코드만 보면 놓친다.
    let error: WireError?
}

struct WireChoice: Decodable, Sendable, Hashable {
    let index: Int?
    let message: WireResponseMessage?
    let finishReason: String?
    /// 업스트림이 준 원문 종료 사유. 정규화된 `finishReason` 이 뭉갠 정보가 여기 남는다.
    let nativeFinishReason: String?
    /// 선택 단위 오류. 팬아웃 응답에서 하나만 실패했을 때 온다.
    let error: WireError?

    enum CodingKeys: String, CodingKey {
        case index, message, error
        case finishReason = "finish_reason"
        case nativeFinishReason = "native_finish_reason"
    }
}

struct WireResponseMessage: Decodable, Sendable, Hashable {
    let role: String?
    let content: String?
    /// 사고 과정. `include_reasoning` 을 켰거나 모델이 기본으로 노출할 때.
    let reasoning: String?
    /// 거절 사유. 값이 있으면 모델이 답하지 않겠다고 한 것이다.
    let refusal: String?
}

struct WireUsage: Decodable, Sendable, Hashable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    /// `usage: {include: true}` 를 보냈을 때 실리는 실제 청구 금액(USD).
    let cost: Double?
    let promptTokensDetails: WirePromptTokensDetails?
    let completionTokensDetails: WireCompletionTokensDetails?

    enum CodingKeys: String, CodingKey {
        case cost
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case promptTokensDetails = "prompt_tokens_details"
        case completionTokensDetails = "completion_tokens_details"
    }
}

struct WirePromptTokensDetails: Decodable, Sendable, Hashable {
    /// 캐시에서 읽은 입력 토큰. `{#lessongen-prompt-caching}` 의 검증 지점.
    let cachedTokens: Int?
    /// 캐시에 새로 쓴 토큰. 명시적 캐싱에 웃돈이 붙는 공급자만 채워 준다.
    let cacheWriteTokens: Int?

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case cacheWriteTokens = "cache_write_tokens"
    }
}

struct WireCompletionTokensDetails: Decodable, Sendable, Hashable {
    let reasoningTokens: Int?

    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
    }
}

/// 오류 봉투 `{"error":{"code":…,"message":…,"metadata":{…}}}`.
///
/// `code` 는 대개 HTTP 상태와 같은 정수지만 문자열이 오는 경우도 있어 둘 다 받는다.
struct WireError: Decodable, Sendable, Hashable {
    let code: String?
    let message: String
    let metadata: WireErrorMetadata?

    enum CodingKeys: String, CodingKey { case code, message, metadata }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intCode = try? container.decode(Int.self, forKey: .code) {
            self.code = String(intCode)
        } else {
            self.code = try? container.decode(String.self, forKey: .code)
        }
        self.message = (try? container.decode(String.self, forKey: .message)) ?? "설명 없는 오류"
        self.metadata = try? container.decode(WireErrorMetadata.self, forKey: .metadata)
    }
}

struct WireErrorMetadata: Decodable, Sendable, Hashable {
    /// 문서화된 실패 분류. **재시도 판정의 1차 근거다** — HTTP 200 에 실려 오는
    /// 실패에서도 살아 있는 유일한 신호이기 때문이다.
    let errorType: String?
    /// 업스트림이 준 원문 코드.
    let providerCode: String?
    /// 실패한 업스트림 이름. 어느 공급자가 죽었는지 알아야 라우팅을 손볼 수 있다.
    let providerName: String?
    /// 업스트림이 준 원문. 문자열이 아닐 수도 있어 임의 JSON 으로 받는다.
    let raw: JSONValue?
    /// 모더레이션이 잡았을 때의 사유.
    let reasons: [String]?

    enum CodingKeys: String, CodingKey {
        case raw, reasons
        case errorType = "error_type"
        case providerCode = "provider_code"
        case providerName = "provider_name"
    }
}

/// 오류 봉투만 담은 최상위. 비-200 응답을 팔 때 쓴다.
struct WireErrorEnvelope: Decodable, Sendable, Hashable {
    let error: WireError
    /// OpenRouter 가 붙이는 요청 식별자. 없을 수 있다.
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case error
        case requestID = "request_id"
    }
}
