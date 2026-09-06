public import Foundation

/// HTTP 왕복 한 번. 이 프로토콜이 테스트의 이음새다 — 스텁을 끼우면 네트워크 없이
/// 재시도·백오프·에러 매핑을 전부 검증할 수 있다.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

public struct HTTPResponse: Sendable, Hashable {
    public let status: Int
    /// 키는 전부 소문자로 눕혀 둔다 — 대소문자 때문에 `retry-after` 를 놓치지 않게.
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = Dictionary(
            headers.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { _, last in last }
        )
        self.body = body
    }
}

/// 실제 전송. `URLSession` 을 쓴다 — 이 공급자들에는 Swift 공식 SDK 가 없다.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    /// 기본 세션. 비스트리밍 요청이라 서버가 응답을 다 만들 때까지 기다려야 하므로
    /// 타임아웃을 넉넉히 잡는다.
    public init(timeout: Duration = .seconds(600)) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout.asTimeInterval
        configuration.timeoutIntervalForResource = timeout.asTimeInterval
        // 프록시 캐시가 오류 응답을 들고 있으면 재시도가 무의미해진다.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.init(session: URLSession(configuration: configuration))
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // `URLError` 의 설명에는 URL 만 담기고 헤더는 담기지 않는다. 그래도 로그로
            // 나갈 때는 `RedactingLog` 를 한 번 더 통과한다.
            throw LLMError.transport(String(describing: error))
        }
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.malformedResponse("HTTP 응답이 아닙니다: \(type(of: response))")
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            guard let key = key as? String else { continue }
            headers[key] = String(describing: value)
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: data)
    }
}
