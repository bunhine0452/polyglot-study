public import LanguageKit
public import LearnCore

/// Python 트랙.
///
/// 러너를 여기서 만들지만 **설정은 밖에서 받는다** — 앱과 테스트가 같은 모듈로
/// 다른 런처·워크스페이스를 쓸 수 있어야 한다.
public struct PythonLanguageModule: LanguageModule {
    public static let id = LanguageID.python

    public var runnerConfiguration: SubprocessRunnerConfiguration
    public var interpreterPath: String?

    public init(
        runnerConfiguration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration(),
        interpreterPath: String? = nil
    ) {
        self.runnerConfiguration = runnerConfiguration
        self.interpreterPath = interpreterPath
    }

    public var displayName: String { "Python" }
    public var fileExtensions: Set<String> { ["py"] }
    public var presenter: GradeResult.Presenter { .console }

    public func probe() async -> ModuleAvailability {
        await LanguageToolchain.shared.availability(for: ToolchainCatalog.python)
    }

    public func makeRunner() throws -> any CodeRunner {
        SubprocessRunner(
            program: PythonProgram(interpreterPath: interpreterPath),
            configuration: runnerConfiguration
        )
    }

    /// 숨은 `unittest` 로 채점한다. 러너와 같은 격리를 지난다.
    public func makeGrader() -> PythonUnittestGrader {
        PythonUnittestGrader(
            interpreterPath: interpreterPath,
            runnerConfiguration: runnerConfiguration
        )
    }
}

/// Swift 트랙.
public struct SwiftLanguageModule: LanguageModule {
    public static let id = LanguageID.swift

    public var runnerConfiguration: SubprocessRunnerConfiguration
    public var compilerPath: String?

    public init(
        runnerConfiguration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration(),
        compilerPath: String? = nil
    ) {
        self.runnerConfiguration = runnerConfiguration
        self.compilerPath = compilerPath
    }

    public var displayName: String { "Swift" }
    public var fileExtensions: Set<String> { ["swift"] }
    public var presenter: GradeResult.Presenter { .console }

    public func probe() async -> ModuleAvailability {
        await LanguageToolchain.shared.availability(for: ToolchainCatalog.swift)
    }

    public func makeRunner() throws -> any CodeRunner {
        SubprocessRunner(
            program: SwiftProgram(compilerPath: compilerPath),
            configuration: runnerConfiguration
        )
    }

    /// 채점은 러너와 다른 길을 간다 — Swift Testing 을 돌리려면 SwiftPM 패키지가
    /// 필요하고, 그건 워크스페이스 하나에 소스를 던져 넣는 것으로는 안 된다.
    public func makeGrader() -> SwiftTestingGrader {
        SwiftTestingGrader()
    }
}
