public import Foundation

/// 테스트가 공유하는 값들.
public enum Fixtures {
    /// 진짜처럼 생긴 가짜 키. 로그 전수 검사가 이 문자열을 찾는다.
    public static let fakeAPIKeyString = "sk-ant-api03-FAKEKEYFORTESTS-0123456789abcdefXYZ"

    /// 성공 응답 본문. `text` 를 첫 텍스트 블록에 담는다.
    public static func messagesResponseJSON(
        text: String,
        stopReason: String = "end_turn",
        cacheReadInputTokens: Int = 0
    ) -> Data {
        let payload: [String: Any] = [
            "id": "msg_01TEST",
            "type": "message",
            "role": "assistant",
            "model": "claude-opus-5",
            "content": [["type": "text", "text": text]],
            "stop_reason": stopReason,
            "stop_details": NSNull(),
            "usage": [
                "input_tokens": 1234,
                "output_tokens": 567,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": cacheReadInputTokens,
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// 거절 응답. HTTP 는 200 이다.
    public static func refusalResponseJSON(category: String = "cyber") -> Data {
        let payload: [String: Any] = [
            "id": "msg_01REFUSAL",
            "type": "message",
            "role": "assistant",
            "model": "claude-opus-5",
            "content": [],
            "stop_reason": "refusal",
            "stop_details": ["type": "refusal", "category": category, "explanation": "정책상 거절"],
            "usage": ["input_tokens": 10, "output_tokens": 0],
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// 오류 응답 본문.
    public static func errorJSON(type: String, message: String, requestID: String = "req_01TEST") -> Data {
        let payload: [String: Any] = [
            "type": "error",
            "error": ["type": type, "message": message],
            "request_id": requestID,
        ]
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
