import AnthropicKit
import Foundation
import TestSupport
import Testing

@Suite("API 키 취급")
struct APIKeyHandlingTests {
    private let key = Fixtures.fakeAPIKeyString

    @Test("환경변수 하나에서만 읽는다")
    func readsOnlyTheEnvironmentVariable() throws {
        let loaded = try APIKey.fromEnvironment(["ANTHROPIC_API_KEY": key])
        #expect(loaded.rawValue == key)

        // 비슷한 이름의 다른 변수는 쳐다보지 않는다.
        #expect(throws: APIKeyError.notSet) {
            try APIKey.fromEnvironment([
                "ANTHROPIC_KEY": key,
                "CLAUDE_API_KEY": key,
                "ANTHROPIC_AUTH_TOKEN": key,
            ])
        }
    }

    @Test("주변 공백은 잘라 내고 빈 값은 거부한다")
    func trimsAndRejectsEmpty() throws {
        #expect(try APIKey.fromEnvironment(["ANTHROPIC_API_KEY": "  \(key)\n"]).rawValue == key)
        #expect(throws: APIKeyError.empty) {
            try APIKey.fromEnvironment(["ANTHROPIC_API_KEY": "   "])
        }
    }

    @Test("헤더 인젝션이 되는 제어문자를 거부한다")
    func rejectsControlCharacters() {
        #expect(throws: APIKeyError.containsControlCharacter) {
            try APIKey(rawValue: "sk-ant-abc\r\nx-evil: 1")
        }
    }

    @Test("키를 문자열로 찍어도 값이 나오지 않는다")
    func stringConversionsAreSafe() throws {
        let apiKey = try APIKey(rawValue: key)
        #expect("\(apiKey)" == APIKey.placeholder)
        #expect(String(describing: apiKey) == APIKey.placeholder)
        #expect(String(reflecting: apiKey) == APIKey.placeholder)
        #expect(!"\(apiKey)".contains(key))
    }

    @Test("키 미설정 안내에 export 방법이 담기고 값은 담기지 않는다")
    func guidanceMessage() {
        let message = String(describing: APIKeyError.notSet)
        #expect(message.contains("ANTHROPIC_API_KEY"))
        #expect(message.contains("export"))
        #expect(!message.contains(key))
    }

    @Test("Redactor 가 알고 있는 키를 지운다")
    func redactsKnownSecret() throws {
        let redactor = Redactor(apiKey: try APIKey(rawValue: key))
        let redacted = redactor.redact("x-api-key: \(key) 요청 실패")
        #expect(!redacted.contains(key))
        #expect(redacted == "x-api-key: \(APIKey.placeholder) 요청 실패")
    }

    @Test("모르는 sk-ant- 토큰도 함께 가린다")
    func redactsUnknownKeyLikeTokens() {
        let redactor = Redactor()
        let other = "sk-ant-api03-SOMEONEELSES-KEY_123"
        let redacted = redactor.redact("본문에 \(other) 가 섞여 돌아왔다.")
        #expect(!redacted.contains(other))
        #expect(redacted == "본문에 \(APIKey.placeholder) 가 섞여 돌아왔다.")
    }

    @Test("가릴 것이 없는 문자열은 그대로 둔다")
    func leavesCleanTextAlone() {
        let text = "429 레이트 리밋 — rate_limit_error: 느려 [request_id: req_01]"
        #expect(Redactor(secrets: [Fixtures.fakeAPIKeyString]).redact(text) == text)
    }

    @Test("요청 덤프의 x-api-key 자리가 자리표시자다")
    func redactedDumpMasksHeader() throws {
        let apiKey = try APIKey(rawValue: key)
        let urlRequest = try RequestBuilder().makeURLRequest(
            endpoint: .messages,
            body: MessagesRequest(model: .opus5, maxTokens: 10, messages: [.user("x")]),
            apiKey: apiKey
        )
        // 실제 URLRequest 에는 키가 있다 — 전선에 실려야 하니까.
        #expect(urlRequest.value(forHTTPHeaderField: "x-api-key") == key)
        // 덤프에는 없다.
        let dump = RequestBuilder.redactedDump(of: urlRequest)
        #expect(!dump.contains(key))
        #expect(dump.contains("x-api-key: \(APIKey.placeholder)"))
    }

    // MARK: - 실행 로그 전수 검사

    @Test("클라이언트가 뱉은 로그 전수에 키가 0건이다")
    func clientLogsNeverLeakTheKey() async throws {
        let log = CapturingLog()
        let transport = StubTransport([
            .response(
                HTTPResponse(
                    status: 429,
                    headers: ["retry-after": "1"],
                    body: Fixtures.errorJSON(type: "rate_limit_error", message: "느려")
                )
            ),
            .response(
                HTTPResponse(status: 529, body: Fixtures.errorJSON(type: "overloaded_error", message: "과부하"))
            ),
            .response(HTTPResponse(status: 200, body: Fixtures.messagesResponseJSON(text: "결과"))),
        ])
        let client = try AnthropicClient(
            apiKey: APIKey(rawValue: key),
            transport: transport,
            sleeper: RecordingSleeper(),
            jitter: { 0.5 },
            log: log
        )

        _ = try await client.send(MessagesRequest(model: .opus5, maxTokens: 10, messages: [.user("x")]))

        // 성공·재시도·오류 세 종류가 다 찍혔는지 먼저 확인한다 — 로그가 비어 있어서
        // "0건" 인 것은 증명이 아니다.
        #expect(log.lines.count >= 5)
        #expect(log.joined.contains("재시도"))
        #expect(log.joined.contains("성공"))

        for line in log.lines {
            #expect(!line.contains(key), "로그에 키가 실렸습니다: \(line)")
            #expect(!line.contains("sk-ant-"), "로그에 키처럼 생긴 토큰이 있습니다: \(line)")
        }
    }

    @Test("누가 일부러 키를 로그에 넣어도 지워진다")
    func sinkCannotBeBypassed() async throws {
        let log = CapturingLog()
        let transport = StubTransport(
            status: 401,
            // 서버가 키를 되돌려주는 최악의 경우를 흉내 낸다.
            body: Fixtures.errorJSON(type: "authentication_error", message: "invalid x-api-key: \(key)")
        )
        let client = try AnthropicClient(
            apiKey: APIKey(rawValue: key),
            transport: transport,
            sleeper: RecordingSleeper(),
            log: log
        )

        await #expect(throws: AnthropicError.self) {
            try await client.send(MessagesRequest(model: .opus5, maxTokens: 10, messages: [.user("x")]))
        }
        #expect(!log.joined.isEmpty)
        #expect(!log.joined.contains(key))
        #expect(log.joined.contains(APIKey.placeholder))
    }

    @Test("에러 설명을 그대로 찍어도 Redactor 를 거치면 키가 없다")
    func errorDescriptionsAreRedactable() throws {
        let redactor = Redactor(apiKey: try APIKey(rawValue: key))
        let errors: [AnthropicError] = [
            .authentication(APIErrorBody(type: "authentication_error", message: "bad key \(key)")),
            .transport("connection failed for \(key)"),
            .unexpectedStatus(status: 502, body: "gateway saw \(key)"),
            .malformedResponse("payload had \(key)"),
            .retriesExhausted(attempts: 3, last: .transport("last saw \(key)")),
        ]
        for error in errors {
            let redacted = redactor.redact(String(describing: error))
            #expect(!redacted.contains(key), "\(error)")
            #expect(redacted.contains(APIKey.placeholder))
        }
    }

    @Test("APIKey 는 Encodable 이 아니다 — 설정 파일에 실릴 수 없다")
    func apiKeyIsNotEncodable() throws {
        // 컴파일 타임 보장을 런타임에서 한 번 더 확인한다. 누가 Codable 을 붙이면
        // 이 테스트가 빨개진다.
        #expect(!(try APIKey(rawValue: key) is any Encodable))
        #expect(!(try APIKey(rawValue: key) is any Decodable))
    }
}
