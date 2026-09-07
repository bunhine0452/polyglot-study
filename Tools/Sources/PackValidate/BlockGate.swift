internal import ContentKit
internal import Foundation
internal import LanguageKit
internal import LearnCore
internal import PackReport
internal import RunnerKit

/// 블록 하나를 실제 러너·채점기에 태우는 곳. **여기가 게이트의 심장이다.**
///
/// ## 과제 블록의 워크스페이스 규약 (v1)
///
/// 팩의 `starters/` `tests/` `solutions/` 파일 이름은 팩 안에서 유일하기만 하면 되고,
/// 채점기가 보는 이름과는 별개다. 채점기마다 이름 규칙이 있으므로 여기서 못박는다.
///
/// | 언어 | 제출 코드 | 숨은 테스트 |
/// |---|---|---|
/// | python | `solution.py` (테스트는 `from solution import …`) | `unittest.TestCase` 모듈 |
/// | swift | `Sources/Solution/Solution.swift` | `Tests/SolutionTests/Tests.swift` — `@testable import Solution` 이 필요하다 |
/// | sql | 학습자 질의 | **기대 결과셋을 내는 질의** (결과셋 비교 채점) |
///
/// ## starter 는 반드시 실패해야 한다
///
/// solution 만 보면 "과제가 풀린다"까지만 안다. starter 가 이미 통과하면 그 과제는
/// 학습자에게 아무것도 시키지 않는 빈 껍데기이고, 값싼 모델이 만드는 가장 흔한 결함이다.
/// 그래서 둘 다 태운다 — 비용은 두 배지만 이 게이트가 존재하는 이유의 절반이 이쪽이다.
struct BlockGate: Sendable {
    let pack: ContentPack
    let limits: ResourceLimits
    let launcherPath: String?
    let seedDatabase: URL?
    /// Swift 채점은 예열 템플릿 하나를 공유하므로 동시에 돌 수 없다. 그 상호 배제는
    /// **`SwiftTestingGrader` 안에** 있다(`RunnerKit.ExecutionLimits.swiftTemplateGate`) —
    /// 공유 자원 옆에 두어야 새 호출자가 같은 실수를 반복하지 않는다. 여기 있던
    /// `SwiftGradingGate` 는 그래서 사라졌다.
    let swiftGrader: SwiftTestingGrader

    // MARK: - 예제

    /// 예제를 실행해 `expected/` 사이드카와 **바이트 단위로** 대조한다.
    func example(_ block: ExampleBlock) async -> [PackValidationReport.Failure] {
        let transcript = await run(code: block.code, language: block.language)
        guard transcript.succeeded else {
            return [
                .init(
                    stage: .execution, kind: .exampleFailedToRun, blockID: block.id,
                    summary: "예제가 실행되지 않는다",
                    evidence: transcript.evidence)
            ]
        }

        let expectedData: Data
        do {
            expectedData = try pack.data(at: block.expectedStdoutPath)
        } catch {
            return [
                .init(
                    stage: .execution, kind: .exampleOutputMismatch, blockID: block.id,
                    summary: "기대 출력 파일 \(block.expectedStdoutPath.rawValue) 를 읽을 수 없다",
                    evidence: "\(error)\n\n" + transcript.evidence)
            ]
        }

        let expected = ExpectedStdout.normalize(expectedData)
        let actual = ExpectedStdout.normalize(transcript.stdout)
        guard expected != actual else { return [] }

        let diff = LineDiff.render(
            expected: ExpectedStdout.lines(expected),
            actual: ExpectedStdout.lines(actual),
            expectedLabel: block.expectedStdoutPath.rawValue,
            actualLabel: "러너 stdout"
        )
        return [
            .init(
                stage: .execution, kind: .exampleOutputMismatch, blockID: block.id,
                summary: "예제 출력이 \(block.expectedStdoutPath.rawValue) 와 다르다",
                evidence: diff + "\n" + transcript.evidence)
        ]
    }

    // MARK: - 빈칸

    /// 정답을 채운 템플릿이 실제로 돌아가는가.
    ///
    /// 기대 출력 사이드카가 없으므로 대조는 하지 않는다. 검사하는 것은 하나 —
    /// **정답을 다 채워도 컴파일조차 안 되는 빈칸**이 화면에 나가지 않는 것.
    func blank(_ block: BlankBlock) async -> [PackValidationReport.Failure] {
        let transcript = await run(code: block.filledTemplate(), language: block.language)
        guard transcript.succeeded else {
            return [
                .init(
                    stage: .execution, kind: .exampleFailedToRun, blockID: block.id,
                    summary: "빈칸의 정답을 채운 코드가 실행되지 않는다",
                    evidence: transcript.evidence)
            ]
        }
        return []
    }

    // MARK: - 과제

    func task(_ block: TaskBlock) async -> [PackValidationReport.Failure] {
        let starter: String
        let solution: String
        let tests: String
        do {
            starter = try pack.text(at: block.starterPath)
            solution = try pack.text(at: block.solutionPath)
            tests = try pack.text(at: block.testsPath)
        } catch {
            return [
                .init(
                    stage: .execution, kind: .solutionFailsTests, blockID: block.id,
                    summary: "과제 사이드카를 읽을 수 없다", evidence: "\(error)")
            ]
        }

        async let solutionRun = grade(
            submission: solution, tests: tests, language: block.language)
        async let starterRun = grade(
            submission: starter, tests: tests, language: block.language)
        let (solutionOutcome, starterOutcome) = await (solutionRun, starterRun)

        var failures: [PackValidationReport.Failure] = []
        if !solutionOutcome.passed {
            failures.append(
                .init(
                    stage: .execution, kind: .solutionFailsTests, blockID: block.id,
                    summary: "solution 이 숨은 테스트를 통과하지 못한다 (\(block.solutionPath.rawValue))",
                    evidence: solutionOutcome.evidence))
        }
        if starterOutcome.passed {
            failures.append(
                .init(
                    stage: .execution, kind: .starterAlreadyPasses, blockID: block.id,
                    summary: "starter 가 이미 숨은 테스트를 통과한다 — 과제가 학습자에게 아무것도 시키지 않는다"
                        + " (\(block.starterPath.rawValue))",
                    evidence: starterOutcome.evidence))
        }
        return failures
    }

    // MARK: - 러너

    private func run(code: String, language: LanguageID) async -> RunTranscript {
        switch language {
        case .python:
            let runner = SubprocessRunner(
                program: PythonProgram(), configuration: subprocessConfiguration())
            return await RunTranscript.collect(
                runner.run(
                    RunRequest(
                        files: [SourceFile(path: "main.py", contents: code)],
                        entryPoint: "main.py", limits: limits)))
        case .swift:
            let runner = SubprocessRunner(
                program: SwiftProgram(), configuration: subprocessConfiguration())
            return await RunTranscript.collect(
                runner.run(
                    RunRequest(
                        files: [SourceFile(path: "main.swift", contents: code)],
                        entryPoint: "main.swift", limits: limits)))
        case .cpp:
            // 예제는 `main` 을 가진 완결된 프로그램이다 — 채점 하네스와 달리 여기서는
            // 사용자 코드가 진입점을 들고 있다.
            let runner = SubprocessRunner(
                program: CppProgram(), configuration: subprocessConfiguration())
            return await RunTranscript.collect(
                runner.run(
                    RunRequest(
                        files: [SourceFile(path: "main.cpp", contents: code)],
                        entryPoint: "main.cpp", limits: limits)))
        case .rust:
            let runner = SubprocessRunner(
                program: RustProgram(), configuration: subprocessConfiguration())
            return await RunTranscript.collect(
                runner.run(
                    RunRequest(
                        files: [SourceFile(path: "main.rs", contents: code)],
                        entryPoint: "main.rs", limits: limits)))
        case .sql:
            let runner = InProcessRunner()
            var resources: [String: URL] = [:]
            if let seedDatabase { resources[RunRequest.Resource.database] = seedDatabase }
            return await RunTranscript.collect(
                runner.run(
                    RunRequest(
                        files: [SourceFile(path: "query.sql", contents: code)],
                        entryPoint: "query.sql", limits: limits, resources: resources)))
        default:
            var transcript = RunTranscript()
            transcript.failure = .backend("실행 게이트가 모르는 언어: \(language.rawValue)")
            return transcript
        }
    }

    private func subprocessConfiguration() -> SubprocessRunnerConfiguration {
        SubprocessRunnerConfiguration(launcherPath: launcherPath)
    }

    // MARK: - 채점

    struct GradeOutcome: Sendable {
        var passed: Bool
        var evidence: String
    }

    private func grade(
        submission: String, tests: String, language: LanguageID
    ) async -> GradeOutcome {
        switch language {
        case .python: await gradePython(submission: submission, tests: tests)
        case .swift: await gradeSwift(submission: submission, tests: tests)
        case .sql: await gradeSQL(submission: submission, reference: tests)
        case .cpp: await gradeCpp(submission: submission, tests: tests)
        case .rust: await gradeRust(submission: submission, tests: tests)
        default:
            GradeOutcome(passed: false, evidence: "채점기가 없는 언어: \(language.rawValue)")
        }
    }

    private func gradePython(submission: String, tests: String) async -> GradeOutcome {
        let grader = PythonUnittestGrader(runnerConfiguration: subprocessConfiguration())
        do {
            let grading = try await grader.grade(
                solution: [SourceFile(path: "solution.py", contents: submission)],
                tests: tests,
                limits: limits)
            return GradeOutcome(passed: grading.passed, evidence: describe(grading.result))
        } catch {
            return GradeOutcome(passed: false, evidence: "채점 실패: \(error)")
        }
    }

    private func gradeCpp(submission: String, tests: String) async -> GradeOutcome {
        // 제출을 **`solution.h` 로 놓는다.** `CppProgram` 은 `.h` 를 번역 단위로 세지
        // 않으므로(`sourceExtensions` 는 cpp/cc/cxx), 테스트가 `#include "solution.h"` 로
        // 끌어와도 중복 정의가 나지 않는다. Rust 의 `include!` 와 같은 구조이고,
        // 저자는 파일 하나만 쓰면 된다.
        let grader = CppAssertGrader(runnerConfiguration: subprocessConfiguration())
        do {
            let grading = try await grader.grade(
                solution: [SourceFile(path: "solution.h", contents: submission)],
                tests: tests,
                limits: limits)
            return GradeOutcome(passed: grading.passed, evidence: describe(grading.result))
        } catch {
            return GradeOutcome(passed: false, evidence: "채점 실패: \(error)")
        }
    }

    private func gradeRust(submission: String, tests: String) async -> GradeOutcome {
        let grader = RustTestGrader(runnerConfiguration: subprocessConfiguration())
        do {
            let grading = try await grader.grade(
                solution: [SourceFile(path: "solution.rs", contents: submission)],
                tests: tests,
                limits: limits)
            return GradeOutcome(passed: grading.passed, evidence: describe(grading.result))
        } catch {
            return GradeOutcome(passed: false, evidence: "채점 실패: \(error)")
        }
    }

    private func gradeSwift(submission: String, tests: String) async -> GradeOutcome {
        do {
            let grading = try await swiftGrader.grade(
                solution: [SourceFile(path: "Solution.swift", contents: submission)],
                tests: [SourceFile(path: "Tests.swift", contents: tests)])
            return GradeOutcome(
                passed: grading.passed,
                evidence: describe(grading.result) + "\n[swift test 원문]\n" + grading.rawOutput)
        } catch {
            return GradeOutcome(passed: false, evidence: "채점 실패: \(error)")
        }
    }

    private func gradeSQL(submission: String, reference: String) async -> GradeOutcome {
        let grader = SQLResultSetGrader(runner: InProcessRunner(), database: seedDatabase)
        do {
            let grading = try await grader.grade(
                submission: submission, reference: reference, limits: limits)
            return GradeOutcome(passed: grading.passed, evidence: describe(grading.result))
        } catch {
            // 참조 해답이 안 도는 것은 학습자가 아니라 **콘텐츠**의 결함이다.
            return GradeOutcome(passed: false, evidence: "채점 실패: \(error)")
        }
    }

    /// `GradeResult` 를 증거 문자열로. 테스트 이름과 메시지를 하나도 빠뜨리지 않는다.
    private func describe(_ result: GradeResult) -> String {
        var parts: [String] = ["[채점] 통과=\(result.passed) \(result.durationMilliseconds)ms"]
        for outcome in result.tests {
            let mark = outcome.passed ? "PASS" : "FAIL"
            let message = outcome.message.map { "\n    \($0.replacingOccurrences(of: "\n", with: "\n    "))" } ?? ""
            parts.append("  \(mark) \(outcome.name)\(message)")
        }
        if !result.diagnostics.isEmpty {
            parts.append(
                "[진단]\n"
                    + result.diagnostics.map {
                        let position = $0.line.map { ":\($0)" } ?? ""
                        return "\($0.file ?? "?")\(position): \($0.severity.rawValue): \($0.message)"
                    }.joined(separator: "\n"))
        }
        if !result.stdout.isEmpty { parts.append("[stdout]\n" + result.stdout) }
        if !result.stderr.isEmpty { parts.append("[stderr]\n" + result.stderr) }
        return parts.joined(separator: "\n")
    }
}
