public import LanguageKit

/// 런처에 넘길 명령 한 건.
///
/// `executablePath` 는 `execv` 로 그대로 넘어가므로 **절대경로여야 한다** — 런처는
/// PATH 탐색을 하지 않는다. 그게 의도다: 어떤 바이너리가 도는지 부모가 모르는 실행은
/// 격리가 아니다.
public struct SubprocessInvocation: Sendable, Hashable {
    public var executablePath: String
    public var arguments: [String]
    /// 기본 환경에 덧씌울 변수. 값이 `nil` 이면 기본 환경에서 제거한다.
    public var environmentOverrides: [String: String?]
    /// nil 이면 워크스페이스 루트.
    public var workingDirectory: String?

    public init(
        executablePath: String,
        arguments: [String] = [],
        environmentOverrides: [String: String?] = [:],
        workingDirectory: String? = nil
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.environmentOverrides = environmentOverrides
        self.workingDirectory = workingDirectory
    }
}

/// 준비 단계의 결론.
public enum SubprocessPreparation: Sendable {
    /// 이 명령을 런처에 태운다.
    case run(SubprocessInvocation)
    /// 준비 단계에서 끝났다 — 컴파일 실패가 대표적이다.
    ///
    /// 예외로 던지지 않는 이유는 컴파일 오류가 **백엔드 실패가 아니라 정상적인 실행
    /// 결과**이기 때문이다. 학습자는 진단을 봐야 하고, UI 는 `.finished` 를 받아야
    /// 제출 이력을 남긴다. 진단은 `emit` 으로 이미 흘려보낸 뒤여야 한다.
    case finished(RunTermination)
}

/// 워크스페이스가 준비된 뒤 "무엇을 실행할지"를 결정하는 쪽.
///
/// `SubprocessRunner` 를 언어마다 상속시키지 않으려고 나눴다. 프로세스 수명·상한·
/// 출력 파이프라인은 언어와 무관하게 똑같고, 언어마다 다른 것은 **준비 단계**뿐이다 —
/// Swift 는 컴파일하고, Python 은 인터프리터 인자를 고른다.
public protocol SubprocessProgram: Sendable {
    /// 이 프로그램이 UI 에 광고할 능력. 러너가 그대로 노출한다.
    var capabilities: RunnerCapabilities { get }

    /// 실행 직전 준비. 컴파일 진단은 `emit` 으로 흘린다.
    ///
    /// - Parameter emit: `.phase(.compiling)`·`.diagnostic` 을 스트림에 바로 태운다.
    ///   컴파일이 끝나기 전에도 UI 가 그릴 수 있어야 하므로 반환값이 아니라 콜백이다.
    func prepare(
        request: RunRequest,
        workspace: RunWorkspace,
        emit: @Sendable (RunEvent) -> Void
    ) async throws -> SubprocessPreparation
}

/// 준비할 것이 없는 프로그램. 테스트와 진단용.
public struct DirectProgram: SubprocessProgram {
    public var executablePath: String
    public var arguments: [String]
    public var capabilities: RunnerCapabilities

    public init(
        executablePath: String,
        arguments: [String] = [],
        capabilities: RunnerCapabilities = [.standardInput]
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.capabilities = capabilities
    }

    public func prepare(
        request: RunRequest,
        workspace: RunWorkspace,
        emit: @Sendable (RunEvent) -> Void
    ) async throws -> SubprocessPreparation {
        .run(SubprocessInvocation(
            executablePath: executablePath,
            arguments: arguments + request.arguments
        ))
    }
}
