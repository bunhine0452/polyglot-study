internal import Foundation
public import LanguageKit
internal import LearnCore

/// C++ 트랙의 실행 준비 — `clang++` 로 워크스페이스 안에 실행 파일을 만든다.
///
/// `SwiftProgram` 과 같은 모양이고 같은 이유로 컴파일을 런처 rlimit **밖**에 둔다:
/// 컴파일은 사용자 코드가 아니라 툴체인이 도는 단계라, `RLIMIT_CPU` 5초를 컴파일러에
/// 걸면 정상적인 제출도 SIGXCPU 로 죽는다. "절대 매달리지 않을 것" 만 `BoundedCommand`
/// 의 시간 상한으로 보장한다.
public struct CppProgram: SubprocessProgram {
    /// nil 이면 `LanguageToolchain` 이 고른다.
    public var compilerPath: String?
    public var defaultEntryPoint: String
    /// 컴파일 한 건의 상한.
    public var compileTimeout: Duration
    /// `-std=` 에 넘길 표준. 트랙 전체가 한 값을 쓴다 — 레슨마다 다르면 학습자가 쓴
    /// 코드가 어느 표준에서 도는지 알 수 없다.
    public var languageStandard: String

    public init(
        compilerPath: String? = nil,
        defaultEntryPoint: String = "main.cpp",
        compileTimeout: Duration = .seconds(60),
        languageStandard: String = "c++20"
    ) {
        self.compilerPath = compilerPath
        self.defaultEntryPoint = defaultEntryPoint
        self.compileTimeout = compileTimeout
        self.languageStandard = languageStandard
    }

    public var capabilities: RunnerCapabilities { [.standardInput, .compileDiagnostics] }

    /// 산출 실행 파일 이름. 사용자 소스와 부딪히지 않게 예약어처럼 생긴 이름을 쓴다.
    public static let productName = "__learnkit_main"

    /// 컴파일 대상으로 삼는 확장자. 헤더는 여기 없다 — 번역 단위가 아니라 include 된다.
    public static let sourceExtensions = ["cpp", "cc", "cxx"]

    public func prepare(
        request: RunRequest,
        workspace: RunWorkspace,
        emit: @Sendable (RunEvent) -> Void
    ) async throws -> SubprocessPreparation {
        let sources = try Self.sourcePaths(for: request, fallback: defaultEntryPoint)
        let compiler = try await resolveCompiler()

        emit(.phase(.compiling))
        let product = workspace.root.appendingPathComponent(Self.productName)
        let clock = ContinuousClock()
        let started = clock.now
        let result = await BoundedCommand.run(
            executable: compiler,
            arguments: Self.compilerArguments(
                sources: sources, output: Self.productName, standard: languageStandard),
            workingDirectory: workspace.root.path,
            timeout: compileTimeout
        )
        let elapsed = Int(started.duration(to: clock.now).milliseconds)

        if let failure = result.launchFailure {
            throw RunFailure.toolchainMissing(hint: "\(compiler) 를 실행할 수 없다: \(failure)")
        }
        if result.timedOut {
            throw RunFailure.backend("컴파일이 \(compileTimeout) 안에 끝나지 않았다")
        }

        let text = result.combinedOutput
        for diagnostic in CppDiagnosticParser.parse(text, workspaceRoot: workspace.root.path) {
            emit(.diagnostic(diagnostic))
        }
        // 원문도 흘려보낸다 — 정규화가 놓친 `In file included from` 사슬을 학습자는 보고 싶어 한다.
        if !text.isEmpty {
            let bytes = Data(text.utf8).prefix(max(0, request.limits.outputBytes))
            if !bytes.isEmpty { emit(.standardError(Data(bytes))) }
        }

        guard result.exitCode == 0, FileManager.default.isExecutableFile(atPath: product.path) else {
            // 컴파일 오류는 백엔드 실패가 아니라 **정상적인 실행 결과**다. 진단을 이미
            // 흘렸으니 종료로 접는다 — 코드는 컴파일러가 낸 그것을 그대로 쓴다.
            return .finished(RunTermination(
                status: .failed(code: result.exitCode == 0 ? nil : result.exitCode),
                durationMilliseconds: elapsed
            ))
        }

        return .run(SubprocessInvocation(
            executablePath: product.path,
            arguments: request.arguments
        ))
    }

    func resolveCompiler() async throws -> String {
        if let compilerPath {
            guard FileManager.default.isExecutableFile(atPath: compilerPath) else {
                throw RunFailure.toolchainMissing(hint: "clang++ 가 \(compilerPath) 에 없다.")
            }
            return compilerPath
        }
        return try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.cpp)
    }

    static func compilerArguments(
        sources: [String], output: String, standard: String
    ) -> [String] {
        // 두 플래그는 파싱 가능한 진단을 얻기 위한 최소 집합이다 — `CppDiagnosticParser`
        // 의 주석에 이유가 있다. `-Wall` 은 학습용이라 켠다: 초심자가 가장 많이 밟는
        // 것들(미사용 변수, 부호 비교)이 여기서 잡히고, 경고는 실행을 막지 않는다.
        [
            "-std=\(standard)", "-Wall",
            "-fno-color-diagnostics", "-fno-caret-diagnostics",
            "-o", output,
        ] + sources
    }

    /// 진입점이 맨 앞에 오도록 정렬한 소스 목록.
    ///
    /// C++ 는 Swift 와 달리 파일 이름으로 진입점을 알아보지 않는다(`main` 함수가 어디에
    /// 있든 링커가 찾는다). 그래도 순서를 맞추는 이유는 진단이 나오는 순서를 예측
    /// 가능하게 두기 위해서다 — 학습자가 고칠 파일이 맨 위에 뜬다.
    static func sourcePaths(for request: RunRequest, fallback: String) throws -> [String] {
        let files = request.files.map(\.path).filter { path in
            sourceExtensions.contains { path.hasSuffix(".\($0)") }
        }
        guard !files.isEmpty else {
            throw RunFailure.backend("컴파일할 .cpp 파일이 없습니다")
        }
        if let entryPoint = request.entryPoint {
            guard files.contains(entryPoint) else {
                throw RunFailure.backend("진입점 파일을 찾을 수 없음: \(entryPoint)")
            }
            return [entryPoint] + files.filter { $0 != entryPoint }
        }
        if files.contains(fallback) {
            return [fallback] + files.filter { $0 != fallback }
        }
        return files
    }
}
