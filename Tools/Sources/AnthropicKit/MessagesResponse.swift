/// `POST /v1/messages` 성공 응답.
public struct MessagesResponse: Decodable, Sendable, Hashable {
    public let id: String
    public let model: String
    public let content: [ResponseContentBlock]
    public let stopReason: StopReason?
    /// `stopReason == .refusal` 일 때만 채워진다. 나머지 경우는 항상 `nil`.
    public let stopDetails: StopDetails?
    public let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id, model, content, usage
        case stopReason = "stop_reason"
        case stopDetails = "stop_details"
    }

    /// 텍스트 블록만 이어 붙인 것. 사고 블록은 제외한다.
    public var text: String {
        content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
    }
}

public struct ResponseContentBlock: Decodable, Sendable, Hashable {
    public let type: String
    /// `type == "text"` 일 때.
    public let text: String?
    /// `type == "thinking"` 일 때. Opus 5 기본 설정(`display: omitted`)에서는 빈 문자열.
    public let thinking: String?
}

/// 종료 사유. 새 값이 늘어도 디코딩이 깨지지 않도록 열거형이 아니라 래퍼다.
public struct StopReason: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public static let endTurn = StopReason("end_turn")
    /// 출력이 `max_tokens` 에 걸려 잘렸다. 구조화 출력이라면 JSON 이 깨져 있다.
    public static let maxTokens = StopReason("max_tokens")
    public static let toolUse = StopReason("tool_use")
    public static let pauseTurn = StopReason("pause_turn")
    public static let stopSequence = StopReason("stop_sequence")
    /// 안전 분류기가 거절했다. HTTP 는 200 이므로 상태 코드로는 안 잡힌다.
    public static let refusal = StopReason("refusal")
}

public struct StopDetails: Decodable, Sendable, Hashable {
    public let type: String?
    /// 열린 집합이라 문자열 그대로 둔다.
    public let category: String?
    public let explanation: String?
}

public struct Usage: Decodable, Sendable, Hashable {
    public let inputTokens: Int
    public let outputTokens: Int
    /// 캐시에 새로 쓴 토큰.
    public let cacheCreationInputTokens: Int?
    /// 캐시에서 읽은 토큰. `{#lessongen-prompt-caching}` 의 검증 지점 — 2회차부터
    /// 여기가 0 이 아니어야 한다.
    public let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

/// 오류 응답 본문 `{"type":"error","error":{"type":..,"message":..}}`.
public struct APIErrorBody: Decodable, Sendable, Hashable {
    public let type: String
    public let message: String
    public let requestID: String?

    public init(type: String, message: String, requestID: String? = nil) {
        self.type = type
        self.message = message
        self.requestID = requestID
    }

    enum RootKeys: String, CodingKey {
        case error
        case requestID = "request_id"
    }

    enum ErrorKeys: String, CodingKey { case type, message }

    public init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let error = try root.nestedContainer(keyedBy: ErrorKeys.self, forKey: .error)
        self.type = try error.decode(String.self, forKey: .type)
        self.message = try error.decode(String.self, forKey: .message)
        self.requestID = try root.decodeIfPresent(String.self, forKey: .requestID)
    }
}
