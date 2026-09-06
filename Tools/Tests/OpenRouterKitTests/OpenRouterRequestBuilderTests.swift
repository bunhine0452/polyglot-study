import Foundation
import LLMKit
import OpenRouterKit
import TestSupport
import Testing

@Suite("OpenRouter 요청 조립")
struct OpenRouterRequestBuilderTests {
    private func makeKey() throws -> APIKey {
        try APIKey(rawValue: Fixtures.fakeAPIKeyString)
    }

    private let model = ModelID(Fixtures.testModel)

    private var sampleRequest: CompletionRequest {
        CompletionRequest(
            system: [PromptSegment(text: "고정 시스템 프롬프트", cacheHint: .default)],
            messages: [.user("안녕")],
            maxOutputTokens: 16000,
            responseFormat: .jsonSchema(name: "track_outline", schema: ["type": "object"]),
            reasoningEffort: .high
        )
    }

    private func body(
        _ request: CompletionRequest,
        builder: OpenRouterRequestBuilder = OpenRouterRequestBuilder()
    ) throws -> [String: Any] {
        let urlRequest = try builder.makeURLRequest(for: request, model: model, apiKey: makeKey())
        return try #require(
            try JSONSerialization.jsonObject(with: urlRequest.httpBody ?? Data()) as? [String: Any]
        )
    }

    @Test("엔드포인트 URL 이 슬래시 중복 없이 만들어진다")
    func endpointURL() throws {
        #expect(
            try OpenRouterRequestBuilder().url(for: .chatCompletions).absoluteString
                == "https://openrouter.ai/api/v1/chat/completions"
        )
        // 후행 슬래시가 붙은 base URL 도 같은 결과.
        let trailing = OpenRouterRequestBuilder(baseURL: URL(string: "http://127.0.0.1:8080/")!)
        #expect(try trailing.url(for: .chatCompletions).absoluteString == "http://127.0.0.1:8080/chat/completions")
        // 사후 조회 자리는 잡혀 있다 ({#lessongen-runlog}).
        #expect(OpenRouterEndpoint.generation.path == "/generation")
    }

    @Test("Authorization 은 Bearer 스킴이고 부가 헤더가 함께 붙는다")
    func headers() throws {
        let request = try OpenRouterRequestBuilder().makeURLRequest(
            for: sampleRequest, model: model, apiKey: makeKey()
        )
        let headers = Dictionary(
            (request.allHTTPHeaderFields ?? [:]).map { ($0.key.lowercased(), $0.value) },
            uniquingKeysWith: { _, last in last }
        )
        #expect(request.httpMethod == "POST")
        #expect(headers["content-type"] == "application/json")
        #expect(headers["authorization"] == "Bearer \(Fixtures.fakeAPIKeyString)")
        #expect(headers["http-referer"] == OpenRouterRequestBuilder.Attribution.polyglotStudy.referer)
        // 2026년의 정식 이름은 X-OpenRouter-Title 이다 (X-Title 은 하위호환 별칭).
        #expect(headers["x-openrouter-title"] == OpenRouterRequestBuilder.Attribution.polyglotStudy.title)
        // 옛 공급자의 헤더는 흔적도 없어야 한다.
        #expect(headers["x-api-key"] == nil)
        #expect(headers["anthropic-version"] == nil)
    }

    @Test("부가 헤더를 비우면 헤더 자체가 없다")
    func noAttributionHeaders() throws {
        let builder = OpenRouterRequestBuilder(attribution: .init())
        let request = try builder.makeURLRequest(for: sampleRequest, model: model, apiKey: makeKey())
        let names = (request.allHTTPHeaderFields ?? [:]).keys.map { $0.lowercased() }
        #expect(!names.contains("http-referer"))
        #expect(!names.contains("x-openrouter-title"))
    }

    @Test("본문이 OpenAI 호환 모양으로 나간다")
    func wireShape() throws {
        let json = try body(sampleRequest)
        #expect(json["model"] as? String == Fixtures.testModel)
        #expect(json["max_tokens"] as? Int == 16000)

        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "system")
        #expect(messages[0]["content"] as? String == "고정 시스템 프롬프트")
        #expect(messages[1]["role"] as? String == "user")
        #expect(messages[1]["content"] as? String == "안녕")

        #expect((json["reasoning"] as? [String: Any])?["effort"] as? String == "high")
    }

    @Test("구조화 출력이 json_schema 봉투에 실리고 strict 가 켜진다")
    func structuredOutputEnvelope() throws {
        let json = try body(sampleRequest)
        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["json_schema"] as? [String: Any])
        #expect(schema["name"] as? String == "track_outline")
        #expect(schema["strict"] as? Bool == true)
        #expect(schema["schema"] != nil)
    }

    @Test("텍스트 응답에는 response_format 자체가 없다")
    func textNeedsNoFormat() throws {
        let json = try body(CompletionRequest(messages: [.user("x")], maxOutputTokens: 10))
        #expect(json["response_format"] == nil)
        #expect(json["reasoning"] == nil)
    }

    /// 이 구현에서 가장 중요한 한 줄. 같은 모델 뒤의 업스트림들이 지원 파라미터가 서로
    /// 달라서, 좁히지 않으면 구조화 출력 요청이 그걸 모르는 곳에 걸려 산문이 돌아온다.
    @Test("구조화 출력을 요구하면 라우팅을 지원 업스트림으로 좁힌다")
    func requireParametersIsSentWithStructuredOutput() throws {
        let json = try body(sampleRequest)
        let provider = try #require(json["provider"] as? [String: Any])
        #expect(provider["require_parameters"] as? Bool == true)
    }

    @Test("아무 파라미터도 안 건 요청은 라우팅을 좁히지 않는다 — 값싼 업스트림을 버릴 이유가 없다")
    func plainRequestDoesNotNarrowRouting() throws {
        let json = try body(CompletionRequest(messages: [.user("x")], maxOutputTokens: 10))
        #expect(json["provider"] == nil)
    }

    @Test("시드를 주면 시드를 지원하는 업스트림으로 좁힌다")
    func seedNarrowsRouting() throws {
        let request = CompletionRequest(
            messages: [.user("x")],
            maxOutputTokens: 10,
            sampling: .deterministic(seed: 7)
        )
        let json = try body(request)
        #expect(json["seed"] as? Int == 7)
        #expect(json["temperature"] as? Double == 0)
        #expect((json["provider"] as? [String: Any])?["require_parameters"] as? Bool == true)
    }

    @Test("라우팅 좁히기를 끄면 그 필드가 사라진다")
    func requireParametersCanBeDisabled() throws {
        let builder = OpenRouterRequestBuilder(requireParameters: false)
        #expect(try body(sampleRequest, builder: builder)["provider"] == nil)
    }

    // MARK: - 업스트림 고정 ({#lessongen-prompt-caching})

    private func pinnedBuilder(
        _ names: [String], allowFallbacks: Bool = false, requireParameters: Bool = true
    ) throws -> OpenRouterRequestBuilder {
        OpenRouterRequestBuilder(
            requireParameters: requireParameters,
            upstreamPin: try #require(
                UpstreamPin(providers: names, allowFallbacks: allowFallbacks)))
    }

    @Test("업스트림을 고정하면 order 와 allow_fallbacks 로 나간다")
    func pinBecomesOrderAndFallbacks() throws {
        let json = try body(sampleRequest, builder: try pinnedBuilder(["NextBit", "Wafer"]))
        let provider = try #require(json["provider"] as? [String: Any])
        #expect(provider["order"] as? [String] == ["NextBit", "Wafer"])
        #expect(provider["allow_fallbacks"] as? Bool == false)
        // 고정과 파라미터 좁히기는 따로 논다. 둘 다 필요하면 둘 다 나간다.
        #expect(provider["require_parameters"] as? Bool == true)
    }

    /// 고정은 캐시가 목적이라 파라미터와 무관하게 언제나 의미가 있다. 예전 로직은
    /// "요구한 파라미터가 있을 때만" provider 블록을 냈고, 그 조건에 고정을 얹으면
    /// 평범한 요청의 고정이 조용히 사라진다.
    @Test("파라미터를 하나도 안 걸어도 고정은 나간다")
    func pinSurvivesPlainRequest() throws {
        let plain = CompletionRequest(messages: [.user("x")], maxOutputTokens: 10)
        let json = try body(plain, builder: try pinnedBuilder(["NextBit"]))
        let provider = try #require(json["provider"] as? [String: Any])
        #expect(provider["order"] as? [String] == ["NextBit"])
        // 좁힐 파라미터가 없으니 require_parameters 는 켜지 않는다 — 값싼 업스트림을
        // 이유 없이 버리지 않는다는 기존 규칙 그대로다.
        #expect(provider["require_parameters"] as? Bool == false)
    }

    @Test("폴백을 허용하면 allow_fallbacks 가 참으로 나간다")
    func fallbacksCanBeAllowed() throws {
        let json = try body(
            sampleRequest, builder: try pinnedBuilder(["NextBit"], allowFallbacks: true))
        #expect((json["provider"] as? [String: Any])?["allow_fallbacks"] as? Bool == true)
    }

    @Test("고정이 없으면 order 와 allow_fallbacks 는 아예 없다")
    func noPinNoOrder() throws {
        let provider = try #require(try body(sampleRequest)["provider"] as? [String: Any])
        #expect(provider["order"] == nil)
        #expect(provider["allow_fallbacks"] == nil)
    }

    @Test("빈 이름만 준 고정은 고정이 아니다")
    func emptyPinIsNil() {
        #expect(UpstreamPin(providers: []) == nil)
        #expect(UpstreamPin(providers: ["", "   "]) == nil)
        #expect(UpstreamPin(providers: [" NextBit "])?.providers == ["NextBit"])
    }

    @Test("고정 목록에 실제로 답한 업스트림이 있는지 판정한다")
    func honoredJudgement() throws {
        let pin = try #require(UpstreamPin(providers: ["NextBit", "Wafer"]))
        #expect(pin.honored(by: "NextBit"))
        #expect(!pin.honored(by: "Reka"))
    }

    /// `usage: {include: true}` 는 2026년에 폐기되어 아무 효과가 없다. 죽은 필드를
    /// 보내면 캐시 접두사 바이트만 흔든다.
    @Test("폐기된 usage.include 는 보내지 않는다")
    func doesNotSendDeprecatedUsageFlag() throws {
        #expect(try body(sampleRequest)["usage"] == nil)
    }

    @Test("세션 키를 주면 캐시 친화 라우팅 키가 실린다")
    func sessionIDIsSent() throws {
        let builder = OpenRouterRequestBuilder(sessionID: "outline-python")
        #expect(try body(sampleRequest, builder: builder)["session_id"] as? String == "outline-python")
        // 안 주면 필드 자체가 없다.
        #expect(try body(sampleRequest)["session_id"] == nil)
    }

    @Test("자동 캐싱 모드에서는 content 가 그냥 문자열이다")
    func automaticCachingKeepsPlainContent() throws {
        let messages = try #require(try body(sampleRequest)["messages"] as? [[String: Any]])
        #expect(messages[0]["content"] as? String != nil)
    }

    @Test("명시 캐시 모드에서는 content 가 파트 배열이고 cache_control 이 붙는다")
    func explicitCachingUsesParts() throws {
        let builder = OpenRouterRequestBuilder(promptCaching: .explicitBreakpoints)
        let messages = try #require(try body(sampleRequest, builder: builder)["messages"] as? [[String: Any]])
        let parts = try #require(messages[0]["content"] as? [[String: Any]])
        #expect(parts[0]["type"] as? String == "text")
        #expect((parts[0]["cache_control"] as? [String: Any])?["type"] as? String == "ephemeral")
        // 힌트가 없는 사용자 메시지에는 경계가 붙지 않는다.
        let userParts = try #require(messages[1]["content"] as? [[String: Any]])
        #expect(userParts[0]["cache_control"] == nil)
    }

    @Test("JSON Schema 의 카멜케이스 키는 절대 변환되지 않는다")
    func schemaKeysSurviveVerbatim() throws {
        let request = CompletionRequest(
            messages: [.user("x")],
            maxOutputTokens: 100,
            responseFormat: .jsonSchema(
                name: "s",
                schema: [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": ["estimatedMinutes": ["type": "integer"]],
                ]
            )
        )
        let urlRequest = try OpenRouterRequestBuilder().makeURLRequest(
            for: request, model: model, apiKey: makeKey()
        )
        let text = String(decoding: urlRequest.httpBody ?? Data(), as: UTF8.self)
        // `.convertToSnakeCase` 를 켜면 여기가 additional_properties 로 망가진다.
        #expect(text.contains("\"additionalProperties\":false"))
        #expect(text.contains("\"estimatedMinutes\""))
        #expect(!text.contains("additional_properties"))
        #expect(!text.contains("estimated_minutes"))
    }

    @Test("정수 스키마 값이 실수로 나가지 않는다")
    func integersStayIntegers() throws {
        let request = CompletionRequest(
            messages: [.user("x")],
            maxOutputTokens: 100,
            responseFormat: .jsonSchema(name: "s", schema: ["minItems": 2])
        )
        let urlRequest = try OpenRouterRequestBuilder().makeURLRequest(
            for: request, model: model, apiKey: makeKey()
        )
        let text = String(decoding: urlRequest.httpBody ?? Data(), as: UTF8.self)
        #expect(text.contains("\"minItems\":2"))
        #expect(!text.contains("2.0"))
    }

    @Test("같은 요청은 항상 같은 바이트로 굽힌다 — 캐시 접두사가 흔들리지 않게")
    func encodingIsDeterministic() throws {
        let first = try OpenRouterRequestBuilder()
            .makeURLRequest(for: sampleRequest, model: model, apiKey: makeKey()).httpBody
        for _ in 0..<20 {
            let again = try OpenRouterRequestBuilder()
                .makeURLRequest(for: sampleRequest, model: model, apiKey: makeKey()).httpBody
            #expect(again == first)
        }
    }

    @Test("요청 덤프의 Authorization 자리가 자리표시자다")
    func redactedDumpMasksHeader() throws {
        let apiKey = try makeKey()
        let urlRequest = try OpenRouterRequestBuilder().makeURLRequest(
            for: sampleRequest, model: model, apiKey: apiKey
        )
        // 실제 URLRequest 에는 키가 있다 — 전선에 실려야 하니까.
        #expect(urlRequest.value(forHTTPHeaderField: "authorization") == "Bearer \(Fixtures.fakeAPIKeyString)")
        // 덤프에는 없다.
        let dump = OpenRouterRequestBuilder.redactedDump(of: urlRequest, apiKey: apiKey)
        #expect(!dump.contains(Fixtures.fakeAPIKeyString))
        #expect(dump.contains("authorization: Bearer \(APIKey.placeholder)"))
        // 모델은 반대로 그대로 남아야 한다 — 재현에 필요하다.
        #expect(dump.contains(Fixtures.testModel))
    }
}
