public import Foundation
public import LanguageKit
public import LearnCore

/// Rust 테스트 하나의 결과.
///
/// 파이썬·C++ 과 같은 이유로 실패와 에러를 나눈다 — 다만 Rust 에서는 그 경계가 흐리다.
/// `assert_eq!` 도 패닉이고 `panic!` 도 패닉이라 libtest 는 둘을 구별하지 않는다.
/// 메시지 본문으로 가른다: `assertion ... failed` 로 시작하면 실패, 아니면 에러다.
public struct RustTestOutcome: Hashable, Sendable {
    public enum Status: String, Hashable, Sendable {
        case passed, failed, error, ignored
    }

    public var name: String
    public var status: Status
    public var message: String?

    public init(name: String, status: Status, message: String? = nil) {
        self.name = name
        self.status = status
        self.message = message
    }

    public var graded: GradeResult.TestOutcome {
        let prefixed: String?
        switch status {
        case .passed: prefixed = nil
        case .ignored: prefixed = "건너뜀"
        case .failed: prefixed = message
        case .error: prefixed = message.map { "에러: \($0)" } ?? "에러"
        }
        return GradeResult.TestOutcome(
            name: name, passed: status == .passed || status == .ignored, message: prefixed)
    }
}

/// 채점 한 번의 전부.
public struct RustGrading: Sendable {
    public var result: GradeResult
    public var outcomes: [RustTestOutcome]
    public var failure: RunFailure?

    public var passed: Bool { result.passed }
}

/// 숨은 `#[test]` 로 Rust 제출을 채점한다.
///
/// **`cargo test` 가 아니라 `rustc --test` 다.** cargo 는 프로젝트 디렉터리와 레지스트리
/// 인덱스를 원하고, 그걸 예열해 공유하면 Swift 채점기가 겪은 동시 접근 결함을 그대로
/// 물려받는다. `rustc --test` 는 크레이트 루트 하나를 테스트 바이너리로 굽고 끝이라
/// 공유 자원이 없다 — 그래서 여기에는 템플릿 게이트가 없다.
///
/// **결과의 정본은 `--logfile` 이 쓰는 파일이다.** libtest 의 진행 줄은 stdout 으로 나가고
/// 거기에는 사용자 코드의 `println!` 도 섞인다(테스트 안의 출력은 libtest 가 가로채지만
/// 그 밖은 아니다). 안정판에는 `--format json` 이 없으므로(nightly 전용), 상태는 파일에서
/// 읽고 **메시지만** stdout 에서 보조로 긁는다. 파일이 오염될 수 없으니 "어느 테스트가
/// 실패했나" 는 언제나 정확하고, 최악의 경우 메시지만 비게 된다.
public struct RustTestGrader: Sendable {
    public var compilerPath: String?
    public var runnerConfiguration: SubprocessRunnerConfiguration
    /// 숨은 테스트 파일 이름. 사용자 파일과 부딪히면 채점이 조용히 무너진다.
    public var testFileName: String
    public var edition: String

    public init(
        compilerPath: String? = nil,
        runnerConfiguration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration(),
        testFileName: String = "__learnkit_tests.rs",
        edition: String = "2021"
    ) {
        self.compilerPath = compilerPath
        self.runnerConfiguration = runnerConfiguration
        self.testFileName = testFileName
        self.edition = edition
    }

    /// 크레이트 루트. 제출과 테스트를 한 크레이트로 합친다.
    static let crateRootName = "__learnkit_main.rs"

    /// `include!` 로 잇는 이유: `mod` 로 나누면 학습자가 쓴 `pub` 없는 항목이 테스트에서
    /// 안 보인다. 텍스트 삽입이라 두 파일이 한 스코프에 들어가고, rustc 가 `include!` 의
    /// 스팬을 원본 파일로 되돌려 주므로 **진단의 줄 번호도 어긋나지 않는다**(실측).
    static func crateRoot(solutionPath: String, testsPath: String) -> String {
        """
        // learnkit 채점 크레이트 루트. 제출과 숨은 테스트를 한 스코프로 합친다.
        include!("\(solutionPath)");
        include!("\(testsPath)");
        """
    }

    /// - Parameters:
    ///   - solution: 학습자 제출. 크레이트 루트가 될 파일 하나여야 한다.
    ///   - tests: 숨은 테스트 본문 (`#[test]` 함수들).
    public func grade(
        solution: [SourceFile],
        tests: String,
        limits: ResourceLimits = .lesson,
        standardInput: Data? = nil
    ) async throws -> RustGrading {
        guard let submission = solution.first(where: { $0.path.hasSuffix(".rs") }) else {
            throw RunFailure.backend("채점할 .rs 파일이 없습니다")
        }

        // 결과는 워크스페이스 **바깥**에 쓴다. 워크스페이스는 실행이 끝나는 순간
        // 사라지므로 안에 쓰면 읽을 기회가 없다.
        let outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-grade-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }
        let logPath = outputDirectory.appendingPathComponent("results.log").path

        var files = solution
        files.append(SourceFile(path: testFileName, contents: tests))
        files.append(SourceFile(
            path: Self.crateRootName,
            contents: Self.crateRoot(solutionPath: submission.path, testsPath: testFileName)
        ))

        let runner = SubprocessRunner(
            program: RustProgram(
                compilerPath: compilerPath, edition: edition, buildsTestHarness: true),
            configuration: runnerConfiguration
        )
        let request = RunRequest(
            files: files,
            entryPoint: Self.crateRootName,
            // `--test-threads=1` 은 속도가 아니라 **결정성** 때문이다. 여러 스레드가
            // 같은 로그 파일에 쓰면 줄이 섞인다.
            arguments: ["--test-threads=1", "--logfile", logPath],
            standardInput: standardInput,
            limits: limits
        )

        var stdout = Data()
        var stderr = Data()
        var diagnostics: [Diagnostic] = []
        var termination: RunTermination?
        var failure: RunFailure?
        let clock = ContinuousClock()
        let started = clock.now
        do {
            for try await event in runner.run(request) {
                switch event {
                case .standardOutput(let data): stdout.append(data)
                case .standardError(let data): stderr.append(data)
                case .diagnostic(let value): diagnostics.append(value)
                case .finished(let value): termination = value
                default: break
                }
            }
        } catch let error as RunFailure {
            failure = error
        }
        let elapsed = Int(started.duration(to: clock.now).milliseconds)

        let statuses = Self.parseLog(at: logPath)
        let messages = Self.parseMessages(String(decoding: stdout, as: UTF8.self))
        let outcomes = statuses.map { entry in
            RustTestOutcome(
                name: entry.name,
                status: Self.classify(entry.status, message: messages[entry.name]),
                message: messages[entry.name]
            )
        }
        let passed = failure == nil && !outcomes.isEmpty
            && outcomes.allSatisfy { $0.status == .passed || $0.status == .ignored }

        var graded = outcomes.map(\.graded)
        if graded.isEmpty {
            // 로그가 없다 = 테스트 바이너리가 시작조차 못 했다(대개 컴파일 실패).
            graded = [GradeResult.TestOutcome(
                name: "테스트 실행",
                passed: false,
                message: failure.map(Self.describe) ?? Self.emptyReason(
                    diagnostics: diagnostics, stderr: stderr)
            )]
        }

        let result = GradeResult(
            passed: passed,
            tests: graded,
            diagnostics: diagnostics,
            stdout: String(decoding: stdout, as: UTF8.self),
            stderr: String(decoding: stderr, as: UTF8.self),
            exitCode: termination?.exitCode,
            durationMilliseconds: termination?.durationMilliseconds ?? elapsed,
            presenter: .console
        )
        return RustGrading(result: result, outcomes: outcomes, failure: failure)
    }

    // MARK: - libtest 출력 파싱

    struct LogEntry { var status: String; var name: String }

    /// `--logfile` 이 쓰는 형식은 `<status> <name>` 한 줄씩이다 (실측 2026-09-07):
    /// `ok learnkit_tests::더한다` · `failed learnkit_tests::터진다` · `ignored ...`
    static func parseLog(at path: String) -> [LogEntry] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        var entries: [LogEntry] = []
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            entries.append(LogEntry(
                status: String(parts[0]),
                name: String(parts[1]).trimmingCharacters(in: .whitespaces)))
        }
        return entries
    }

    /// 실패한 테스트의 패닉 메시지를 stdout 에서 긁는다.
    ///
    /// libtest 는 실패마다 `---- <이름> stdout ----` 블록을 내고 그 안에
    /// `thread '<이름>' panicked at <위치>:` 다음 줄부터 본문이 온다. 백트레이스 안내
    /// (`note: run with RUST_BACKTRACE=1`)는 학습자에게 쓸모가 없어 버린다.
    static func parseMessages(_ text: String) -> [String: String] {
        var messages: [String: String] = [:]
        var current: String?
        var buffer: [String] = []

        func flush() {
            guard let name = current else { return }
            let body = buffer
                .drop { $0.isEmpty }
                .filter { !$0.hasPrefix("note: run with") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty { messages[name] = body }
            current = nil
            buffer = []
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("---- "), line.hasSuffix(" stdout ----") {
                flush()
                current = String(line.dropFirst(5).dropLast(12))
                continue
            }
            // 블록의 끝은 다음 블록이거나 `failures:` 요약이다.
            if current != nil, line == "failures:" || line.hasPrefix("test result:") {
                flush()
                continue
            }
            guard current != nil else { continue }
            // `thread '이름' (4291162) panicked at 파일:줄:열:` 은 위치 안내다. 본문은
            // 다음 줄부터라 이 줄 자체는 남기지 않는다 — 위치는 진단이 이미 들고 있다.
            if line.hasPrefix("thread '") { continue }
            buffer.append(line)
        }
        flush()
        return messages
    }

    /// libtest 는 `assert_eq!` 실패와 `panic!` 을 똑같이 "failed" 로 적는다. 학습자에게는
    /// "답이 틀렸다" 와 "코드가 터졌다" 가 다른 조언이라 메시지로 가른다.
    static func classify(_ status: String, message: String?) -> RustTestOutcome.Status {
        switch status {
        case "ok": return .passed
        case "ignored": return .ignored
        default: break
        }
        guard let message else { return .error }
        return message.contains("assertion") ? .failed : .error
    }

    static func describe(_ failure: RunFailure) -> String {
        switch failure {
        case .toolchainMissing(let hint): "툴체인 없음: \(hint)"
        case .wallClockExceeded(let seconds): "\(seconds)초 안에 끝나지 않았다 (코드가 멈춰 있다)"
        case .cpuExceeded(let seconds): "CPU \(seconds)초를 다 썼다 (코드가 느리다)"
        case .memoryExceeded(let megabytes): "메모리 \(megabytes)MB 를 넘겼다"
        case .fileSizeExceeded(let bytes): "파일 크기 \(bytes)바이트를 넘겼다"
        case .cancelled: "취소됐다"
        case .backend(let message): "실행기 오류: \(message)"
        }
    }

    static func emptyReason(diagnostics: [Diagnostic], stderr: Data) -> String {
        if let firstError = diagnostics.first(where: { $0.severity == .error }) {
            let place = [firstError.file, firstError.line.map(String.init)]
                .compactMap { $0 }.joined(separator: ":")
            let code = firstError.ruleID.map { " [\($0)]" } ?? ""
            return place.isEmpty
                ? firstError.message + code
                : "\(place): \(firstError.message)\(code)"
        }
        let text = String(decoding: stderr, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "테스트 결과가 생성되지 않았다" : text
    }
}
