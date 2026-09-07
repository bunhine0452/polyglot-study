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

/// C++ 트랙.
///
/// Swift 와 달리 채점기가 러너와 **같은 길**을 간다 — 숨은 테스트는 번역 단위 하나가
/// 더 붙는 것뿐이라 워크스페이스에 파일을 던져 넣으면 끝이다. SwiftPM 패키지를 굽는
/// Swift 쪽이 예외적인 것이지 이쪽이 특별한 것이 아니다.
public struct CppLanguageModule: LanguageModule {
    public static let id = LanguageID.cpp

    public var runnerConfiguration: SubprocessRunnerConfiguration
    public var compilerPath: String?
    /// 트랙 전체가 한 표준을 쓴다 — 레슨마다 다르면 학습자가 쓴 코드가 어느 표준에서
    /// 도는지 알 수 없다.
    public var languageStandard: String

    public init(
        runnerConfiguration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration(),
        compilerPath: String? = nil,
        languageStandard: String = "c++20"
    ) {
        self.runnerConfiguration = runnerConfiguration
        self.compilerPath = compilerPath
        self.languageStandard = languageStandard
    }

    public var displayName: String { "C++" }
    /// 헤더도 센다 — 에디터가 이 집합으로 파일을 알아본다. 컴파일 대상 판정은
    /// `CppProgram.sourceExtensions` 가 따로 한다(헤더는 번역 단위가 아니다).
    public var fileExtensions: Set<String> { ["cpp", "cc", "cxx", "h", "hpp"] }
    public var presenter: GradeResult.Presenter { .console }

    public func probe() async -> ModuleAvailability {
        await LanguageToolchain.shared.availability(for: ToolchainCatalog.cpp)
    }

    public func makeRunner() throws -> any CodeRunner {
        SubprocessRunner(
            program: CppProgram(
                compilerPath: compilerPath, languageStandard: languageStandard),
            configuration: runnerConfiguration
        )
    }

    public func makeGrader() -> CppAssertGrader {
        CppAssertGrader(
            compilerPath: compilerPath,
            runnerConfiguration: runnerConfiguration,
            languageStandard: languageStandard
        )
    }
}

/// Rust 트랙.
///
/// C++ 과 같은 이유로 채점기가 러너와 같은 길을 간다 — 숨은 테스트는 크레이트 루트에
/// `include!` 로 붙는 것뿐이다. `cargo` 를 쓰지 않으므로 예열 템플릿도, 그에 딸린
/// 상호 배제도 없다(`RustTestGrader` 주석 참고).
public struct RustLanguageModule: LanguageModule {
    public static let id = LanguageID.rust

    public var runnerConfiguration: SubprocessRunnerConfiguration
    public var compilerPath: String?
    /// 트랙 전체가 한 에디션을 쓴다 — 레슨마다 다르면 학습자가 쓴 코드가 어느 에디션에서
    /// 도는지 알 수 없다.
    public var edition: String

    public init(
        runnerConfiguration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration(),
        compilerPath: String? = nil,
        edition: String = "2021"
    ) {
        self.runnerConfiguration = runnerConfiguration
        self.compilerPath = compilerPath
        self.edition = edition
    }

    public var displayName: String { "Rust" }
    public var fileExtensions: Set<String> { ["rs"] }
    public var presenter: GradeResult.Presenter { .console }

    public func probe() async -> ModuleAvailability {
        await LanguageToolchain.shared.availability(for: ToolchainCatalog.rust)
    }

    public func makeRunner() throws -> any CodeRunner {
        SubprocessRunner(
            program: RustProgram(compilerPath: compilerPath, edition: edition),
            configuration: runnerConfiguration
        )
    }

    public func makeGrader() -> RustTestGrader {
        RustTestGrader(
            compilerPath: compilerPath,
            runnerConfiguration: runnerConfiguration,
            edition: edition
        )
    }
}
