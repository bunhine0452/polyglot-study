// `fromEnvironment` 의 기본 인자가 `ProcessInfo` 를 부르므로 공개 임포트여야 한다.
public import Foundation

/// 원격 공급자의 API 키.
///
/// **입력 경로는 환경변수 하나뿐이다.** 플래그·설정파일·키체인 어디에서도 읽지 않는다
/// (쟁점 3 — 생성을 빌드타임 CLI 로 밀었으므로 개발자 셸의 환경변수가 유일한 출처다).
///
/// 값이 밖으로 새지 않도록 타입 차원에서 막아 둔 것:
/// - `Codable` 을 **일부러 채택하지 않는다** — 설정 파일이나 JSON 로그에 실릴 수 없다.
/// - `description`·`debugDescription` 이 자리표시자를 돌려준다 — `"\(key)"` 나
///   `print(key)` 로는 값이 나오지 않는다.
/// - 원문은 `package` 접근 수준의 ``rawValue`` 로만 열려 있고, 이걸 읽는 곳은
///   공급자의 헤더 조립과 ``Redactor`` 구성 두 군데뿐이다.
///
/// 공급자가 늘어도 이 타입은 하나다 — 환경변수 이름만 ``Variable`` 로 갈린다. 로컬
/// 백엔드(MLX)처럼 키가 없는 공급자는 이 타입을 아예 쓰지 않는다.
public struct APIKey: Sendable {
    /// 키를 담는 환경변수. 공급자마다 다르므로 값으로 들고 다닌다.
    public struct Variable: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }

        /// OpenRouter. 현재 유일한 원격 공급자.
        public static let openRouter = Variable("OPENROUTER_API_KEY")

        /// 로그에 값 대신 실리는 문자열.
        public var placeholder: String { "<redacted:\(rawValue)>" }
    }

    /// 기본 환경변수 이름. 지금은 OpenRouter 하나뿐이다.
    public static var environmentVariableName: String { Variable.openRouter.rawValue }

    /// 기본 자리표시자. 공급자를 모르는 자리(테스트·범용 Redactor)가 쓴다.
    public static var placeholder: String { Variable.openRouter.placeholder }

    /// 이 키가 어느 환경변수에서 왔는가. 안내 문구와 자리표시자가 여기서 나온다.
    public let variable: Variable

    private let value: String

    /// 원문. 요청 헤더 조립과 ``Redactor`` 구성에만 쓴다.
    package var rawValue: String { value }

    package init(rawValue: String, variable: Variable = .openRouter) throws(APIKeyError) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty(variable) }
        // 헤더 값에 개행이 들어가면 헤더 인젝션이 된다. URLSession 이 조용히 자르거나
        // 던지기 전에 여기서 막는다.
        guard trimmed.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else {
            throw .containsControlCharacter(variable)
        }
        self.value = trimmed
        self.variable = variable
    }

    /// 환경변수에서 읽는다. 없거나 비어 있으면 던진다 — 다른 곳은 절대 뒤지지 않는다.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        variable: Variable = .openRouter
    ) throws(APIKeyError) -> APIKey {
        guard let raw = environment[variable.rawValue] else { throw .notSet(variable) }
        return try APIKey(rawValue: raw, variable: variable)
    }
}

extension APIKey: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { variable.placeholder }
    public var debugDescription: String { variable.placeholder }
}

public enum APIKeyError: Error, Sendable, Hashable {
    /// 환경변수 자체가 없다.
    case notSet(APIKey.Variable)
    /// 환경변수는 있으나 공백뿐이다.
    case empty(APIKey.Variable)
    /// 제어문자가 섞여 있다 — 헤더에 실을 수 없다.
    case containsControlCharacter(APIKey.Variable)
}

extension APIKeyError: CustomStringConvertible {
    /// 사용자에게 그대로 보여 줄 안내. 키 값은 당연히 담기지 않는다.
    public var description: String {
        switch self {
        case .notSet(let variable):
            """
            \(variable.rawValue) 가 설정되어 있지 않습니다.

              export \(variable.rawValue)="sk-or-v1-..."

            이 도구는 키를 환경변수에서만 읽습니다 — 플래그·설정파일로는 받지 않습니다.
            키를 저장소·로그·명령행 인자 어디에도 남기지 마십시오.
            """
        case .empty(let variable):
            "\(variable.rawValue) 가 비어 있습니다."
        case .containsControlCharacter(let variable):
            "\(variable.rawValue) 에 제어문자가 섞여 있습니다. 값을 다시 확인하십시오."
        }
    }
}
