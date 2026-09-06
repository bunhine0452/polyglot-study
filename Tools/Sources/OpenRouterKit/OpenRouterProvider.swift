public import Foundation
public import LLMKit

/// OpenRouter 공급자.
///
/// OpenAI 호환 `chat/completions` 를 `URLSession` 으로 직접 친다 (Swift 공식 SDK 없음).
/// 구조는 셋으로 갈라져 있다.
///
/// - **조립** — ``OpenRouterRequestBuilder``. 순수 함수.
/// - **해석** — ``OpenRouterResponseParser``. 순수 함수.
/// - **왕복과 재시도** — 이 타입. 전송·수면·난수를 전부 주입받으므로 네트워크 없이도
///   429·5xx 재시도 경로를 통째로 태울 수 있다.
///
/// 재시도 루프가 공급자 안에 있는 것은 의도다. 로컬 백엔드에는 HTTP 백오프가 무의미한데
/// 프로토콜 쪽에 두면 모든 구현이 그 개념을 물려받는다. 원격 공급자가 둘이 되는 날
/// 이 루프를 데코레이터로 들어 올리면 된다.
///
/// 로그 sink 는 무엇을 주든 ``RedactingLog`` 로 감싸서 들고 있다. 이 공급자를 통해
/// 나가는 어떤 문자열도 API 키를 담을 수 없다.
public struct OpenRouterProvider: LLMProvider {
    public struct Configuration: Sendable {
        public var baseURL: URL
        public var retry: RetryPolicy
        public var requestTimeout: Duration
        public var attribution: OpenRouterRequestBuilder.Attribution
        /// 요청한 파라미터를 전부 지원하는 업스트림으로만 라우팅을 좁힐지. 기본 켜짐.
        public var requireParameters: Bool
        /// 캐시 친화 라우팅 키. 같은 값을 쓰는 요청이 같은 업스트림에 붙는다 —
        /// 프롬프트 캐시가 업스트림에 붙어 있으므로 이게 캐시 적중의 전제다.
        public var sessionID: String?
        /// 캐시 경계 표현 방식. 기본은 자동 — 대부분의 업스트림이 그쪽이고, 파트 배열을
        /// 못 받는 곳이 섞여 있다.
        public var promptCaching: PromptCachingMode
        /// 업스트림 고정. `session_id` 가 힌트라면 이쪽은 제약이다 — 실측상 힌트만으로는
        /// 캐시가 붙지 않았다 (``UpstreamPin`` 참조).
        public var upstreamPin: UpstreamPin?

        public init(
            baseURL: URL = OpenRouterRequestBuilder.defaultBaseURL,
            retry: RetryPolicy = RetryPolicy(),
            requestTimeout: Duration = .seconds(600),
            attribution: OpenRouterRequestBuilder.Attribution = .polyglotStudy,
            requireParameters: Bool = true,
            sessionID: String? = nil,
            promptCaching: PromptCachingMode = .automatic,
            upstreamPin: UpstreamPin? = nil
        ) {
            self.baseURL = baseURL
            self.retry = retry
            self.requestTimeout = requestTimeout
            self.attribution = attribution
            self.requireParameters = requireParameters
            self.sessionID = sessionID
            self.promptCaching = promptCaching
            self.upstreamPin = upstreamPin
        }
    }

    public let configuration: Configuration
    public let identity: ProviderIdentity

    private let apiKey: APIKey
    private let transport: any HTTPTransport
    private let sleeper: any Sleeper
    private let jitter: @Sendable () -> Double
    private let log: RedactingLog

    public init(
        apiKey: APIKey,
        model: ModelID,
        configuration: Configuration = Configuration(),
        transport: (any HTTPTransport)? = nil,
        sleeper: any Sleeper = TaskSleeper(),
        jitter: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) },
        log: any ClientLogSink = DiscardLog()
    ) {
        self.apiKey = apiKey
        self.identity = ProviderIdentity(provider: Self.providerName, model: model)
        self.configuration = configuration
        self.transport = transport ?? URLSessionTransport(timeout: configuration.requestTimeout)
        self.sleeper = sleeper
        self.jitter = jitter
        // 이음새를 여기 하나로 묶는다 — 감쌈을 우회할 방법이 없다.
        self.log = RedactingLog(redactor: Redactor(apiKey: apiKey), inner: log)
    }

    public static let providerName = "openrouter"

    /// 이 구현이 실제로 하는 것.
    ///
    /// **모델의 이론적 상한이 아니다.** `structuredOutputs` 를 선언할 수 있는 근거는
    /// ``Configuration/requireParameters`` 가 켜져 있어 구조화 출력을 지원하는
    /// 업스트림으로만 라우팅이 좁혀진다는 것이다 — 끄면 그 보장이 사라지므로 능력에서도
    /// 빠진다. 이 연결이 `CodeRunner.enforcedLimits` 와 같은 규율이다.
    ///
    /// `streaming` 이 없는 것은 OpenRouter 가 SSE 를 못 해서가 아니라 **이 구현이 안
    /// 하기 때문**이다.
    public var capabilities: ProviderCapabilities {
        // 사용량과 비용은 이제 모든 응답에 자동으로 실린다 — 켜고 끌 것이 없다.
        var capabilities: ProviderCapabilities = [
            .usageTokens, .usageCost, .samplingControls, .seededSampling, .reasoningEffort,
        ]
        if configuration.requireParameters {
            capabilities.insert(.structuredOutputs)
            capabilities.insert(.jsonObjectMode)
        }
        switch configuration.promptCaching {
        case .automatic: capabilities.insert(.automaticPromptCaching)
        case .explicitBreakpoints: capabilities.insert(.explicitPromptCaching)
        }
        return capabilities
    }

    private var builder: OpenRouterRequestBuilder {
        OpenRouterRequestBuilder(
            baseURL: configuration.baseURL,
            timeout: configuration.requestTimeout,
            attribution: configuration.attribution,
            requireParameters: configuration.requireParameters,
            sessionID: configuration.sessionID,
            promptCaching: configuration.promptCaching,
            upstreamPin: configuration.upstreamPin
        )
    }

    /// 보내기 직전의 `URLRequest`. `--dry-run` 과 감사 로그가 쓴다.
    public func makeURLRequest(for request: CompletionRequest) throws -> URLRequest {
        try builder.makeURLRequest(for: request, model: identity.model, apiKey: apiKey)
    }

    /// 사람이 읽을 요청 덤프. 키 자리에 자리표시자가 들어간다.
    public func redactedDump(of request: CompletionRequest) throws -> String {
        OpenRouterRequestBuilder.redactedDump(of: try makeURLRequest(for: request), apiKey: apiKey)
    }

    /// 왕복 한 번. 429·5xx·전송 오류에 지수 백오프로 재시도한다.
    ///
    /// 재시도하지 않는 것: 400·401·402·403·404·413(요청이 틀렸거나 지갑이 비었으므로
    /// 다시 걸어도 같다)과 거절.
    public func complete(_ request: CompletionRequest) async throws -> CompletionResponse {
        // 선언하지 않은 능력을 요구하면 전선을 타기 전에 막는다. 라우팅을 좁히지 않은
        // 채 구조화 출력을 보내면 그걸 모르는 업스트림이 조용히 산문을 돌려준다.
        if let required = request.responseFormat.requiredCapability, !capabilities.contains(required) {
            let error = LLMError.unsupported(required)
            log.write("[openrouter] \(error)")
            throw error
        }

        let urlRequest = try makeURLRequest(for: request)
        var lastError: LLMError?

        attempts: for attempt in 1...max(configuration.retry.maxAttempts, 1) {
            let outcome: Result<CompletionResponse, LLMError>
            do {
                let response = try await transport.send(urlRequest)
                log.write("[openrouter] 시도 \(attempt) → HTTP \(response.status) (\(response.body.count) bytes)")
                outcome = OpenRouterResponseParser.parse(
                    status: response.status,
                    headers: response.headers,
                    data: response.body
                )
            } catch let error as LLMError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.transport(String(describing: error)))
            }

            switch outcome {
            case .success(let response):
                log.write(
                    """
                    [openrouter] 성공 id=\(response.id) \
                    model=\(response.model) upstream=\(response.upstreamProvider ?? "?") \
                    finish=\(response.finishReason?.rawValue ?? "nil") \(response.usage.logLine)
                    """
                )
                return response

            case .failure(let error):
                lastError = error
                // 다시 걸어도 같은 결과인 오류는 그대로 올려 보낸다 — 감싸면 원인이 흐려진다.
                guard error.isRetryable else {
                    log.write("[openrouter] 시도 \(attempt) 실패 (재시도 안 함) — \(error)")
                    throw error
                }
                // 마지막 시도였다면 루프를 빠져나가 retriesExhausted 로 끝낸다.
                // (레이블이 없는 `break` 는 switch 만 빠져나가므로 반드시 필요하다.)
                guard attempt < configuration.retry.maxAttempts else {
                    log.write("[openrouter] 시도 \(attempt) 실패 (마지막) — \(error)")
                    break attempts
                }
                let delay = configuration.retry.delay(
                    afterAttempt: attempt,
                    retryAfter: error.retryAfter,
                    jitterUnit: jitter()
                )
                log.write(
                    "[openrouter] 시도 \(attempt) 실패 — \(error) / "
                        + "\(String(format: "%.2f", delay.asTimeInterval))초 뒤 재시도"
                )
                try await sleeper.sleep(for: delay)
            }
        }

        let error = LLMError.retriesExhausted(
            attempts: configuration.retry.maxAttempts,
            last: lastError ?? .malformedResponse("알 수 없는 실패")
        )
        log.write("[openrouter] \(error)")
        throw error
    }
}
