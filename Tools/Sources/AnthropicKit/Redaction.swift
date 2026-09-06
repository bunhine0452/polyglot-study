import Foundation

/// 로그로 나가는 모든 문자열에서 비밀값을 지운다.
///
/// 두 겹으로 막는다.
/// 1. 알고 있는 비밀값의 **정확한 일치**를 자리표시자로 바꾼다.
/// 2. 우리가 들고 있지 않은 키까지 잡도록 `sk-ant-` 로 시작하는 토큰을 통째로 가린다.
///    (사용자가 실수로 붙여 넣은 키가 에러 메시지에 되돌아오는 경우 대비.)
public struct Redactor: Sendable {
    /// 스캐너가 인식하는 Anthropic 키 접두사.
    static let keyPrefix = "sk-ant-"

    private let secrets: [String]

    public init(secrets: [String] = []) {
        // 긴 것부터 지워야 짧은 비밀값이 긴 비밀값의 일부를 먼저 갉아먹지 않는다.
        self.secrets = secrets
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
    }

    public init(apiKey: APIKey) {
        self.init(secrets: [apiKey.rawValue])
    }

    public func redact(_ text: String) -> String {
        var result = text
        for secret in secrets where result.contains(secret) {
            result = result.replacingOccurrences(of: secret, with: APIKey.placeholder)
        }
        return Self.maskKeyLikeTokens(in: result)
    }

    /// `sk-ant-` 로 시작하는 토큰을 끝까지(구분자 전까지) 가린다.
    ///
    /// 정규식 대신 손으로 훑는다 — 동작이 눈에 보이고, 의존성이 없고, 실패 모드가 없다.
    static func maskKeyLikeTokens(in text: String) -> String {
        guard text.contains(keyPrefix) else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            if text[index...].hasPrefix(keyPrefix) {
                var end = text.index(index, offsetBy: keyPrefix.count)
                while end < text.endIndex, isTokenCharacter(text[end]) {
                    end = text.index(after: end)
                }
                result += APIKey.placeholder
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
