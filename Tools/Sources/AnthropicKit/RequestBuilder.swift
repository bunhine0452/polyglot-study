public import Foundation

/// 호출할 엔드포인트.
public enum AnthropicEndpoint: Sendable, Hashable {
    case messages
    /// 트랙 전체를 팬아웃할 때 쓸 자리 (`{#lessongen-batch-fanout}`, 입출력 50% 할인).
    /// 아직 아무도 호출하지 않는다.
    case messageBatches

    public var path: String {
        switch self {
        case .messages: "/v1/messages"
        case .messageBatches: "/v1/messages/batches"
        }
    }
}

/// 요청 조립. **순수 함수다** — 네트워크도 시계도 건드리지 않으므로 키 없이 전량 검증된다.
public struct RequestBuilder: Sendable {
    public static let anthropicVersion = "2023-06-01"
    public static let defaultBaseURL = URL(string: "https://api.anthropic.com")!

    public var baseURL: URL
    public var timeout: Duration

    public init(baseURL: URL = RequestBuilder.defaultBaseURL, timeout: Duration = .seconds(600)) {
        self.baseURL = baseURL
        self.timeout = timeout
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
    public func url(for endpoint: AnthropicEndpoint) throws -> URL {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + endpoint.path) else {
            throw AnthropicError.malformedResponse("엔드포인트 URL 을 만들 수 없습니다: \(base)\(endpoint.path)")
        }
        return url
    }

    /// 헤더까지 붙은 `URLRequest` 를 만든다. 키는 여기서만 원문으로 읽힌다.
    public func makeURLRequest(
        endpoint: AnthropicEndpoint,
        body: some Encodable,
        apiKey: APIKey,
        betas: [String] = []
    ) throws -> URLRequest {
        var request = URLRequest(url: try url(for: endpoint))
        request.httpMethod = "POST"
        request.httpBody = try Self.encodeBody(body)
        request.timeoutInterval = timeout.asTimeInterval
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey.rawValue, forHTTPHeaderField: "x-api-key")
        if !betas.isEmpty {
            request.setValue(betas.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }
        return request
    }

    /// 사람이 읽을 요청 덤프. **키 자리에 자리표시자가 들어간다.**
    ///
    /// `--dry-run` 과 감사 로그가 쓴다. `URLRequest` 를 통째로 문자열화하면 헤더가 그대로
    /// 나오므로, 덤프는 반드시 이 함수를 거쳐야 한다.
    public static func redactedDump(of request: URLRequest) -> String {
        var lines: [String] = []
        lines.append("\(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        let headers = request.allHTTPHeaderFields ?? [:]
        for name in headers.keys.sorted() {
            let value = name.lowercased() == "x-api-key" ? APIKey.placeholder : headers[name]!
            lines.append("\(name): \(value)")
        }
        lines.append("")
        lines.append(String(decoding: request.httpBody ?? Data(), as: UTF8.self))
        return lines.joined(separator: "\n")
    }
}
