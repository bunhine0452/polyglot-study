public import AnthropicKit
public import Foundation

/// 미리 정해 둔 응답을 순서대로 돌려주는 전송. 재시도·백오프 검증용.
public final class StubTransport: HTTPTransport, @unchecked Sendable {
    public enum Step: Sendable {
        case response(HTTPResponse)
        case failure(AnthropicError)
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
            throw AnthropicError.transport("StubTransport: 준비된 응답을 다 썼습니다.")
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
