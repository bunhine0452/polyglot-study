internal import Foundation
public import LanguageKit
internal import LearnCore

/// Swift 트랙의 실행 준비 — `swiftc` 로 워크스페이스 안에 실행 파일을 만든다.
///
/// 컴파일은 **사용자 코드가 아니라 툴체인**이 도는 단계라 런처 rlimit 아래 두지 않는다.
/// `RLIMIT_CPU` 5초를 컴파일러에 걸면 정상적인 제출도 SIGXCPU 로 죽는다. 대신
/// `BoundedCommand` 의 시간 상한으로 "절대 매달리지 않을 것"만 보장한다.
public struct SwiftProgram: SubprocessProgram {
    /// nil 이면 `LanguageToolchain` 이 고른다.
    public var compilerPath: String?
    public var defaultEntryPoint: String
    /// 컴파일 한 건의 상한.
    public var compileTimeout: Duration
    /// 사용자 파일 끝에 `import Foundation` 을 덧붙일지.
    ///
    /// **줄 끝에 붙이는 이유가 있다.** Swift 의 `import` 는 파일 스코프 선언이라 위치와
    /// 무관하게 파일 전체에 적용되고, 맨 뒤에 붙이면 **사용자 코드의 줄 번호가 하나도
    /// 밀리지 않는다** — 진단의 line/column 을 보정할 필요가 없다는 뜻이다.
    /// (앞에 붙이면 모든 진단을 -1 해야 하고, 그 보정은 반드시 어딘가에서 어긋난다.)
    /// 이미 `import Foundation` 이 있어도 중복 경고는 나지 않는다(실측).
    public var implicitFoundationImport: Bool

    public init(
        compilerPath: String? = nil,
        defaultEntryPoint: String = "main.swift",
        compileTimeout: Duration = .seconds(60),
        implicitFoundationImport: Bool = true
    ) {
        self.compilerPath = compilerPath
        self.defaultEntryPoint = defaultEntryPoint
        self.compileTimeout = compileTimeout
        self.implicitFoundationImport = implicitFoundationImport
    }

    public var capabilities: RunnerCapabilities { [.standardInput, .compileDiagnostics] }

    /// 산출 실행 파일 이름. 사용자 소스와 부딪히지 않게 예약어처럼 생긴 이름을 쓴다.
    public static let productName = "__learnkit_main"

    public func prepare(
        request: RunRequest,
        workspace: RunWorkspace,
        emit: @Sendable (RunEvent) -> Void
    ) async throws -> SubprocessPreparation {
        let sources = try Self.sourcePaths(for: request, fallback: defaultEntryPoint)
        let compiler = try await resolveCompiler()

        if implicitFoundationImport {
            for path in sources {
                try Self.appendFoundationImport(at: workspace.url(for: path))
            }
        }

        emit(.phase(.compiling))
        let product = workspace.root.appendingPathComponent(Self.productName)
        let clock = ContinuousClock()
        let started = clock.now
        let result = await BoundedCommand.run(
            executable: compiler,
            arguments: Self.compilerArguments(sources: sources, output: Self.productName),
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
        for diagnostic in SwiftDiagnosticParser.parse(text, workspaceRoot: workspace.root.path) {
            emit(.diagnostic(diagnostic))
        }
        // 원문도 흘려보낸다 — 정규화가 놓친 캐럿·주석 줄을 학습자는 보고 싶어 한다.
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
                throw RunFailure.toolchainMissing(hint: "swiftc 가 \(compilerPath) 에 없다.")
            }
            return compilerPath
        }
        return try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.swift)
    }

    static func compilerArguments(sources: [String], output: String) -> [String] {
        // 세 플래그는 파싱 가능한 진단을 얻기 위한 최소 집합이다. `SwiftDiagnosticParser`
        // 의 주석에 각각의 이유가 적혀 있다.
        ["-diagnostic-style=llvm", "-no-color-diagnostics", "-print-diagnostic-groups", "-o", output]
            + sources
    }

    /// 진입점이 맨 앞에 오도록 정렬한 소스 목록.
    ///
    /// `swiftc` 는 `main.swift` 를 이름으로 알아보므로 순서 자체는 중요하지 않지만,
    /// 진입점이 요청 안에 실재하는지는 여기서 확인해야 한다.
    static func sourcePaths(for request: RunRequest, fallback: String) throws -> [String] {
        let swiftFiles = request.files.map(\.path).filter { $0.hasSuffix(".swift") }
        guard !swiftFiles.isEmpty else {
            throw RunFailure.backend("컴파일할 .swift 파일이 없습니다")
        }
        if let entryPoint = request.entryPoint {
            guard swiftFiles.contains(entryPoint) else {
                throw RunFailure.backend("진입점 파일을 찾을 수 없음: \(entryPoint)")
            }
            return [entryPoint] + swiftFiles.filter { $0 != entryPoint }
        }
        if swiftFiles.contains(fallback) {
            return [fallback] + swiftFiles.filter { $0 != fallback }
        }
        return swiftFiles
    }

    static func appendFoundationImport(at url: URL) throws {
        guard let handle = FileHandle(forWritingAtPath: url.path) else {
            throw RunFailure.backend("소스 파일을 열 수 없습니다: \(url.lastPathComponent)")
        }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("\nimport Foundation\n".utf8))
        } catch {
            throw RunFailure.backend("소스 파일에 쓸 수 없습니다: \(error)")
        }
    }
}
