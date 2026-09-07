public import Foundation
public import LanguageKit
public import LearnCore

/// C++ 테스트 하나의 결과.
///
/// `GradeResult.TestOutcome` 은 통과/실패 두 갈래라 **실패와 에러를 구별하지 못한다** —
/// "답이 틀렸다" 와 "코드가 터졌다" 는 학습자에게 다른 조언이므로 채점기 층에서는
/// 셋을 유지한다. (`PythonTestOutcome` 과 같은 이유·같은 모양이다.)
public struct CppTestOutcome: Hashable, Sendable {
    public enum Status: String, Hashable, Sendable {
        case passed, failed, error
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
        case .failed: prefixed = message
        case .error: prefixed = message.map { "에러: \($0)" } ?? "에러"
        }
        return GradeResult.TestOutcome(name: name, passed: status == .passed, message: prefixed)
    }
}

/// 채점 한 번의 전부.
public struct CppGrading: Sendable {
    public var result: GradeResult
    public var outcomes: [CppTestOutcome]
    /// 실행 자체가 실패한 경우(타임아웃·메모리 초과 등).
    public var failure: RunFailure?

    public var passed: Bool { result.passed }
}

/// 숨은 테스트로 C++ 제출을 채점한다.
///
/// 테스트는 사용자 코드와 **같은 격리 안에서** 돈다 — 상한을 벗어난 제출이 채점기를
/// 붙잡지 못하게 하려면 채점도 `SubprocessRunner` 를 지나야 한다.
///
/// Swift 채점기와 달리 **예열 템플릿이 없다.** SwiftPM 패키지를 굽는 것과 달리 여기서는
/// 번역 단위 셋을 `clang++` 한 번에 넘기면 끝이라 공유 자원이 없다 — 그래서
/// `ExecutionLimits.swiftTemplateGate` 같은 상호 배제도 필요 없다. 동시 실행 상한은
/// `SubprocessRunner` 안의 스폰 게이트가 이미 세운다.
public struct CppAssertGrader: Sendable {
    public var compilerPath: String?
    public var runnerConfiguration: SubprocessRunnerConfiguration
    /// 숨은 테스트 파일 이름. 사용자 파일과 부딪히면 채점이 조용히 무너진다.
    public var testFileName: String
    public var languageStandard: String

    public init(
        compilerPath: String? = nil,
        runnerConfiguration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration(),
        testFileName: String = "__learnkit_tests.cpp",
        languageStandard: String = "c++20"
    ) {
        self.compilerPath = compilerPath
        self.runnerConfiguration = runnerConfiguration
        self.testFileName = testFileName
        self.languageStandard = languageStandard
    }

    /// - Parameters:
    ///   - solution: 학습자 제출. `main` 을 담지 않는다 — 하네스가 준다.
    ///   - tests: 숨은 테스트 본문 (`LEARNKIT_TEST` 블록들).
    public func grade(
        solution: [SourceFile],
        tests: String,
        limits: ResourceLimits = .lesson,
        standardInput: Data? = nil
    ) async throws -> CppGrading {
        // 결과는 워크스페이스 **바깥**에 쓴다. 워크스페이스는 실행이 끝나는 순간
        // 사라지므로 안에 쓰면 읽을 기회가 없다.
        let outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-grade-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }
        let outputPath = outputDirectory.appendingPathComponent("results.jsonl").path

        var files = solution
        files.append(SourceFile(path: testFileName, contents: tests))
        files.append(SourceFile(
            path: CppAssertHarness.headerName, contents: CppAssertHarness.header))
        files.append(SourceFile(
            path: CppAssertHarness.mainName, contents: CppAssertHarness.main))

        let runner = SubprocessRunner(
            program: CppProgram(
                compilerPath: compilerPath, languageStandard: languageStandard),
            configuration: runnerConfiguration
        )
        // 진입점을 하네스로 못박는다 — 사용자 파일이 `main.cpp` 라는 이름을 써도
        // 진단 순서만 바뀌지 링크 대상은 같다.
        let request = RunRequest(
            files: files,
            entryPoint: CppAssertHarness.mainName,
            arguments: [outputPath],
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

        let outcomes = Self.parse(resultsAt: outputPath)
        let passed = failure == nil && !outcomes.isEmpty
            && outcomes.allSatisfy { $0.status == .passed }

        var graded = outcomes.map(\.graded)
        if graded.isEmpty {
            // 결과 파일이 없다 = 하네스가 시작조차 못 했다(대개 컴파일 실패). 침묵하지 않는다.
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
        return CppGrading(result: result, outcomes: outcomes, failure: failure)
    }

    // MARK: - JSON Lines 파싱

    struct HarnessLine: Decodable {
        var name: String
        var status: String
        var message: String?
    }

    static func parse(resultsAt path: String) -> [CppTestOutcome] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        return parse(jsonLines: data)
    }

    static func parse(jsonLines data: Data) -> [CppTestOutcome] {
        let decoder = JSONDecoder()
        var outcomes: [CppTestOutcome] = []
        for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            guard let record = try? decoder.decode(HarnessLine.self, from: Data(line)),
                  let status = CppTestOutcome.Status(rawValue: record.status)
            else { continue }
            let message = (record.message?.isEmpty ?? true) ? nil : record.message
            outcomes.append(CppTestOutcome(
                name: record.name, status: status, message: message))
        }
        return outcomes
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

    /// 결과가 비었을 때 학습자에게 보여줄 이유.
    ///
    /// 컴파일 오류가 압도적으로 흔하므로 진단의 첫 에러를 먼저 보여준다 — stderr 원문은
    /// `In file included from` 사슬로 시작하는 경우가 많아 첫 줄이 도움이 안 된다.
    static func emptyReason(diagnostics: [Diagnostic], stderr: Data) -> String {
        if let firstError = diagnostics.first(where: { $0.severity == .error }) {
            let place = [firstError.file, firstError.line.map(String.init)]
                .compactMap { $0 }.joined(separator: ":")
            return place.isEmpty ? firstError.message : "\(place): \(firstError.message)"
        }
        let text = String(decoding: stderr, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "테스트 결과가 생성되지 않았다" : text
    }
}
