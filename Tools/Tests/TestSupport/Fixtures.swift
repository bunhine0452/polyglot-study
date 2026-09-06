public import Foundation

/// 테스트가 공유하는 값들.
public enum Fixtures {
    /// 진짜처럼 생긴 가짜 OpenRouter 키. 로그 전수 검사가 이 문자열을 찾는다.
    ///
    /// **실제 키를 여기 넣지 말 것.** 이 파일은 커밋된다.
    public static let fakeAPIKeyString = "sk-or-v1-FAKEKEYFORTESTS0123456789abcdefXYZ"

    /// 실수로 남아 있을 수 있는 옛 공급자 키 모양. Redactor 가 이것도 가리는지 본다.
    public static let fakeAnthropicKeyString = "sk-ant-api03-FAKEKEYFORTESTS-0123456789abcdefXYZ"

    /// 테스트가 쓰는 모델 ID. 비밀이 아니다.
    public static let testModel = "test-vendor/test-model"

    /// 성공 응답 본문. `text` 를 첫 choice 의 메시지에 담는다.
    public static func chatCompletionJSON(
        text: String,
        finishReason: String = "stop",
        model: String = Fixtures.testModel,
        upstreamProvider: String = "TestUpstream",
        cachedTokens: Int = 0,
        cost: Double? = 0.000123
    ) -> Data {
        var usage: [String: Any] = [
            "prompt_tokens": 1234,
            "completion_tokens": 567,
            "total_tokens": 1801,
            "prompt_tokens_details": ["cached_tokens": cachedTokens],
            "completion_tokens_details": ["reasoning_tokens": 42],
        ]
        if let cost { usage["cost"] = cost }
        let payload: [String: Any] = [
            "id": "gen-01TEST",
            "object": "chat.completion",
            "created": 1_787_752_741,
            "model": model,
            "provider": upstreamProvider,
            "choices": [
                [
                    "index": 0,
                    "finish_reason": finishReason,
                    "native_finish_reason": finishReason,
                    "message": ["role": "assistant", "content": text],
                ]
            ],
            "usage": usage,
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// 거절 응답. HTTP 는 200 이고 `refusal` 필드에 사유가 실린다.
    public static func refusalJSON(reason: String = "정책상 거절") -> Data {
        let payload: [String: Any] = [
            "id": "gen-01REFUSAL",
            "model": Fixtures.testModel,
            "provider": "TestUpstream",
            "choices": [
                [
                    "index": 0,
                    "finish_reason": "stop",
                    "message": ["role": "assistant", "content": NSNull(), "refusal": reason],
                ]
            ],
            "usage": ["prompt_tokens": 10, "completion_tokens": 0],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// **HTTP 200 인데 본문에 오류가 실린** 응답. 상태 코드만 보면 놓치는 경로다.
    public static func inlineErrorJSON(code: Int, message: String, providerName: String = "TestUpstream") -> Data {
        let payload: [String: Any] = [
            "id": "gen-01INLINE",
            "error": ["code": code, "message": message, "metadata": ["provider_name": providerName]],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// 오류 응답 본문.
    public static func errorJSON(
        code: Int,
        message: String,
        providerName: String? = "TestUpstream",
        requestID: String? = "req_01TEST"
    ) -> Data {
        var error: [String: Any] = ["code": code, "message": message]
        if let providerName { error["metadata"] = ["provider_name": providerName] }
        var payload: [String: Any] = ["error": error]
        if let requestID { payload["request_id"] = requestID }
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// 스키마를 만족하는 최소 개요 초안 JSON.
    public static let outlineDraftJSON = """
        {
          "trackTitle": "파이썬 입문",
          "trackSummary": "표준 라이브러리만으로 실행 가능한 프로그램을 쓴다.",
          "lessons": [
            {
              "slug": "hello-stdout",
              "title": "첫 출력",
              "summary": "print 로 표준 출력에 쓴다.",
              "objectives": ["print 로 문자열을 출력할 수 있다.", "스크립트를 실행할 수 있다."],
              "prerequisiteSlugs": [],
              "concepts": ["print", "stdout"],
              "estimatedMinutes": 15
            },
            {
              "slug": "list-comprehension",
              "title": "리스트 컴프리헨션",
              "summary": "반복문을 한 줄 표현식으로 접는다.",
              "objectives": ["컴프리헨션으로 리스트를 만들 수 있다.", "조건절을 붙일 수 있다."],
              "prerequisiteSlugs": ["hello-stdout"],
              "concepts": ["list", "comprehension"],
              "estimatedMinutes": 25
            }
          ]
        }
        """
}
