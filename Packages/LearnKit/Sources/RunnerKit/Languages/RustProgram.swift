internal import Foundation
public import LanguageKit
internal import LearnCore

/// Rust 트랙의 실행 준비 — `rustc` 로 워크스페이스 안에 실행 파일을 만든다.
///
/// **cargo 를 쓰지 않는다.** 예제 하나를 돌리는 데 Cargo 프로젝트를 굽는 것은 과하고,
/// 그러면 Swift 채점기처럼 **예열된 템플릿을 공유**하게 되어 그 자리의 동시 접근 결함을
/// 그대로 물려받는다(HANDOFF "동시성" 참고). `rustc` 한 번이면 끝나는 일이라 공유 자원을
/// 만들지 않는다.
///
/// 컴파일을 런처 rlimit **밖**에 두는 이유는 `SwiftProgram`·`CppProgram` 과 같다:
/// 컴파일은 사용자 코드가 아니라 툴체인이 도는 단계라 `RLIMIT_CPU` 를 걸면 정상적인
/// 제출도 SIGXCPU 로 죽는다.
public struct RustProgram: SubprocessProgram {
    /// nil 이면 `LanguageToolchain` 이 고른다.
    public var compilerPath: String?
    public var defaultEntryPoint: String
    /// 컴파일 한 건의 상한.
    public var compileTimeout: Duration
    /// `--edition`. 트랙 전체가 한 값을 쓴다 — 레슨마다 다르면 학습자가 쓴 코드가 어느
    /// 에디션에서 도는지 알 수 없다.
    public var edition: String
    /// `--test` 로 테스트 하네스를 링크할지. 채점기가 켠다.
    public var buildsTestHarness: Bool

    public init(
        compilerPath: String? = nil,
        defaultEntryPoint: String = "main.rs",
        compileTimeout: Duration = .seconds(60),
        edition: String = "2021",
        buildsTestHarness: Bool = false
    ) {
        self.compilerPath = compilerPath
        self.defaultEntryPoint = defaultEntryPoint
        self.compileTimeout = compileTimeout
        self.edition = edition
        self.buildsTestHarness = buildsTestHarness
    }

    public var capabilities: RunnerCapabilities { [.standardInput, .compileDiagnostics] }

    /// 산출 실행 파일 이름. 사용자 소스와 부딪히지 않게 예약어처럼 생긴 이름을 쓴다.
    public static let productName = "__learnkit_main"

    public func prepare(
        request: RunRequest,
        workspace: RunWorkspace,
        emit: @Sendable (RunEvent) -> Void
    ) async throws -> SubprocessPreparation {
        // **rustc 는 크레이트 루트 하나만 받는다.** C++ 처럼 여러 파일을 나열할 수 없다 —
        // 나머지는 루트가 `mod`·`include!` 로 끌어온다. 그래서 진입점이 필수다.
        let root = try Self.crateRoot(for: request, fallback: defaultEntryPoint)
        let compiler = try await resolveCompiler()

        emit(.phase(.compiling))
        let product = workspace.root.appendingPathComponent(Self.productName)
        let clock = ContinuousClock()
        let started = clock.now
        let result = await BoundedCommand.run(
            executable: compiler,
            arguments: Self.compilerArguments(
                crateRoot: root, output: Self.productName,
                edition: edition, test: buildsTestHarness),
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
        let diagnostics = RustDiagnosticParser.parse(text, workspaceRoot: workspace.root.path)
        for diagnostic in diagnostics {
            emit(.diagnostic(diagnostic))
        }
        // **JSON 원문은 흘려보내지 않는다.** swiftc·clang 은 사람이 읽을 텍스트를 내서
        // 원문을 그대로 보여주는 것이 도움이 되지만, 여기서는 한 줄이 수 KB 짜리
        // `explanation` 을 달고 있어 콘솔이 JSON 으로 뒤덮인다. 사람이 읽을 형태는
        // 인라인 진단 행이 이미 그린다.
        if result.exitCode != 0, diagnostics.isEmpty, !text.isEmpty {
            // 진단을 하나도 못 뽑았는데 실패했다면 원문이 유일한 단서다.
            let bytes = Data(text.utf8).prefix(max(0, request.limits.outputBytes))
            if !bytes.isEmpty { emit(.standardError(Data(bytes))) }
        }

        guard result.exitCode == 0, FileManager.default.isExecutableFile(atPath: product.path) else {
            // 컴파일 오류는 백엔드 실패가 아니라 **정상적인 실행 결과**다.
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
                throw RunFailure.toolchainMissing(hint: "rustc 가 \(compilerPath) 에 없다.")
            }
            return compilerPath
        }
        return try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.rust)
    }

    static func compilerArguments(
        crateRoot: String, output: String, edition: String, test: Bool
    ) -> [String] {
        var arguments = [
            "--edition", edition,
            // 셋 중 유일하게 구조화 진단이 있다 — `RustDiagnosticParser` 참고.
            "--error-format=json",
            "-o", output,
        ]
        if test { arguments.append("--test") }
        arguments.append(crateRoot)
        return arguments
    }

    /// 컴파일할 크레이트 루트 한 개.
    ///
    /// rustc 는 파일 목록이 아니라 **루트 하나**를 받는다. 이름 규칙이 없으므로 진입점을
    /// 못 고르면 실패로 끝내는 편이 낫다 — 아무 `.rs` 나 고르면 학습자가 못 읽는 오류가 난다.
    static func crateRoot(for request: RunRequest, fallback: String) throws -> String {
        let files = request.files.map(\.path).filter { $0.hasSuffix(".rs") }
        guard !files.isEmpty else {
            throw RunFailure.backend("컴파일할 .rs 파일이 없습니다")
        }
        if let entryPoint = request.entryPoint {
            guard files.contains(entryPoint) else {
                throw RunFailure.backend("진입점 파일을 찾을 수 없음: \(entryPoint)")
            }
            return entryPoint
        }
        if files.contains(fallback) { return fallback }
        if files.count == 1 { return files[0] }
        throw RunFailure.backend(
            "크레이트 루트를 고를 수 없습니다 — \(fallback) 이 없고 .rs 파일이 여럿입니다")
    }
}
