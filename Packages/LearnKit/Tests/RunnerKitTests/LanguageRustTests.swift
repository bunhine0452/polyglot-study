import Foundation
import LanguageKit
import LearnCore
import Testing

@testable import RunnerKit

@Suite("Rust 어댑터 실측", .serialized)
struct LanguageRustTests {

    private func runner(_ container: URL? = nil) throws -> SubprocessRunner {
        try SubprocessTestSupport.runner(program: RustProgram(), workspaceContainer: container)
    }

    @Test("표준 입력을 읽는 프로그램이 정답을 낸다")
    func standardInputProducesCorrectAnswer() async throws {
        let source = """
            use std::io::Read;
            fn main() {
                let mut text = String::new();
                std::io::stdin().read_to_string(&mut text).unwrap();
                let sum: i32 = text.split_whitespace().map(|t| t.parse::<i32>().unwrap()).sum();
                println!("{}", sum);
            }
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(
                files: [SourceFile(path: "main.rs", contents: source)],
                standardInput: Data("17 25\n".utf8)
            )
        )
        #expect(observation.failure == nil, "\(String(describing: observation.failure))")
        #expect(observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) == "42")
        #expect(observation.termination?.succeeded == true)
    }

    @Test("컴파일 오류는 진단이 되고 오류 코드가 ruleID 로 온다")
    func compileErrorCarriesErrorCode() async throws {
        // rustc 만 구조화 진단이 있다. `E0308` 은 학습자가 `rustc --explain` 으로 펼칠 수 있다.
        let source = """
            fn main() { let x: i32 = "이건 i32 가 아니다"; println!("{}", x); }
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [SourceFile(path: "main.rs", contents: source)])
        )
        #expect(observation.failure == nil, "\(String(describing: observation.failure))")
        #expect(observation.termination?.succeeded == false)
        let errors = observation.diagnostics.filter { $0.severity == .error }
        #expect(!errors.isEmpty, "진단이 하나도 안 나왔다")
        #expect(errors.contains { $0.ruleID == "E0308" },
                "받은 코드: \(errors.map { $0.ruleID ?? "nil" })")
        // 경로는 워크스페이스 기준 상대경로라는 계약이다.
        #expect(errors.allSatisfy { ($0.file ?? "").hasPrefix("/") == false })
    }

    @Test("요약 줄은 진단으로 세지 않는다")
    func summaryLinesAreNotDiagnostics() async throws {
        // `aborting due to N previous errors` 와 `For more information ...` 은 고칠 자리를
        // 가리키지 않는다. 인라인 진단 행에 섞이면 학습자가 헛짚는다.
        let source = """
            fn main() { let x: i32 = "a"; let y: i32 = "b"; println!("{}{}", x, y); }
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [SourceFile(path: "main.rs", contents: source)])
        )
        #expect(observation.diagnostics.allSatisfy { !$0.message.hasPrefix("aborting due to") })
        #expect(observation.diagnostics.allSatisfy {
            !$0.message.hasPrefix("For more information about")
        })
        #expect(observation.diagnostics.contains { $0.severity == .error })
    }
}

@Suite("Rust 채점 실측", .serialized)
struct LanguageRustGradingTests {

    private let tests = """
        #[cfg(test)]
        mod learnkit_tests {
            use super::*;
            #[test] fn 빈_슬라이스는_0이다() { assert_eq!(sum_of(&[]), 0); }
            #[test] fn 양수를_더한다() { assert_eq!(sum_of(&[1, 2, 3]), 6); }
            #[test] fn 음수도_더한다() { assert_eq!(sum_of(&[-5, 5, -2]), -2); }
        }
        """

    /// 채점기도 러너와 같은 격리를 지나므로 런처 경로를 같은 방식으로 받아야 한다.
    private func grader() throws -> RustTestGrader {
        RustTestGrader(runnerConfiguration: try SubprocessTestSupport.configuration())
    }

    private func solution(_ body: String) -> [SourceFile] {
        [SourceFile(path: "solution.rs", contents: body)]
    }

    @Test("정답은 숨은 테스트를 전부 통과한다")
    func solutionPasses() async throws {
        let body = "pub fn sum_of(values: &[i32]) -> i32 { values.iter().sum() }"
        let grading = try await grader().grade(solution: solution(body), tests: tests)
        #expect(grading.failure == nil, "\(String(describing: grading.failure))")
        #expect(grading.passed, "결과: \(grading.result.tests.map { "\($0.name)=\($0.passed)" })")
        #expect(grading.outcomes.count == 3)
    }

    @Test("assert 실패는 failed, panic 은 error 로 갈린다")
    func assertionAndPanicAreSeparated() async throws {
        // libtest 는 둘 다 "failed" 로 적는다 — 메시지로 가르는 것이 `classify` 의 일이다.
        let body = """
            pub fn sum_of(values: &[i32]) -> i32 {
                if values.is_empty() { return 0; }              // 하나는 우연히 맞는다
                if values.len() == 3 && values[0] == 1 { return 99; }  // 하나는 틀린 답
                panic!("여기를 구현해라");                        // 하나는 터진다
            }
            """
        let grading = try await grader().grade(solution: solution(body), tests: tests)
        #expect(grading.passed == false)
        #expect(grading.outcomes.contains { $0.status == .passed })
        #expect(grading.outcomes.contains { $0.status == .failed },
                "상태: \(grading.outcomes.map { "\($0.name)=\($0.status.rawValue)" })")
        #expect(grading.outcomes.contains { $0.status == .error },
                "상태: \(grading.outcomes.map { "\($0.name)=\($0.status.rawValue)" })")
        let errorMessage = grading.outcomes.first { $0.status == .error }?.message ?? ""
        #expect(errorMessage.contains("여기를 구현해라"), "메시지: \(errorMessage)")
    }

    @Test("틀린 답은 기대와 실제를 함께 보여준다")
    func wrongAnswerShowsBothSides() async throws {
        let body = "pub fn sum_of(_values: &[i32]) -> i32 { 999 }"
        let grading = try await grader().grade(solution: solution(body), tests: tests)
        #expect(grading.passed == false)
        let failed = grading.outcomes.first { $0.status == .failed }
        let message = try #require(failed?.message, "실패로 분류된 테스트가 없다")
        #expect(message.contains("999"), "실제값이 없다: \(message)")
    }

    @Test("컴파일이 깨지면 결과가 비고, 이유로 첫 에러와 코드를 보여준다")
    func compileFailureReportsFirstDiagnostic() async throws {
        let body = "pub fn sum_of(values: &[i32]) -> i32 { \"문자열\" }"
        let grading = try await grader().grade(solution: solution(body), tests: tests)
        #expect(grading.passed == false)
        #expect(grading.outcomes.isEmpty)
        let message = try #require(grading.result.tests.first?.message)
        #expect(message.contains("E0308"), "메시지: \(message)")
    }

    @Test("include! 로 이어도 진단의 줄 번호가 제출 파일 기준으로 온다")
    func diagnosticsPointAtTheSubmission() async throws {
        // 크레이트 루트가 `include!` 로 두 파일을 합치므로, 줄 번호가 루트 기준으로
        // 밀리면 학습자가 엉뚱한 줄을 본다. rustc 가 스팬을 원본으로 되돌리는지 확인한다.
        let body = """
            pub fn sum_of(values: &[i32]) -> i32 {
                let broken: i32 = "세 번째 줄";
                values.iter().sum()
            }
            """
        let grading = try await grader().grade(solution: solution(body), tests: tests)
        let errors = grading.result.diagnostics.filter { $0.severity == .error }
        #expect(errors.contains { $0.file == "solution.rs" && $0.line == 2 },
                "받은 진단: \(errors.map { "\($0.file ?? "?"):\($0.line ?? -1)" })")
    }
}
