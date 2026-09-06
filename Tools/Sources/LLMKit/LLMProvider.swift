/// 공급자 하나가 실제로 할 수 있는 일.
///
/// **이론적 상한이 아니라 이 구현이 지금 하는 것을 선언한다.** OpenRouter 가 SSE
/// 스트리밍을 지원해도 우리 구현이 스트리밍을 안 하면 ``streaming`` 은 빠진다 —
/// `CodeRunner.enforcedLimits` 와 같은 규율이다. 능력을 부풀리면 호출자가 없는 기능을
/// 믿고 분기하고, 계약 스위트는 검사 범위를 잘못 잡는다.
public struct ProviderCapabilities: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// JSON Schema 를 주면 스키마를 만족하는 JSON 이 나온다 (`ResponseFormat.jsonSchema`).
    ///
    /// 이게 없으면 개요 생성은 "JSON 만 내놔" 라고 부탁하고 파싱 실패를 재시도로 때워야
    /// 한다 — 그래서 호출자가 런타임에 물어봐야 하는 능력이다.
    public static let structuredOutputs = ProviderCapabilities(rawValue: 1 << 0)
    /// 스키마 없이 "유효한 JSON" 만 강제할 수 있다 (`ResponseFormat.jsonObject`).
    public static let jsonObjectMode = ProviderCapabilities(rawValue: 1 << 1)
    /// 토큰이 흘러나오는 대로 낸다 (``LLMProvider/stream(_:)``).
    public static let streaming = ProviderCapabilities(rawValue: 1 << 2)
    /// 응답에 입력·출력 토큰 수가 실린다.
    public static let usageTokens = ProviderCapabilities(rawValue: 1 << 3)
    /// 응답에 실제 청구 금액이 실린다. 로컬 백엔드에는 없다.
    public static let usageCost = ProviderCapabilities(rawValue: 1 << 4)
    /// `temperature`·`top_p` 를 받는다.
    public static let samplingControls = ProviderCapabilities(rawValue: 1 << 5)
    /// `seed` 를 받는다. **받는 것과 지키는 것은 다르다** — 재현 로그는 시드를 남기되
    /// 재현을 보장하지 않는다.
    public static let seededSampling = ProviderCapabilities(rawValue: 1 << 6)
    /// 프롬프트 캐시 경계를 **호출자가 명시**한다 (`PromptSegment.cacheHint`).
    public static let explicitPromptCaching = ProviderCapabilities(rawValue: 1 << 7)
    /// 프롬프트 캐시가 **자동**이다. 호출자는 안정 접두사를 앞에 두기만 하면 된다.
    public static let automaticPromptCaching = ProviderCapabilities(rawValue: 1 << 8)
    /// 사고(reasoning) 노력 수준을 조절할 수 있다.
    public static let reasoningEffort = ProviderCapabilities(rawValue: 1 << 9)
}

extension ProviderCapabilities: CustomStringConvertible {
    public var description: String {
        let names: [(ProviderCapabilities, String)] = [
            (.structuredOutputs, "structuredOutputs"),
            (.jsonObjectMode, "jsonObjectMode"),
            (.streaming, "streaming"),
            (.usageTokens, "usageTokens"),
            (.usageCost, "usageCost"),
            (.samplingControls, "samplingControls"),
            (.seededSampling, "seededSampling"),
            (.explicitPromptCaching, "explicitPromptCaching"),
            (.automaticPromptCaching, "automaticPromptCaching"),
            (.reasoningEffort, "reasoningEffort"),
        ]
        let present = names.filter { contains($0.0) }.map(\.1)
        return present.isEmpty ? "[]" : "[\(present.joined(separator: ", "))]"
    }
}

/// 텍스트 생성의 유일한 경계.
///
/// 구현은 지금 하나다 — OpenRouter(OpenAI 호환 `chat/completions`). 다음에 들어올 것은
/// 로컬 MLX 백엔드이고, 그때 이 프로토콜은 **바뀌지 않아야 한다.** 그래서 여기에는
/// HTTP 도, 토큰 단가도, 벤더 파라미터도 없다.
///
/// `CodeRunner` 와 같은 모양이다 — 능력을 런타임에 물어보고(``capabilities``),
/// 실패는 공급자 중립 오류(``LLMError``)로 정규화되며, 모든 구현이 하나의 계약
/// 스위트(`ProviderContract`)를 통과한다.
public protocol LLMProvider: Sendable {
    /// 이 구현이 실제로 하는 일. 호출자가 런타임에 물어본다.
    ///
    /// 기본 구현을 일부러 두지 않았다 — 새 백엔드가 "무엇을 못 하는지" 를 조용히
    /// 넘어가지 못하게 하는 것이 이 속성의 존재 이유다.
    var capabilities: ProviderCapabilities { get }

    /// 실행 로그에 남길 공급자 신원. **비밀값이 없어야 한다.**
    var identity: ProviderIdentity { get }

    /// 완성 하나. 재시도는 구현 안에서 끝낸다 — 호출자는 최종 결과만 본다.
    func complete(_ request: CompletionRequest) async throws -> CompletionResponse

    /// 토큰이 흘러나오는 대로. ``ProviderCapabilities/streaming`` 을 선언한 구현만
    /// 진짜로 구현한다.
    func stream(_ request: CompletionRequest) -> AsyncThrowingStream<CompletionEvent, any Error>
}

extension LLMProvider {
    /// 스트리밍을 선언하지 않은 공급자의 기본 동작 — **던진다.**
    ///
    /// `complete` 를 불러 한 덩어리로 흘려보내는 가짜 스트림을 만들지 않는다. 그러면
    /// UI 가 "스트리밍 되는데 왜 한 번에 오지" 를 겪게 되고, 능력 선언이 거짓말이
    /// 된다. 로컬 MLX 백엔드는 진짜 토큰 스트림을 갖고 오므로 이 자리를 덮어쓴다.
    public func stream(_ request: CompletionRequest) -> AsyncThrowingStream<CompletionEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: LLMError.unsupported(.streaming))
        }
    }
}

/// 실행 로그에 남는 공급자 신원.
public struct ProviderIdentity: Hashable, Sendable {
    /// `"openrouter"`, 나중에 `"mlx"`.
    public let provider: String
    /// 이 공급자가 쓰도록 설정된 모델.
    public let model: ModelID

    public init(provider: String, model: ModelID) {
        self.provider = provider
        self.model = model
    }
}

extension ProviderIdentity: CustomStringConvertible {
    public var description: String { "\(provider):\(model.rawValue)" }
}

/// 스트리밍 중 흘러나오는 사건.
///
/// 지금 쓰는 구현이 없어도 **모양은 잡아 둔다** — MLX 백엔드가 붙을 때 프로토콜을
/// 다시 흔들지 않으려는 것이다.
public enum CompletionEvent: Sendable, Hashable {
    /// 이어 붙일 텍스트 조각.
    case textDelta(String)
    /// 사고 과정 조각. 공급자가 노출할 때만.
    case reasoningDelta(String)
    /// 마지막에 한 번. 여기서 usage 가 확정된다.
    case finished(CompletionResponse)
}
