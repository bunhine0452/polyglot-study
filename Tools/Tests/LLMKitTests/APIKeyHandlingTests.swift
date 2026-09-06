import Foundation
import LLMKit
import TestSupport
import Testing

@Suite("API 키 취급")
struct APIKeyHandlingTests {
    private let key = Fixtures.fakeAPIKeyString

    @Test("환경변수 하나에서만 읽는다")
    func readsOnlyTheEnvironmentVariable() throws {
        let loaded = try APIKey.fromEnvironment(["OPENROUTER_API_KEY": key])
        #expect(loaded.rawValue == key)

        // 비슷한 이름의 다른 변수는 쳐다보지 않는다.
        #expect(throws: APIKeyError.notSet(.openRouter)) {
            try APIKey.fromEnvironment([
                "OPENROUTER_KEY": key,
                "OPEN_ROUTER_API_KEY": key,
                "OPENROUTER_API_TOKEN": key,
                // 옛 공급자의 변수가 셸에 남아 있어도 쓰지 않는다.
                "ANTHROPIC_API_KEY": key,
            ])
        }
    }

    @Test("주변 공백은 잘라 내고 빈 값은 거부한다")
    func trimsAndRejectsEmpty() throws {
        #expect(try APIKey.fromEnvironment(["OPENROUTER_API_KEY": "  \(key)\n"]).rawValue == key)
        #expect(throws: APIKeyError.empty(.openRouter)) {
            try APIKey.fromEnvironment(["OPENROUTER_API_KEY": "   "])
        }
    }

    @Test("헤더 인젝션이 되는 제어문자를 거부한다")
    func rejectsControlCharacters() {
        #expect(throws: APIKeyError.containsControlCharacter(.openRouter)) {
            try APIKey(rawValue: "sk-or-v1-abc\r\nx-evil: 1")
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

    @Test("자리표시자에 변수 이름이 담기고 값은 담기지 않는다")
    func placeholderNamesTheVariable() throws {
        #expect(APIKey.Variable.openRouter.placeholder == "<redacted:OPENROUTER_API_KEY>")
        #expect(!APIKey.placeholder.contains(key))
    }

    @Test("키 미설정 안내에 export 방법이 담기고 값은 담기지 않는다")
    func guidanceMessage() {
        let message = String(describing: APIKeyError.notSet(.openRouter))
        #expect(message.contains("OPENROUTER_API_KEY"))
        #expect(message.contains("export"))
        #expect(!message.contains(key))
    }

    // MARK: - Redactor

    @Test("Redactor 가 알고 있는 키를 지운다")
    func redactsKnownSecret() throws {
        let redactor = Redactor(apiKey: try APIKey(rawValue: key))
        let redacted = redactor.redact("authorization: Bearer \(key) 요청 실패")
        #expect(!redacted.contains(key))
        #expect(redacted == "authorization: Bearer \(APIKey.placeholder) 요청 실패")
    }

    @Test(
        "모르는 키 토큰도 접두사로 함께 가린다",
        arguments: [
            "sk-or-v1-SOMEONEELSES0123456789abcdef",
            "sk-ant-api03-SOMEONEELSES-KEY_123",
            "sk-proj-SOMEONEELSES0123456789",
        ]
    )
    func redactsUnknownKeyLikeTokens(other: String) {
        let redacted = Redactor().redact("본문에 \(other) 가 섞여 돌아왔다.")
        #expect(!redacted.contains(other))
        #expect(redacted == "본문에 \(APIKey.placeholder) 가 섞여 돌아왔다.")
    }

    @Test("공급자를 바꿔도 옛 Anthropic 키 모양은 계속 가린다")
    func stillMasksLegacyProviderKeys() {
        let legacy = Fixtures.fakeAnthropicKeyString
        let redacted = Redactor(secrets: [Fixtures.fakeAPIKeyString]).redact("셸에 남은 \(legacy)")
        #expect(!redacted.contains(legacy))
    }

    @Test("가릴 것이 없는 문자열은 그대로 둔다")
    func leavesCleanTextAlone() {
        let text = "429 레이트 리밋 — rate_limit_error: 느려 [request_id: req_01] sk-not-a-key"
        #expect(Redactor(secrets: [Fixtures.fakeAPIKeyString]).redact(text) == text)
    }

    @Test("APIKey 는 Encodable 이 아니다 — 설정 파일에 실릴 수 없다")
    func apiKeyIsNotEncodable() throws {
        // 컴파일 타임 보장을 런타임에서 한 번 더 확인한다. 누가 Codable 을 붙이면
        // 이 테스트가 빨개진다.
        #expect(!(try APIKey(rawValue: key) is any Encodable))
        #expect(!(try APIKey(rawValue: key) is any Decodable))
    }

    @Test("모델 ID 는 반대로 Codable 이고 값을 그대로 보여 준다 — 재현에 필요하다")
    func modelIDIsNotASecret() throws {
        let model = ModelID("vendor/model-x")
        #expect("\(model)" == "vendor/model-x")
        let encoded = try JSONEncoder().encode(model)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"vendor\\/model-x\"")
    }
}
