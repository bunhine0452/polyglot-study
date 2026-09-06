public import Foundation

/// 서명 키를 읽는 **유일한 경로**.
///
/// 입력이 환경변수 하나뿐인 것은 `APIKey` 와 같은 규약이다. 플래그로 받으면 키가
/// 셸 히스토리와 `ps` 출력과 CI 로그에 남는다. 설정 파일로 받으면 저장소에 커밋된다.
public enum SigningEnvironment {
    /// 개인키. base64(32바이트 원문).
    public static let privateKeyVariable = "POLYGLOT_PACK_SIGNING_KEY"
    /// 공개키. base64(32바이트 원문). 비밀이 아니지만 **검증기가 아는 키**여야 하므로
    /// 같은 방식으로 주입한다.
    public static let publicKeyVariable = "POLYGLOT_PACK_PUBLIC_KEY"

    public static func privateKey(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws(SigningEnvironmentError) -> String {
        try value(of: privateKeyVariable, in: environment)
    }

    public static func publicKey(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws(SigningEnvironmentError) -> String {
        try value(of: publicKeyVariable, in: environment)
    }

    private static func value(
        of variable: String, in environment: [String: String]
    ) throws(SigningEnvironmentError) -> String {
        guard let raw = environment[variable] else { throw .notSet(variable) }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty(variable) }
        return trimmed
    }
}

public enum SigningEnvironmentError: Error, Hashable, Sendable, CustomStringConvertible {
    case notSet(String)
    case empty(String)

    /// 안내에 키 **값**은 당연히 담기지 않는다.
    public var description: String {
        switch self {
        case .notSet(let variable):
            """
            \(variable) 가 설정되어 있지 않습니다.

              export \(variable)="$(cat <키 파일>)"

            키 쌍은 `packtool keygen --private-key-out <파일>` 로 만듭니다.
            """
        case .empty(let variable): "\(variable) 가 비어 있습니다."
        }
    }
}
