public import Foundation
public import LLMKit

/// 미리 정해 둔 응답을 순서대로 돌려주는 전송. 재시도·백오프 검증용.
public final class StubTransport: HTTPTransport, @unchecked Sendable {
    public enum Step: Sendable {
        case response(HTTPResponse)
        case failure(LLMError)
    }

    private let lock = NSLock()
    private var steps: [Step]
    private var recorded: [URLRequest] = []

    public init(_ steps: [Step]) {
        self.steps = steps
    }

    public convenience init(status: Int, headers: [String: String] = [:], body: Data) {
        self.init([.response(HTTPResponse(status: status, headers: headers, body: body))])
    }

    /// 지금까지 받은 요청. 헤더 검증에 쓴다.
    public var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    public var remainingStepCount: Int {
        lock.withLock { steps.count }
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let step: Step? = lock.withLock {
            recorded.append(request)
            return steps.isEmpty ? nil : steps.removeFirst()
        }
        guard let step else {
            throw LLMError.transport("StubTransport: 준비된 응답을 다 썼습니다.")
        }
        switch step {
        case .response(let response): return response
        case .failure(let error): throw error
        }
    }
}

/// 실제로 자지 않고 요청받은 대기 시간만 적어 둔다.
public final class RecordingSleeper: Sleeper, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Duration] = []

    public init() {}

    public var durations: [Duration] {
        lock.withLock { recorded }
    }

    public func sleep(for duration: Duration) async throws {
        lock.withLock { recorded.append(duration) }
    }
}

/// 나간 로그를 전부 붙잡아 둔다. 키 유출 검사가 이걸 훑는다.
public final class CapturingLog: ClientLogSink, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    public init() {}

    public var lines: [String] {
        lock.withLock { recorded }
    }

    public var joined: String {
        lines.joined(separator: "\n")
    }

    public func write(_ line: String) {
        lock.withLock { recorded.append(line) }
    }
}

/// 네트워크가 아예 없는 ``LLMProvider``.
///
/// ``ProviderContract`` 를 태우는 **두 번째 구현**이라는 데 의미가 있다 — 계약이 한
/// 구현에만 맞춰 쓰이면 계약이 아니라 그 구현의 사본이다. 도메인 코드(개요 생성기)의
/// 테스트도 HTTP 를 세우지 않고 이걸 쓴다.
public final class FakeProvider: LLMProvider, @unchecked Sendable {
    public enum Step: Sendable {
        case success(CompletionResponse)
        case failure(LLMError)
    }

    public let capabilities: ProviderCapabilities
    public let identity: ProviderIdentity

    private let lock = NSLock()
    private var steps: [Step]
    private var recorded: [CompletionRequest] = []

    public init(
        capabilities: ProviderCapabilities = [.structuredOutputs, .jsonObjectMode, .usageTokens],
        model: ModelID = ModelID(Fixtures.testModel),
        steps: [Step]
    ) {
        self.capabilities = capabilities
        self.identity = ProviderIdentity(provider: "fake", model: model)
        self.steps = steps
    }

    /// 같은 텍스트를 몇 번이든 돌려주는 공급자.
    public convenience init(
        capabilities: ProviderCapabilities = [.structuredOutputs, .jsonObjectMode, .usageTokens],
        alwaysReturning text: String,
        finishReason: FinishReason = .stop
    ) {
        self.init(
            capabilities: capabilities,
            steps: [
                .success(
                    CompletionResponse(
                        id: "fake-1",
                        model: Fixtures.testModel,
                        upstreamProvider: "fake",
                        text: text,
                        finishReason: finishReason,
                        usage: TokenUsage(inputTokens: 100, outputTokens: 50)
                    )
                )
            ]
        )
        repeating = true
    }

    private var repeating = false

    public var requests: [CompletionRequest] {
        lock.withLock { recorded }
    }

    public func complete(_ request: CompletionRequest) async throws -> CompletionResponse {
        if let required = request.responseFormat.requiredCapability, !capabilities.contains(required) {
            throw LLMError.unsupported(required)
        }
        let step: Step? = lock.withLock {
            recorded.append(request)
            guard !steps.isEmpty else { return nil }
            return repeating ? steps[0] : steps.removeFirst()
        }
        guard let step else { throw LLMError.provider("FakeProvider: 준비된 응답을 다 썼습니다.") }
        switch step {
        case .success(let response): return response
        case .failure(let error): throw error
        }
    }
}
