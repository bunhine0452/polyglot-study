/// 응답 본문에서 JSON 객체 하나를 도려낸다.
///
/// ## 왜 필요한가 — 실측
///
/// `response_format: json_schema` 에 `strict: true` 를 걸고 `provider.require_parameters`
/// 로 라우팅까지 좁혀도, 업스트림이 문법을 **강제**하는 대신 **유도**하기만 하는 경우가
/// 있다. 실측: `z-ai/glm-5.3-flash` 가 NextBit 에서 스키마를 만족하는 객체를 낸 **뒤에**
/// 닫는 중괄호를 하나 더 붙여 보냈다. `finish_reason` 은 `stop` 이었고 잘린 것도 아니다.
///
/// `JSONDecoder` 는 뒤에 한 글자라도 남으면 통째로 실패한다. 그래서 완전한 응답 하나를
/// 재시도로 버리게 된다 — 돈은 이미 나갔는데.
///
/// 균형 잡힌 첫 객체만 도려내면 이 실패와 함께, 코드펜스로 감싸 보내거나 앞에 한 줄
/// 설명을 붙여 보내는 경우까지 같이 살아난다. **관대함의 범위는 여기까지다** — 도려낸
/// 뒤에는 스키마 디코딩이 그대로 엄격하게 돈다.
enum JSONExtraction {
    /// 첫 `{` 부터 짝이 맞는 `}` 까지. 문자열 리터럴 안의 중괄호는 세지 않는다.
    static func balancedObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if inString {
                if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...index])
                    }
                default: break
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
}
