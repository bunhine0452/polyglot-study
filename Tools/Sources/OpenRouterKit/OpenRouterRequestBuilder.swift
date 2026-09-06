public import Foundation
public import LLMKit

/// 호출할 엔드포인트.
public enum OpenRouterEndpoint: Sendable, Hashable {
    case chatCompletions
    /// 생성 사후 조회. 비용·토큰을 응답 뒤에 다시 확인할 때 (`{#lessongen-runlog}`).
    /// 아직 아무도 호출하지 않는다.
    case generation

    public var path: String {
        switch self {
        case .chatCompletions: "/chat/completions"
        case .generation: "/generation"
        }
    }
}

/// 캐시 경계를 어떻게 표현할지.
public enum PromptCachingMode: Sendable, Hashable {
    /// 업스트림이 알아서 캐시한다. 메시지 `content` 는 그냥 문자열이다.
    ///
    /// 대부분의 오픈 모델 호스트가 이쪽이다 — 안정 접두사를 앞에 두기만 하면 되고
    /// 캐시 쓰기에 웃돈이 없다.
    case automatic
    /// `cache_control` 로 경계를 **명시**한다. 메시지 `content` 가 파트 배열이 된다.
    ///
    /// Anthropic 계열이 이쪽이다 — 명시하지 않으면 캐시가 아예 안 걸리고, 캐시 쓰기에
    /// 웃돈이 붙는다. 파트 배열을 못 받는 업스트림이 섞여 있으므로 **기본값이 아니다.**
    case explicitBreakpoints
}

/// 요청 조립. **순수 함수다** — 네트워크도 시계도 건드리지 않으므로 키 없이 전량 검증된다.
public struct OpenRouterRequestBuilder: Sendable {
    /// OpenAI 호환 표면의 루트. 경로 `/chat/completions` 가 여기 붙는다.
    public static let defaultBaseURL = URL(string: "https://openrouter.ai/api/v1")!

    public struct Attribution: Sendable, Hashable {
        /// `HTTP-Referer`. OpenRouter 순위 페이지에 앱을 식별시키는 선택 헤더다.
        public var referer: String?
        /// `X-OpenRouter-Title`. 같은 목적의 사람이 읽는 이름. (옛 이름 `X-Title` 도
        /// 아직 받아 주지만 정식 이름은 이쪽이다.) `HTTP-Referer` 없이 이것만 보내면
        /// 아무것도 만들어지지 않는다.
        public var title: String?

        public init(referer: String? = nil, title: String? = nil) {
            self.referer = referer
            self.title = title
        }

        /// 이 저장소의 기본값. 비밀값이 아니고 공개 저장소 주소일 뿐이다.
        public static let polyglotStudy = Attribution(
            referer: "https://github.com/polyglot-study/polyglot",
            title: "Polyglot Study lessongen"
        )
    }

    public var baseURL: URL
    public var timeout: Duration
    public var attribution: Attribution
    /// 요청한 파라미터를 전부 지원하는 업스트림으로만 라우팅을 좁힐지.
    ///
    /// 기본이 켜짐인 이유는 ``WireProviderRouting`` 주석에 있다 — 꺼 두면 구조화 출력
    /// 요청이 그걸 모르는 업스트림에 걸려 산문으로 돌아온다.
    public var requireParameters: Bool
    /// 캐시 친화 라우팅 키. 같은 값을 쓰는 요청들이 같은 업스트림에 붙는다.
    ///
    /// 프롬프트 캐시는 **업스트림에 붙어 있다.** 이게 없으면 트랙마다 라우터가 다른
    /// 업스트림을 고를 수 있고, 그러면 고정 시스템 프롬프트를 아무리 잘 잡아도 캐시가
    /// 매번 차갑다 (`{#lessongen-prompt-caching}`). 비밀값이 아니다.
    public var sessionID: String?
    public var promptCaching: PromptCachingMode

    public init(
        baseURL: URL = OpenRouterRequestBuilder.defaultBaseURL,
        timeout: Duration = .seconds(600),
        attribution: Attribution = .polyglotStudy,
        requireParameters: Bool = true,
        sessionID: String? = nil,
        promptCaching: PromptCachingMode = .automatic
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.attribution = attribution
        self.requireParameters = requireParameters
        self.sessionID = sessionID
        self.promptCaching = promptCaching
    }

    /// 본문을 바이트로 굽는다.
    ///
    /// `sortedKeys` 를 켜서 같은 입력이 항상 같은 바이트가 되게 한다 — 프롬프트 캐시가
    /// 접두사 바이트 일치이고, 감사 로그도 결정적이어야 하기 때문이다.
    /// `keyEncodingStrategy` 는 **쓰지 않는다**. ``JSONValue`` 의 동적 키까지 변환돼
    /// JSON Schema 의 `additionalProperties` 가 `additional_properties` 로 망가진다.
    public static func encodeBody(_ body: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(body)
    }

    /// 엔드포인트 URL. `appendingPathComponent` 는 선행 슬래시와 만나면 `//` 를 만들 수
    /// 있어 쓰지 않는다.
    public func url(for endpoint: OpenRouterEndpoint) throws -> URL {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + endpoint.path) else {
            throw LLMError.malformedResponse("엔드포인트 URL 을 만들 수 없습니다: \(base)\(endpoint.path)")
        }
        return url
    }

    /// 도메인 요청을 와이어 본문으로 옮긴다. 순수 함수.
    func makeBody(for request: CompletionRequest, model: ModelID) -> ChatCompletionsBody {
        var messages: [WireMessage] = []
        for segment in request.system {
            messages.append(
                WireMessage(role: "system", content: content(text: segment.text, hint: segment.cacheHint))
            )
        }
        for message in request.messages {
            messages.append(
                WireMessage(role: message.role.rawValue, content: content(text: message.text, hint: message.cacheHint))
            )
        }

        let responseFormat: WireResponseFormat?
        switch request.responseFormat {
        case .text: responseFormat = nil
        case .jsonObject: responseFormat = .jsonObject
        case .jsonSchema(let name, let schema, let strict):
            responseFormat = .jsonSchema(name: name, schema: schema, strict: strict)
        }

        return ChatCompletionsBody(
            model: model.rawValue,
            messages: messages,
            maxTokens: request.maxOutputTokens,
            temperature: request.sampling?.temperature,
            topP: request.sampling?.topP,
            seed: request.sampling?.seed,
            responseFormat: responseFormat,
            reasoning: request.reasoningEffort.map { WireReasoning(effort: $0.rawValue) },
            // 라우팅을 좁히는 것은 **요구한 파라미터가 있을 때만** 의미가 있다. 아무
            // 파라미터도 안 건 요청까지 좁히면 값싼 업스트림을 이유 없이 버리게 된다.
            provider: (requireParameters && hasRoutingSensitiveParameters(request))
                ? WireProviderRouting(requireParameters: true)
                : nil,
            sessionID: sessionID
        )
    }

    /// 업스트림마다 지원 여부가 갈리는 파라미터를 요청이 쓰고 있는가.
    private func hasRoutingSensitiveParameters(_ request: CompletionRequest) -> Bool {
        if request.responseFormat != .text { return true }
        if request.sampling?.seed != nil { return true }
        return false
    }

    private func content(text: String, hint: CacheHint?) -> WireMessage.Content {
        switch promptCaching {
        case .automatic:
            .text(text)
        case .explicitBreakpoints:
            .parts([WireContentPart(text: text, cacheControl: hint.map { WireCacheControl(ttl: ttlString($0.ttl)) })])
        }
    }

    /// `Duration` 을 공급자가 읽는 문자열로. 아는 값만 내보내고 나머지는 기본값에 맡긴다.
    private func ttlString(_ ttl: Duration?) -> String? {
        guard let ttl else { return nil }
        let seconds = Int(ttl.asTimeInterval.rounded())
        return seconds >= 3600 ? "1h" : "5m"
    }

    /// 헤더까지 붙은 `URLRequest` 를 만든다. 키는 여기서만 원문으로 읽힌다.
    public func makeURLRequest(
        for request: CompletionRequest,
        model: ModelID,
        apiKey: APIKey
    ) throws -> URLRequest {
        try makeURLRequest(endpoint: .chatCompletions, body: makeBody(for: request, model: model), apiKey: apiKey)
    }

    /// 임의 본문을 실은 요청. 테스트와 사후 조회가 쓴다.
    public func makeURLRequest(
        endpoint: OpenRouterEndpoint,
        body: some Encodable,
        apiKey: APIKey
    ) throws -> URLRequest {
        var request = URLRequest(url: try url(for: endpoint))
        request.httpMethod = "POST"
        request.httpBody = try Self.encodeBody(body)
        request.timeoutInterval = timeout.asTimeInterval
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey.rawValue)", forHTTPHeaderField: "authorization")
        // 선택 헤더. OpenRouter 가 앱을 식별하는 데 쓰고, 비밀값이 아니다.
        if let referer = attribution.referer, !referer.isEmpty {
            request.setValue(referer, forHTTPHeaderField: "http-referer")
        }
        if let title = attribution.title, !title.isEmpty {
            request.setValue(title, forHTTPHeaderField: "x-openrouter-title")
        }
        return request
    }

    /// 사람이 읽을 요청 덤프. **키 자리에 자리표시자가 들어간다.**
    ///
    /// `--dry-run` 과 감사 로그가 쓴다. `URLRequest` 를 통째로 문자열화하면 헤더가 그대로
    /// 나오므로, 덤프는 반드시 이 함수를 거쳐야 한다.
    public static func redactedDump(of request: URLRequest, apiKey: APIKey? = nil) -> String {
        let redactor = apiKey.map { Redactor(apiKey: $0) } ?? Redactor()
        var lines: [String] = []
        lines.append("\(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        // 헤더 이름을 소문자로 눕혀 둔다 — `URLRequest` 가 표준 헤더를 정규화하는 바람에
        // 같은 요청의 덤프가 실행마다 다른 대소문자로 나오면 감사 diff 가 더러워진다.
        let headers = Dictionary(
            (request.allHTTPHeaderFields ?? [:]).map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { _, last in last }
        )
        for name in headers.keys.sorted() {
            let value = name == "authorization"
                ? "Bearer \(apiKey?.variable.placeholder ?? APIKey.placeholder)"
                : headers[name]!
            lines.append("\(name): \(redactor.redact(value))")
        }
        lines.append("")
        lines.append(redactor.redact(String(decoding: request.httpBody ?? Data(), as: UTF8.self)))
        return lines.joined(separator: "\n")
    }
}
