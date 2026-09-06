public import Foundation
public import LearnCore
public import LanguageKit

/// 파이썬 테스트 하나의 결과. `GradeResult.TestOutcome` 은 통과/실패 두 갈래라
/// **실패와 에러를 구별하지 못한다** — 학습자에게 "답이 틀렸다"와 "코드가 터졌다"는
/// 다른 조언이므로 채점기 층에서는 셋을 유지한다.
public struct PythonTestOutcome: Hashable, Sendable {
    public enum Status: String, Hashable, Sendable {
        case passed, failed, error, skipped
    }

    public var name: String
    public var status: Status
    public var message: String?
    public var durationMilliseconds: Int

    public init(name: String, status: Status, message: String? = nil, durationMilliseconds: Int = 0) {
        self.name = name
        self.status = status
        self.message = message
        self.durationMilliseconds = durationMilliseconds
    }

    /// `GradeResult` 로 접을 때 세 갈래를 메시지 머리말로 보존한다.
    public var graded: GradeResult.TestOutcome {
        let prefixed: String?
        switch status {
        case .passed: prefixed = nil
        case .skipped: prefixed = message.map { "건너뜀: \($0)" } ?? "건너뜀"
        case .failed: prefixed = message
        case .error: prefixed = message.map { "에러: \($0)" } ?? "에러"
        }
        return GradeResult.TestOutcome(
            name: name,
            passed: status == .passed || status == .skipped,
            message: prefixed,
            durationMilliseconds: durationMilliseconds
        )
    }
}

/// 채점 한 번의 전부.
public struct PythonGrading: Sendable {
    public var result: GradeResult
    public var outcomes: [PythonTestOutcome]
    /// 실행 자체가 실패한 경우(타임아웃·메모리 초과 등).
    public var failure: RunFailure?

    public var passed: Bool { result.passed }
}

/// 숨은 `unittest` 테스트로 파이썬 제출을 채점한다.
///
/// 테스트는 사용자 코드와 **같은 격리 안에서** 돈다 — 상한을 벗어난 제출이 채점기를
/// 붙잡지 못하게 하려면 채점도 `SubprocessRunner` 를 지나야 한다.
public struct PythonUnittestGrader: Sendable {
    public var interpreterPath: String?
    public var runnerConfiguration: SubprocessRunnerConfiguration
    /// 숨은 테스트 파일 이름. 사용자 파일과 부딪히면 채점이 조용히 무너진다.
    public var testFileName: String

    public init(
        interpreterPath: String? = nil,
        runnerConfiguration: SubprocessRunnerConfiguration = SubprocessRunnerConfiguration(),
        testFileName: String = "__learnkit_tests.py"
    ) {
        self.interpreterPath = interpreterPath
        self.runnerConfiguration = runnerConfiguration
        self.testFileName = testFileName
    }

    /// - Parameters:
    ///   - solution: 학습자 제출.
    ///   - tests: 숨은 테스트 본문 (`unittest.TestCase` 하위 클래스).
    public func grade(
        solution: [SourceFile],
        tests: String,
        limits: ResourceLimits = .lesson,
        standardInput: Data? = nil
    ) async throws -> PythonGrading {
        // 결과 JSON 은 워크스페이스 **바깥**에 쓴다. 워크스페이스는 실행이 끝나는
        // 순간 사라지므로 안에 쓰면 읽을 기회가 없다.
        let outputDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-grade-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }
        let outputPath = outputDirectory.appendingPathComponent("results.jsonl").path

        let moduleName = String(testFileName.dropLast(3))
        var files = solution
        files.append(SourceFile(path: testFileName, contents: tests))
        files.append(SourceFile(
            path: PythonUnittestHarness.fileName,
            contents: PythonUnittestHarness.source
        ))

        let runner = SubprocessRunner(
            program: PythonProgram(interpreterPath: interpreterPath),
            configuration: runnerConfiguration
        )
        let request = RunRequest(
            files: files,
            entryPoint: PythonUnittestHarness.fileName,
            arguments: [outputPath, moduleName],
            standardInput: standardInput,
            limits: limits
        )

        var stdout = Data()
        var stderr = Data()
        var termination: RunTermination?
        var failure: RunFailure?
        let clock = ContinuousClock()
        let started = clock.now
        do {
            for try await event in runner.run(request) {
                switch event {
                case .standardOutput(let data): stdout.append(data)
                case .standardError(let data): stderr.append(data)
                case .finished(let value): termination = value
                default: break
                }
            }
        } catch let error as RunFailure {
            failure = error
        }
        let elapsed = Int(started.duration(to: clock.now).milliseconds)

        let outcomes = Self.parse(resultsAt: outputPath)
        let passed = failure == nil
            && !outcomes.isEmpty
            && outcomes.allSatisfy { $0.status == .passed || $0.status == .skipped }

        var graded = outcomes.map(\.graded)
        if graded.isEmpty {
            // 결과 파일이 없다 = 하네스가 시작조차 못 했다. 침묵하지 않는다.
            graded = [GradeResult.TestOutcome(
                name: "테스트 실행",
                passed: false,
                message: failure.map(Self.describe) ?? Self.emptyReason(stderr: stderr)
            )]
        }

        let result = GradeResult(
            passed: passed,
            tests: graded,
            diagnostics: [],
            stdout: String(decoding: stdout, as: UTF8.self),
            stderr: String(decoding: stderr, as: UTF8.self),
            exitCode: termination?.exitCode,
            durationMilliseconds: termination?.durationMilliseconds ?? elapsed,
            presenter: .console
        )
        return PythonGrading(result: result, outcomes: outcomes, failure: failure)
    }

    // MARK: - JSON Lines 파싱

    struct HarnessLine: Decodable {
        var kind: String
        var name: String?
        var status: String?
        var message: String?
        var durationMilliseconds: Int?
        var passed: Bool?
        var count: Int?
    }

    static func parse(resultsAt path: String) -> [PythonTestOutcome] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        return parse(jsonLines: data)
    }

    static func parse(jsonLines data: Data) -> [PythonTestOutcome] {
        let decoder = JSONDecoder()
        var outcomes: [PythonTestOutcome] = []
        for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            guard let record = try? decoder.decode(HarnessLine.self, from: Data(line)) else { continue }
            guard record.kind == "test",
                  let name = record.name,
                  let status = record.status.flatMap(PythonTestOutcome.Status.init(rawValue:))
            else { continue }
            outcomes.append(PythonTestOutcome(
                name: name,
                status: status,
                message: record.message,
                durationMilliseconds: record.durationMilliseconds ?? 0
            ))
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

    static func emptyReason(stderr: Data) -> String {
        let text = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "테스트 결과가 생성되지 않았다" : text
    }
}
