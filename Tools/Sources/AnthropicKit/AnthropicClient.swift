public import Foundation

/// Anthropic Messages API 클라이언트.
///
/// Swift 에는 공식 SDK 가 없으므로 `URLSession` 으로 `/v1/messages` 를 직접 친다.
/// 구조는 셋으로 갈라져 있다.
///
/// - **조립** — ``RequestBuilder``. 순수 함수.
/// - **해석** — ``ResponseParser``. 순수 함수.
/// - **왕복과 재시도** — 이 타입. 전송·수면·난수를 전부 주입받으므로 네트워크 없이도
///   429·529 재시도 경로를 통째로 태울 수 있다.
///
/// 로그 sink 는 무엇을 주든 ``RedactingLog`` 로 감싸서 들고 있다. 클라이언트를 통해
/// 나가는 어떤 문자열도 API 키를 담을 수 없다.
public struct AnthropicClient: Sendable {
    public struct Configuration: Sendable {
        public var baseURL: URL
        public var retry: RetryPolicy
        public var requestTimeout: Duration
        /// 거절 시 서버측 대체 모델 라우팅. 켜 두는 것이 기본이다 — 거절 하나로
        /// 트랙 생성 전체가 멈추지 않게. 끄려면 `nil`.
        public var fallbacks: Fallbacks?
        /// 위 `fallbacks` 가 요구하는 것 외에 추가로 붙일 베타 플래그.
        public var extraBetas: [String]

        public init(
            baseURL: URL = RequestBuilder.defaultBaseURL,
            retry: RetryPolicy = RetryPolicy(),
            requestTimeout: Duration = .seconds(600),
            fallbacks: Fallbacks? = .default,
            extraBetas: [String] = []
        ) {
            self.baseURL = baseURL
            self.retry = retry
            self.requestTimeout = requestTimeout
            self.fallbacks = fallbacks
            self.extraBetas = extraBetas
        }
    }

    public let configuration: Configuration

    private let apiKey: APIKey
    private let transport: any HTTPTransport
    private let sleeper: any Sleeper
    private let jitter: @Sendable () -> Double
    private let log: RedactingLog

    public init(
        apiKey: APIKey,
        configuration: Configuration = Configuration(),
        transport: (any HTTPTransport)? = nil,
        sleeper: any Sleeper = TaskSleeper(),
        jitter: @escaping @Sendable () -> Double = { Double.random(in: 0..<1) },
        log: any ClientLogSink = DiscardLog()
    ) {
        self.apiKey = apiKey
        self.configuration = configuration
        self.transport = transport ?? URLSessionTransport(timeout: configuration.requestTimeout)
        self.sleeper = sleeper
        self.jitter = jitter
        // 이음새를 여기 하나로 묶는다 — 감쌈을 우회할 방법이 없다.
        self.log = RedactingLog(redactor: Redactor(apiKey: apiKey), inner: log)
    }

    /// 이 클라이언트가 붙일 베타 플래그.
    public var betas: [String] {
        var betas = configuration.extraBetas
        if let fallbacks = configuration.fallbacks { betas.append(fallbacks.betaFlag) }
        return betas
    }

    /// 요청에 설정의 기본값을 채운다. 지금은 `fallbacks` 하나뿐 — 호출자가 명시했으면
    /// 그대로 둔다.
    public func prepare(_ request: MessagesRequest) -> MessagesRequest {
        var prepared = request
        if prepared.fallbacks == nil { prepared.fallbacks = configuration.fallbacks }
        return prepared
    }

    /// 보내기 직전의 `URLRequest`. `--dry-run` 과 감사 로그가 쓴다.
    public func makeURLRequest(for request: MessagesRequest) throws -> URLRequest {
        let builder = RequestBuilder(baseURL: configuration.baseURL, timeout: configuration.requestTimeout)
        return try builder.makeURLRequest(
            endpoint: .messages,
            body: prepare(request),
            apiKey: apiKey,
            betas: betas
        )
    }

    /// 왕복 한 번. 429·529·5xx·전송 오류에 지수 백오프로 재시도한다.
    ///
    /// 재시도하지 않는 것: 400·401·403·404·413(요청이 틀린 것이므로 다시 걸어도 같다)과
    /// 거절(서버가 이미 대체 모델까지 태워 본 결과다).
    public func send(_ request: MessagesRequest) async throws -> MessagesResponse {
        let urlRequest = try makeURLRequest(for: request)
        var lastError: AnthropicError?

        attempts: for attempt in 1...max(configuration.retry.maxAttempts, 1) {
            let outcome: Result<MessagesResponse, AnthropicError>
            do {
                let response = try await transport.send(urlRequest)
                log.write("[anthropic] 시도 \(attempt) → HTTP \(response.status) (\(response.body.count) bytes)")
                outcome = ResponseParser.parse(
                    status: response.status,
                    headers: response.headers,
                    data: response.body
                )
            } catch let error as AnthropicError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(.transport(String(describing: error)))
            }

            switch outcome {
            case .success(let response):
                if response.stopReason == .refusal {
                    let error = AnthropicError.refused(
                        category: response.stopDetails?.category,
                        explanation: response.stopDetails?.explanation
                    )
                    log.write("[anthropic] \(error)")
                    throw error
                }
                log.write(
                    """
                    [anthropic] 성공 id=\(response.id) model=\(response.model) \
                    stop=\(response.stopReason?.rawValue ?? "nil") \
                    in=\(response.usage.inputTokens) out=\(response.usage.outputTokens) \
                    cache_read=\(response.usage.cacheReadInputTokens.map(String.init) ?? "0")
                    """
                )
                return response

            case .failure(let error):
                lastError = error
                // 다시 걸어도 같은 결과인 오류는 그대로 올려 보낸다 — 감싸면 원인이 흐려진다.
                guard error.isRetryable else {
                    log.write("[anthropic] 시도 \(attempt) 실패 (재시도 안 함) — \(error)")
                    throw error
                }
                // 마지막 시도였다면 루프를 빠져나가 retriesExhausted 로 끝낸다.
                // (레이블이 없는 `break` 는 switch 만 빠져나가므로 반드시 필요하다.)
                guard attempt < configuration.retry.maxAttempts else {
                    log.write("[anthropic] 시도 \(attempt) 실패 (마지막) — \(error)")
                    break attempts
                }
                let delay = configuration.retry.delay(
                    afterAttempt: attempt,
                    retryAfter: error.retryAfter,
                    jitterUnit: jitter()
                )
                log.write(
                    "[anthropic] 시도 \(attempt) 실패 — \(error) / "
                        + "\(String(format: "%.2f", delay.asTimeInterval))초 뒤 재시도"
                )
                try await sleeper.sleep(for: delay)
            }
        }

        let error = AnthropicError.retriesExhausted(
            attempts: configuration.retry.maxAttempts,
            last: lastError ?? .malformedResponse("알 수 없는 실패")
        )
        log.write("[anthropic] \(error)")
        throw error
    }
}
