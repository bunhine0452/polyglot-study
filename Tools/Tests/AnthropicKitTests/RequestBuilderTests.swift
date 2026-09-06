import AnthropicKit
import Foundation
import TestSupport
import Testing

@Suite("요청 조립")
struct RequestBuilderTests {
    private func makeKey() throws -> APIKey {
        try APIKey(rawValue: Fixtures.fakeAPIKeyString)
    }

    private var sampleRequest: MessagesRequest {
        MessagesRequest(
            model: .opus5,
            maxTokens: 16000,
            system: [SystemBlock(text: "고정 시스템 프롬프트", cacheControl: CacheControl())],
            messages: [.user("안녕")],
            thinking: Thinking(type: .adaptive),
            outputConfig: OutputConfig(effort: .high)
        )
    }

    @Test("엔드포인트 URL 이 슬래시 중복 없이 만들어진다")
    func endpointURL() throws {
        #expect(
            try RequestBuilder().url(for: .messages).absoluteString
                == "https://api.anthropic.com/v1/messages"
        )
        // 후행 슬래시가 붙은 base URL 도 같은 결과.
        let trailing = RequestBuilder(baseURL: URL(string: "http://127.0.0.1:8080/")!)
        #expect(try trailing.url(for: .messages).absoluteString == "http://127.0.0.1:8080/v1/messages")
        // Batch 엔드포인트 자리는 잡혀 있다 ({#lessongen-batch-fanout}).
        #expect(AnthropicEndpoint.messageBatches.path == "/v1/messages/batches")
    }

    @Test("필수 헤더 4종이 정확히 붙는다")
    func headers() throws {
        let request = try RequestBuilder().makeURLRequest(
            endpoint: .messages,
            body: sampleRequest,
            apiKey: makeKey(),
            betas: ["server-side-fallback-2026-07-01"]
        )
        let headers = try #require(request.allHTTPHeaderFields)
        let lowercased = Dictionary(
            headers.map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { _, last in last }
        )
        #expect(request.httpMethod == "POST")
        #expect(lowercased["content-type"] == "application/json")
        #expect(lowercased["anthropic-version"] == "2023-06-01")
        #expect(lowercased["x-api-key"] == Fixtures.fakeAPIKeyString)
        #expect(lowercased["anthropic-beta"] == "server-side-fallback-2026-07-01")
    }

    @Test("베타 플래그가 없으면 anthropic-beta 헤더 자체가 없다")
    func noBetaHeader() throws {
        let request = try RequestBuilder().makeURLRequest(
            endpoint: .messages,
            body: sampleRequest,
            apiKey: makeKey()
        )
        let names = (request.allHTTPHeaderFields ?? [:]).keys.map { $0.lowercased() }
        #expect(!names.contains("anthropic-beta"))
    }

    @Test("본문 와이어 키가 스네이크 케이스로 나간다")
    func wireKeys() throws {
        let data = try RequestBuilder.encodeBody(sampleRequest)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(json["max_tokens"] as? Int == 16000)
        #expect(json["model"] as? String == "claude-opus-5")
        #expect((json["output_config"] as? [String: Any])?["effort"] as? String == "high")
        #expect((json["thinking"] as? [String: Any])?["type"] as? String == "adaptive")

        let system = try #require(json["system"] as? [[String: Any]])
        #expect(system[0]["type"] as? String == "text")
        #expect((system[0]["cache_control"] as? [String: Any])?["type"] as? String == "ephemeral")
    }

    @Test("JSON Schema 의 카멜케이스 키는 절대 변환되지 않는다")
    func schemaKeysSurviveVerbatim() throws {
        let request = MessagesRequest(
            model: .opus5,
            maxTokens: 100,
            messages: [.user("x")],
            outputConfig: OutputConfig(
                format: OutputFormat(
                    schema: [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": ["estimatedMinutes": ["type": "integer"]],
                    ]
                )
            )
        )
        let text = String(decoding: try RequestBuilder.encodeBody(request), as: UTF8.self)
        // `.convertToSnakeCase` 를 켜면 여기가 additional_properties 로 망가진다.
        #expect(text.contains("\"additionalProperties\":false"))
        #expect(text.contains("\"estimatedMinutes\""))
        #expect(!text.contains("additional_properties"))
        #expect(!text.contains("estimated_minutes"))
    }

    @Test("정수 스키마 값이 실수로 나가지 않는다")
    func integersStayIntegers() throws {
        let request = MessagesRequest(
            model: .opus5,
            maxTokens: 100,
            messages: [.user("x")],
            outputConfig: OutputConfig(format: OutputFormat(schema: ["minItems": 2]))
        )
        let text = String(decoding: try RequestBuilder.encodeBody(request), as: UTF8.self)
        #expect(text.contains("\"minItems\":2"))
        #expect(!text.contains("2.0"))
    }

    @Test("같은 요청은 항상 같은 바이트로 굽힌다 — 캐시 접두사가 흔들리지 않게")
    func encodingIsDeterministic() throws {
        let first = try RequestBuilder.encodeBody(sampleRequest)
        for _ in 0..<20 {
            #expect(try RequestBuilder.encodeBody(sampleRequest) == first)
        }
    }

    @Test("fallbacks 두 형태가 각자의 베타 플래그를 요구한다")
    func fallbackShapes() throws {
        #expect(Fallbacks.default.betaFlag == "server-side-fallback-2026-07-01")
        #expect(Fallbacks.models([.opus5]).betaFlag == "server-side-fallback-2026-06-01")

        let scalar = MessagesRequest(
            model: .opus5, maxTokens: 10, messages: [.user("x")], fallbacks: .default
        )
        let scalarText = String(decoding: try RequestBuilder.encodeBody(scalar), as: UTF8.self)
        #expect(scalarText.contains("\"fallbacks\":\"default\""))

        let array = MessagesRequest(
            model: .opus5, maxTokens: 10, messages: [.user("x")], fallbacks: .models([.opus5])
        )
        let arrayText = String(decoding: try RequestBuilder.encodeBody(array), as: UTF8.self)
        #expect(arrayText.contains("\"fallbacks\":[{\"model\":\"claude-opus-5\"}]"))
    }
}
