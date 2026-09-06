import Foundation

/// 로그로 나가는 모든 문자열에서 비밀값을 지운다.
///
/// 두 겹으로 막는다.
/// 1. 알고 있는 비밀값의 **정확한 일치**를 자리표시자로 바꾼다.
/// 2. 우리가 들고 있지 않은 키까지 잡도록 알려진 키 접두사로 시작하는 토큰을 통째로
///    가린다. (사용자가 실수로 붙여 넣은 키가 에러 메시지에 되돌아오는 경우 대비.)
///
/// 접두사 목록은 **공급자보다 넓게** 잡는다 — OpenRouter 로 옮겼다고 Anthropic 키를
/// 흘려도 되는 것은 아니다. 셸에 남아 있던 옛 키가 프롬프트나 오류 본문에 섞여 돌아올
/// 수 있으므로 알던 접두사는 지우지 않고 더한다.
public struct Redactor: Sendable {
    /// 스캐너가 인식하는 키 접두사.
    ///
    /// - `sk-or-` — OpenRouter (`sk-or-v1-…`).
    /// - `sk-ant-` — Anthropic. 공급자를 바꿔도 남겨 둔다.
    /// - `sk-proj-` — OpenAI 프로젝트 키. OpenRouter 를 우회해 직접 키를 넣어 본 흔적이
    ///   본문에 섞여 돌아오는 경우가 있다.
    ///
    /// 맨 `sk-` 는 **일부러 넣지 않는다** — 너무 넓어서 정상 텍스트를 갉아먹는다.
    static let keyPrefixes = ["sk-or-", "sk-ant-", "sk-proj-"]

    private let secrets: [String]
    private let placeholder: String

    public init(secrets: [String] = [], placeholder: String = APIKey.placeholder) {
        // 긴 것부터 지워야 짧은 비밀값이 긴 비밀값의 일부를 먼저 갉아먹지 않는다.
        self.secrets = secrets
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        self.placeholder = placeholder
    }

    public init(apiKey: APIKey) {
        self.init(secrets: [apiKey.rawValue], placeholder: apiKey.variable.placeholder)
    }

    public func redact(_ text: String) -> String {
        var result = text
        for secret in secrets where result.contains(secret) {
            result = result.replacingOccurrences(of: secret, with: placeholder)
        }
        return Self.maskKeyLikeTokens(in: result, placeholder: placeholder)
    }

    /// 알려진 접두사로 시작하는 토큰을 끝까지(구분자 전까지) 가린다.
    ///
    /// 정규식 대신 손으로 훑는다 — 동작이 눈에 보이고, 의존성이 없고, 실패 모드가 없다.
    static func maskKeyLikeTokens(in text: String, placeholder: String = APIKey.placeholder) -> String {
        guard keyPrefixes.contains(where: { text.contains($0) }) else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            if let prefix = keyPrefixes.first(where: { text[index...].hasPrefix($0) }) {
                var end = text.index(index, offsetBy: prefix.count)
                while end < text.endIndex, isTokenCharacter(text[end]) {
                    end = text.index(after: end)
                }
                result += placeholder
                index = end
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }
        return result
    }

    /// 키 본문에 나타날 수 있는 문자. 여기서 벗어나면 토큰이 끝난 것으로 본다.
    private static func isTokenCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == "_"
    }
}
