public import Foundation
public import LearnCore
public import LanguageKit

/// Swift Testing 채점 한 번의 전부.
public struct SwiftGrading: Sendable {
    public var result: GradeResult
    /// 빌드가 실패해 테스트가 아예 돌지 못했는가.
    public var buildFailed: Bool
    /// `swift test` 원문. 이벤트 스트림이 비었을 때 사람이 볼 마지막 근거.
    public var rawOutput: String

    public var passed: Bool { result.passed }
}

/// 예열된 SwiftPM 템플릿에 제출과 숨은 테스트만 갈아끼워 채점한다.
///
/// **매번 새 패키지를 만들지 않는 이유**는 시간이다. 빈 SwiftPM 패키지의 첫
/// `swift build --build-tests` 는 십수 초가 걸리고 그 대부분이 테스트 하네스와
/// 의존 모듈 컴파일이다. 같은 디렉터리를 재사용하면 두 번째부터는 사용자 파일만
/// 다시 컴파일하므로 수 초로 떨어진다.
///
/// **`--event-stream-output-path` 는 `swift test --help` 에 안 나오지만 실재한다.**
/// (실측 2026-09-06, Swift 6.3.3 / Testing 1902) `--event-stream-version 0` 과 함께
/// 주면 JSON Lines 가 지정 경로에 쌓인다. 사람이 읽는 콘솔 출력과 달리 이 스트림은
/// 형식이 고정돼 있고 **사용자 코드의 `print` 가 섞이지 않는다** — 파일이 따로이기
/// 때문이다. 플래그가 사라지는 날을 대비해 `--xunit-output` 폴백을 둔다.
public actor SwiftTestingGrader {
    public struct Configuration: Sendable {
        /// 예열된 패키지가 사는 곳. 프로세스 수명을 넘어 살아남아야 예열이 의미가 있다.
        public var templateDirectory: URL
        /// nil 이면 `swiftc` 옆의 `swift` 를 쓴다.
        public var swiftExecutablePath: String?
        public var buildTimeout: Duration
        public var testTimeout: Duration
        /// SwiftPM 에 넘길 `-j`.
        ///
        /// 상한을 두는 이유는 채점이 **앱이 돌아가는 동안** 일어나기 때문이다.
        /// 기본값의 SwiftPM 은 모든 코어를 가져가고, 그러면 채점 몇 초 동안 UI 와
        /// 다른 실행이 같이 굶는다. 절반이면 예열된 증분 빌드에는 체감 차이가 없다.
        public var buildJobs: Int

        public init(
            templateDirectory: URL = SwiftTestingGrader.defaultTemplateDirectory,
            swiftExecutablePath: String? = nil,
            buildTimeout: Duration = .seconds(300),
            testTimeout: Duration = .seconds(120),
            buildJobs: Int = max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
        ) {
            self.templateDirectory = templateDirectory
            self.swiftExecutablePath = swiftExecutablePath
            self.buildTimeout = buildTimeout
            self.testTimeout = testTimeout
            self.buildJobs = buildJobs
        }
    }

    public static let solutionTarget = "Solution"
    public static let testTarget = "SolutionTests"

    public static var defaultTemplateDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-swift-template", isDirectory: true)
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - 예열

    /// 템플릿을 만들고 테스트 하네스까지 미리 빌드한다.
    ///
    /// 앱은 Swift 레슨을 처음 열 때 이걸 백그라운드로 부른다. 부르지 않아도 첫
    /// 채점이 대신 하지만, 그러면 그 한 번이 십수 초 걸린다.
    @discardableResult
    public func warmUp() async throws -> Duration {
        // 게이트는 ``grade(solution:tests:)`` 의 주석에 적힌 이유로 **여기 펼쳐** 둔다.
        let template = ExecutionLimits.swiftTemplateGate(for: configuration.templateDirectory)
        await template.acquire()
        defer { template.release() }
        await ExecutionLimits.spawns.acquire()
        defer { ExecutionLimits.spawns.release() }

        let clock = ContinuousClock()
        let started = clock.now
        try materializeTemplate()
        // 지난 채점이 남긴 소스 위에서 예열하면 그 제출의 컴파일 오류가 예열 실패로
        // 둔갑한다. 예열은 항상 빈 자리표 위에서 한다.
        try replaceSources(solution: [], tests: [])
        let swift = try await resolveSwift()
        let result = await BoundedCommand.run(
            executable: swift,
            arguments: ["build", "--build-tests", "-j", String(configuration.buildJobs)],
            workingDirectory: configuration.templateDirectory.path,
            timeout: configuration.buildTimeout
        )
        guard result.launchFailure == nil, !result.timedOut, result.exitCode == 0 else {
            throw RunFailure.backend("템플릿 예열 실패: \(result.combinedOutput)")
        }
        return started.duration(to: clock.now)
    }

    // MARK: - 채점

    /// 템플릿 하나를 **한 번에 하나씩** 쓰게 하고, 전역 스폰 상한도 함께 지난다.
    ///
    /// 문지기를 호출자가 아니라 여기 두는 이유는 인스턴스가 상호 배제의 단위가 아니기
    /// 때문이다 — `EditorModel.defaultGrade` 는 채점할 때마다 `SwiftTestingGrader()` 를
    /// 새로 만들지만 ``defaultTemplateDirectory`` 는 **고정 경로**다. 액터 경계로는 아무것도
    /// 막지 못하고, 겹치면 한쪽이 다른 쪽의 `Solution.swift` 를 덮어쓴다.
    /// 획득 순서는 언제나 **템플릿 → 스폰**이다(반대로 잡는 곳이 없으므로 교착이 없다).
    ///
    /// ⚠︎ **이 함수를 쪼개지 마라.** 게이트를 제네릭 래퍼로 감싸거나 본문을
    /// `performGrade(...)` 로 떼어 내고 여기서 `return try await performGrade(…)` 로
    /// 넘기면, 돌아오는 ``SwiftGrading`` 이 **깨진다** — `GradeResult.hasErrors` 가
    /// `EXC_BAD_ACCESS`(0x10, 배열 버퍼가 쓰레기)로 죽는다. 실측 2026-09-07, Swift 6.3.3:
    /// 래퍼 방식 6/6 재현, 단순 전달(`grade` → `performGrade`) 2/2 재현, 한 함수로 되돌리면
    /// 0/5. 액터 격리 함수 하나를 더 거쳐 이 구조체를 돌려보내는 것 자체가 방아쇠다.
    public func grade(solution: [SourceFile], tests: [SourceFile]) async throws -> SwiftGrading {
        let template = ExecutionLimits.swiftTemplateGate(for: configuration.templateDirectory)
        await template.acquire()
        defer { template.release() }
        await ExecutionLimits.spawns.acquire()
        defer { ExecutionLimits.spawns.release() }

        try materializeTemplate()
        let swift = try await resolveSwift()
        try replaceSources(solution: solution, tests: tests)

        let eventPath = configuration.templateDirectory
            .appendingPathComponent(".learnkit-events.jsonl")
        try? FileManager.default.removeItem(at: eventPath)

        let clock = ContinuousClock()
        let started = clock.now
        var usedFallback = false
        var result = await BoundedCommand.run(
            executable: swift,
            arguments: [
                "test",
                "-j", String(configuration.buildJobs),
                "--event-stream-output-path", eventPath.path,
                "--event-stream-version", "0",
            ],
            workingDirectory: configuration.templateDirectory.path,
            timeout: configuration.testTimeout
        )
        // 플래그가 사라졌다면 SwiftPM 이 인자 파싱 단계에서 죽는다 — 그 경우에만 폴백.
        if Self.rejectedEventStreamFlag(result) {
            usedFallback = true
            result = await BoundedCommand.run(
                executable: swift,
                arguments: [
                    "test",
                    "-j", String(configuration.buildJobs),
                    "--xunit-output",
                    eventPath.deletingPathExtension().appendingPathExtension("xml").path,
                ],
                workingDirectory: configuration.templateDirectory.path,
                timeout: configuration.testTimeout
            )
        }
        let elapsed = Int(started.duration(to: clock.now).milliseconds)

        let output = result.combinedOutput
        if result.timedOut {
            throw RunFailure.wallClockExceeded(seconds: Int(configuration.testTimeout.milliseconds / 1000))
        }
        if let failure = result.launchFailure {
            throw RunFailure.toolchainMissing(hint: "\(swift) 를 실행할 수 없다: \(failure)")
        }

        let outcomes: [GradeResult.TestOutcome]
        if usedFallback {
            outcomes = SwiftTestingEventStream.parseXUnit(
                at: eventPath.deletingPathExtension().appendingPathExtension("xml")
            )
        } else {
            outcomes = SwiftTestingEventStream.parse(at: eventPath)
        }

        // 이벤트가 하나도 없으면 테스트가 돌기 전에 죽은 것이다 — 대개 컴파일 실패다.
        let buildFailed = outcomes.isEmpty && result.exitCode != 0
        let diagnostics = SwiftDiagnosticParser.parse(
            output,
            workspaceRoot: configuration.templateDirectory.path
        )

        var tests = outcomes
        if tests.isEmpty {
            tests = [GradeResult.TestOutcome(
                name: buildFailed ? "빌드" : "테스트 실행",
                passed: false,
                message: Self.firstErrorMessage(diagnostics) ?? Self.tail(output)
            )]
        }

        let result_ = GradeResult(
            passed: result.exitCode == 0 && !outcomes.isEmpty && outcomes.allSatisfy(\.passed),
            tests: tests,
            diagnostics: diagnostics,
            stdout: output,
            stderr: "",
            exitCode: result.exitCode,
            durationMilliseconds: elapsed,
            presenter: .console
        )
        return SwiftGrading(result: result_, buildFailed: buildFailed, rawOutput: output)
    }

    // MARK: - 템플릿

    private func materializeTemplate() throws {
        let fileManager = FileManager.default
        let root = configuration.templateDirectory
        let sources = root.appendingPathComponent("Sources/\(Self.solutionTarget)", isDirectory: true)
        let tests = root.appendingPathComponent("Tests/\(Self.testTarget)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: tests, withIntermediateDirectories: true)
            let manifest = root.appendingPathComponent("Package.swift")
            let desired = Self.manifestSource
            // 매번 쓰지 않는다 — mtime 이 바뀌면 SwiftPM 이 매니페스트를 다시 평가한다.
            if (try? String(contentsOf: manifest, encoding: .utf8)) != desired {
                try desired.write(to: manifest, atomically: true, encoding: .utf8)
            }
            // 빈 타깃은 SwiftPM 이 "buildable target 이 없다"로 거부한다 — 예열이
            // 소스보다 먼저 오므로 자리를 지키는 파일이 처음부터 있어야 한다.
            try seedPlaceholderIfEmpty(sources, contents: Self.solutionPlaceholder)
            try seedPlaceholderIfEmpty(tests, contents: Self.testPlaceholder)
        } catch {
            throw RunFailure.backend("Swift 채점 템플릿을 만들 수 없다: \(error)")
        }
    }

    private func seedPlaceholderIfEmpty(_ directory: URL, contents: String) throws {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        guard !entries.contains(where: { $0.hasSuffix(".swift") }) else { return }
        try contents.write(
            to: directory.appendingPathComponent("__Placeholder.swift"),
            atomically: false,
            encoding: .utf8
        )
    }

    private func replaceSources(solution: [SourceFile], tests: [SourceFile]) throws {
        try write(solution, into: "Sources/\(Self.solutionTarget)", placeholder: Self.solutionPlaceholder)
        try write(tests, into: "Tests/\(Self.testTarget)", placeholder: Self.testPlaceholder)
    }

    private func write(_ files: [SourceFile], into relativeDirectory: String, placeholder: String) throws {
        let fileManager = FileManager.default
        let directory = configuration.templateDirectory
            .appendingPathComponent(relativeDirectory, isDirectory: true)
        // 지난 채점의 파일이 남으면 다음 제출이 그 심볼을 그대로 쓴다 — 조용한 오답이다.
        let existing = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for entry in existing where entry.hasSuffix(".swift") {
            try? fileManager.removeItem(at: directory.appendingPathComponent(entry))
        }
        var wrote = false
        for file in files {
            let normalized = try WorkspacePathPolicy.normalize(file.path)
            guard normalized.hasSuffix(".swift") else { continue }
            let url = directory.appendingPathComponent(normalized)
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try file.contents.write(to: url, atomically: false, encoding: .utf8)
            wrote = true
        }
        if !wrote {
            // 빈 타깃은 SwiftPM 이 거부한다. 자리를 지키는 파일 하나는 있어야 한다.
            try placeholder.write(
                to: directory.appendingPathComponent("__Placeholder.swift"),
                atomically: false,
                encoding: .utf8
            )
        }
    }

    private func resolveSwift() async throws -> String {
        if let path = configuration.swiftExecutablePath {
            guard FileManager.default.isExecutableFile(atPath: path) else {
                throw RunFailure.toolchainMissing(hint: "swift 가 \(path) 에 없다.")
            }
            return path
        }
        let compiler = try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.swift)
        // `swift` 는 `swiftc` 의 형제다. 툴체인이 여럿일 때 PATH 로 다시 찾으면
        // 감지가 고른 것과 다른 툴체인이 걸릴 수 있다.
        let sibling = URL(fileURLWithPath: compiler)
            .deletingLastPathComponent()
            .appendingPathComponent("swift")
        guard FileManager.default.isExecutableFile(atPath: sibling.path) else {
            throw RunFailure.toolchainMissing(hint: "\(compiler) 옆에 swift 실행 파일이 없다.")
        }
        return sibling.path
    }

    static func rejectedEventStreamFlag(_ result: BoundedCommandResult) -> Bool {
        guard result.exitCode != 0 else { return false }
        let text = result.combinedOutput
        return text.contains("event-stream-output-path")
            && (text.contains("Unknown option") || text.contains("Unexpected argument"))
    }

    static func firstErrorMessage(_ diagnostics: [Diagnostic]) -> String? {
        diagnostics.first { $0.severity == .error }?.message
    }

    static func tail(_ text: String, lines: Int = 12) -> String {
        let all = text.split(separator: "\n", omittingEmptySubsequences: false)
        return all.suffix(lines).joined(separator: "\n")
    }

    static let manifestSource = """
        // swift-tools-version: 6.2
        import PackageDescription

        // learnkit 채점 템플릿. 외부 의존이 없어야 오프라인에서도 예열이 끝난다.
        let package = Package(
            name: "Solution",
            targets: [
                .target(name: "Solution"),
                .testTarget(name: "SolutionTests", dependencies: ["Solution"]),
            ]
        )

        """

    static let solutionPlaceholder = "// 제출이 비어 있습니다.\n"
    static let testPlaceholder = """
        import Testing

        @Test("숨은 테스트가 없습니다")
        func placeholder() { #expect(Bool(true)) }

        """
}
