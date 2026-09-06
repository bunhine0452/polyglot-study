public import Foundation

/// JSON-RPC 2.0 의 요청 id. **정수만 쓰는 게 아니다** — 스펙이 문자열도 허용하고,
/// 서버가 클라이언트에게 보내는 요청은 문자열 id 를 쓰는 구현이 있다.
/// 우리가 만드는 id 는 항상 정수지만, 받는 쪽은 둘 다 받아야 한다.
public enum JSONRPCID: Hashable, Sendable, Codable, CustomStringConvertible {
    case number(Int)
    case string(String)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }

    public var description: String {
        switch self {
        case .number(let value): "\(value)"
        case .string(let value): value
        }
    }
}

/// 서버가 돌려준 오류. `code` 는 JSON-RPC 표준 코드이거나 LSP 확장 코드다.
public struct JSONRPCError: Error, Hashable, Sendable, Codable, CustomStringConvertible {
    /// LSP 가 정의한 "클라이언트가 취소한 요청" 코드. 우리가 `$/cancelRequest` 를 보낸 뒤
    /// 서버가 이 코드로 답한다 — 실측으로 확인했다(sourcekit-lsp, Xcode 26.6).
    public static let requestCancelled = -32800
    /// 서버가 내용이 바뀌어 결과를 버렸다는 뜻. 재요청하면 된다.
    public static let contentModified = -32801
    public static let methodNotFound = -32601

    public var code: Int
    public var message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    public var isCancellation: Bool {
        code == Self.requestCancelled || code == Self.contentModified
    }

    public var description: String { "JSON-RPC \(code): \(message)" }
}

/// 서버에서 들어온 메시지 한 건을 **분류만** 한 것.
///
/// `result`·`params` 를 여기서 타입으로 풀지 않는 것은 의도적이다. 메서드마다 모양이
/// 달라 하나의 열거형으로 묶으면 LSP 스펙 전체를 이 파일에 옮겨 적어야 한다.
/// 대신 원본 바이트를 들고 있다가 **호출자가 아는 타입으로** 디코드한다.
public enum JSONRPCIncoming: Hashable, Sendable {
    /// 우리 요청에 대한 성공 응답. `payload` 는 메시지 전체(봉투 포함)다.
    case response(id: JSONRPCID, payload: Data)
    /// 우리 요청에 대한 실패 응답.
    case failure(id: JSONRPCID, error: JSONRPCError)
    /// 서버발 알림 (`textDocument/publishDiagnostics` 등). 답할 필요가 없다.
    case notification(method: String, payload: Data)
    /// 서버발 요청. **답하지 않으면 서버가 기다린다.**
    case serverRequest(id: JSONRPCID, method: String, payload: Data)
}

/// 메시지 봉투. 분류에 필요한 필드만 본다.
private struct JSONRPCEnvelope: Decodable {
    var id: JSONRPCID?
    var method: String?
    var error: JSONRPCError?

    private enum CodingKeys: String, CodingKey {
        case id, method, error
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 셋 다 `decodeIfPresent` 다. `result: null` 은 **유효한 성공 응답**이고
        // (`shutdown` 이 그렇다) 그 경우 여기서 볼 것은 id 뿐이다.
        id = try container.decodeIfPresent(JSONRPCID.self, forKey: .id)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        error = try container.decodeIfPresent(JSONRPCError.self, forKey: .error)
    }
}

public enum JSONRPCDecodingError: Error, Hashable, Sendable, CustomStringConvertible {
    case notJSON(String)
    case unclassifiable

    public var description: String {
        switch self {
        case .notJSON(let reason): "JSON-RPC 메시지를 해석할 수 없다: \(reason)"
        case .unclassifiable: "id 도 method 도 없는 JSON-RPC 메시지다."
        }
    }
}

public enum JSONRPCDecoder {
    /// 메시지 하나를 네 갈래로 분류한다. **프로세스가 없다** — 바이트만 본다.
    public static func classify(_ payload: Data) throws -> JSONRPCIncoming {
        let envelope: JSONRPCEnvelope
        do {
            envelope = try JSONDecoder().decode(JSONRPCEnvelope.self, from: payload)
        } catch {
            throw JSONRPCDecodingError.notJSON("\(error)")
        }

        switch (envelope.id, envelope.method) {
        case (let id?, let method?):
            // id 와 method 가 둘 다 있으면 서버발 요청이다.
            return .serverRequest(id: id, method: method, payload: payload)
        case (let id?, nil):
            if let error = envelope.error { return .failure(id: id, error: error) }
            return .response(id: id, payload: payload)
        case (nil, let method?):
            return .notification(method: method, payload: payload)
        case (nil, nil):
            throw JSONRPCDecodingError.unclassifiable
        }
    }

    /// 응답 봉투에서 `result` 를 원하는 타입으로 꺼낸다.
    public static func result<Value: Decodable>(_ type: Value.Type, from payload: Data) throws -> Value {
        try JSONDecoder().decode(ResultEnvelope<Value>.self, from: payload).result
    }

    /// 알림 봉투에서 `params` 를 원하는 타입으로 꺼낸다.
    public static func params<Value: Decodable>(_ type: Value.Type, from payload: Data) throws -> Value {
        try JSONDecoder().decode(ParamsEnvelope<Value>.self, from: payload).params
    }

    private struct ResultEnvelope<Value: Decodable>: Decodable {
        var result: Value
    }

    private struct ParamsEnvelope<Value: Decodable>: Decodable {
        var params: Value
    }
}

public enum JSONRPCEncoder {
    /// 항상 같은 바이트가 나오도록 키를 정렬한다. 프레이밍 테스트가 바이트로 비교할 수
    /// 있어야 하고, 로그를 눈으로 비교할 때도 정렬돼 있는 편이 낫다.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func request(
        id: JSONRPCID,
        method: String,
        params: some Encodable & Sendable
    ) throws -> Data {
        try makeEncoder().encode(Request(id: id, method: method, params: params))
    }

    public static func request(id: JSONRPCID, method: String) throws -> Data {
        try makeEncoder().encode(ParameterlessRequest(id: id, method: method))
    }

    public static func notification(
        method: String,
        params: some Encodable & Sendable
    ) throws -> Data {
        try makeEncoder().encode(Notification(method: method, params: params))
    }

    public static func notification(method: String) throws -> Data {
        try makeEncoder().encode(ParameterlessNotification(method: method))
    }

    /// 서버발 요청에 대한 성공 응답. LSP 에서 `result: null` 로 답해도 되는 요청들
    /// (`client/registerCapability` 등)에 쓴다.
    public static func nullResponse(id: JSONRPCID) throws -> Data {
        try makeEncoder().encode(NullResponse(id: id))
    }

    public static func errorResponse(id: JSONRPCID, error: JSONRPCError) throws -> Data {
        try makeEncoder().encode(ErrorResponse(id: id, error: error))
    }

    private struct Request<Params: Encodable & Sendable>: Encodable {
        let jsonrpc = "2.0"
        var id: JSONRPCID
        var method: String
        var params: Params
    }

    private struct ParameterlessRequest: Encodable {
        let jsonrpc = "2.0"
        var id: JSONRPCID
        var method: String
    }

    private struct Notification<Params: Encodable & Sendable>: Encodable {
        let jsonrpc = "2.0"
        var method: String
        var params: Params
    }

    private struct ParameterlessNotification: Encodable {
        let jsonrpc = "2.0"
        var method: String
    }

    private struct NullResponse: Encodable {
        let jsonrpc = "2.0"
        var id: JSONRPCID
        var result: String? = nil

        private enum CodingKeys: String, CodingKey { case jsonrpc, id, result }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(jsonrpc, forKey: .jsonrpc)
            try container.encode(id, forKey: .id)
            // `encodeIfPresent` 는 키를 통째로 뺀다. 여기서는 **명시적 null** 이어야 한다.
            try container.encodeNil(forKey: .result)
        }
    }

    private struct ErrorResponse: Encodable {
        let jsonrpc = "2.0"
        var id: JSONRPCID
        var error: JSONRPCError
    }
}
