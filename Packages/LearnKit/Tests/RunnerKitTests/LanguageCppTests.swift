import Foundation
import LanguageKit
import LearnCore
import Testing

@testable import RunnerKit

@Suite("C++ 어댑터 실측", .serialized)
struct LanguageCppTests {

    private func runner(_ container: URL? = nil) throws -> SubprocessRunner {
        try SubprocessTestSupport.runner(program: CppProgram(), workspaceContainer: container)
    }

    @Test("표준 입력을 읽는 프로그램이 정답을 낸다")
    func standardInputProducesCorrectAnswer() async throws {
        let source = """
            #include <iostream>
            int main() {
                int a = 0, b = 0;
                std::cin >> a >> b;
                std::cout << a + b << std::endl;
                return 0;
            }
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(
                files: [SourceFile(path: "main.cpp", contents: source)],
                standardInput: Data("17 25\n".utf8)
            )
        )
        #expect(observation.failure == nil, "\(String(describing: observation.failure))")
        #expect(observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) == "42")
        #expect(observation.termination?.succeeded == true)
    }

    @Test("컴파일 오류는 백엔드 실패가 아니라 진단과 함께 실패 종료로 접힌다")
    func compileErrorBecomesDiagnostics() async throws {
        // 컴파일이 안 되는 것은 학습자가 늘 만나는 **정상적인 결과**다. 여기서
        // `RunFailure` 를 던지면 UI 가 "실행기가 고장났다" 로 그린다.
        let source = """
            int main() { int x = "이건 int 가 아니다"; return 0; }
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [SourceFile(path: "main.cpp", contents: source)])
        )
        #expect(observation.failure == nil, "\(String(describing: observation.failure))")
        #expect(observation.termination?.succeeded == false)
        let errors = observation.diagnostics.filter { $0.severity == .error }
        #expect(!errors.isEmpty, "진단이 하나도 안 나왔다")
        // 경로는 워크스페이스 기준 상대경로라는 계약이다 — 절대경로가 새면 안 된다.
        #expect(errors.allSatisfy { ($0.file ?? "").hasPrefix("/") == false })
        #expect(errors.contains { $0.line == 1 })
    }

    @Test("경고에는 clang 의 그룹 이름이 ruleID 로 붙는다")
    func warningCarriesRuleID() async throws {
        // swiftc 에서는 못 얻는 값이다. `-Wall` 을 켜 둔 이유가 여기에 있다.
        let source = """
            #include <iostream>
            int main() { int unused = 3; std::cout << "ok" << std::endl; return 0; }
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [SourceFile(path: "main.cpp", contents: source)])
        )
        #expect(observation.termination?.succeeded == true)
        let warnings = observation.diagnostics.filter { $0.severity == .warning }
        #expect(warnings.contains { $0.ruleID == "-Wunused-variable" },
                "받은 경고: \(warnings.map { $0.ruleID ?? "nil" })")
    }

    @Test("여러 번역 단위를 한 번에 링크한다")
    func linksMultipleTranslationUnits() async throws {
        let header = "#pragma once\nint doubled(int value);\n"
        let library = "#include \"lib.h\"\nint doubled(int value) { return value * 2; }\n"
        let main = """
            #include <iostream>
            #include "lib.h"
            int main() { std::cout << doubled(21) << std::endl; return 0; }
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [
                SourceFile(path: "main.cpp", contents: main),
                SourceFile(path: "lib.cpp", contents: library),
                SourceFile(path: "lib.h", contents: header),
            ])
        )
        #expect(observation.failure == nil, "\(String(describing: observation.failure))")
        #expect(observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) == "42")
    }
}

@Suite("C++ 채점 실측", .serialized)
struct LanguageCppGradingTests {

    private let solutionHeader = "#pragma once\n#include <vector>\nint sumOf(const std::vector<int>& values);\n"
    private let tests = """
        #include "__learnkit_harness.h"
        #include "solution.h"

        LEARNKIT_TEST("빈 벡터는 0 이다") { LEARNKIT_EXPECT_EQ(sumOf({}), 0); }
        LEARNKIT_TEST("양수를 더한다") { LEARNKIT_EXPECT_EQ(sumOf({1, 2, 3}), 6); }
        LEARNKIT_TEST("음수도 더한다") { LEARNKIT_EXPECT_EQ(sumOf({-5, 5, -2}), -2); }
        """

    /// 채점기도 러너와 같은 격리를 지나므로 런처 경로를 같은 방식으로 받아야 한다.
    /// 기본 `SubprocessRunnerConfiguration()` 은 앱 번들 기준이라 테스트에서는 못 찾는다.
    private func grader() throws -> CppAssertGrader {
        CppAssertGrader(runnerConfiguration: try SubprocessTestSupport.configuration())
    }

    private func solutionFiles(_ body: String) -> [SourceFile] {
        [
            SourceFile(path: "solution.h", contents: solutionHeader),
            SourceFile(path: "solution.cpp", contents: body),
        ]
    }

    @Test("정답은 숨은 테스트를 전부 통과한다")
    func solutionPasses() async throws {
        let body = """
            #include "solution.h"
            int sumOf(const std::vector<int>& values) {
                int total = 0;
                for (int value : values) total += value;
                return total;
            }
            """
        let grading = try await grader().grade(
            solution: solutionFiles(body), tests: tests)
        #expect(grading.failure == nil, "\(String(describing: grading.failure))")
        #expect(grading.passed, "결과: \(grading.result.tests.map { "\($0.name)=\($0.passed)" })")
        #expect(grading.outcomes.count == 3)
    }

    @Test("구현이 비면 실패하고, 실패와 에러를 구별한다")
    func starterFailsAndSeparatesErrorFromFailure() async throws {
        // starter 가 통과하는 과제는 빈 껍데기다 — packtool 게이트가 보는 바로 그 성질을
        // 채점기 층에서도 확인한다.
        let body = """
            #include "solution.h"
            #include <stdexcept>
            int sumOf(const std::vector<int>& values) {
                if (values.empty()) return 0;          // 하나는 우연히 맞는다
                throw std::runtime_error("여기를 구현해라");
            }
            """
        let grading = try await grader().grade(
            solution: solutionFiles(body), tests: tests)
        #expect(grading.passed == false)
        #expect(grading.outcomes.contains { $0.status == .passed })
        #expect(grading.outcomes.contains { $0.status == .error })
        let errorMessage = grading.outcomes.first { $0.status == .error }?.message ?? ""
        #expect(errorMessage.contains("여기를 구현해라"), "메시지: \(errorMessage)")
    }

    @Test("틀린 답은 기대와 실제를 함께 보여준다")
    func wrongAnswerShowsBothSides() async throws {
        let body = """
            #include "solution.h"
            int sumOf(const std::vector<int>& values) { return 999; }
            """
        let grading = try await grader().grade(
            solution: solutionFiles(body), tests: tests)
        #expect(grading.passed == false)
        let failed = grading.outcomes.first { $0.status == .failed }
        let message = try #require(failed?.message)
        #expect(message.contains("999"), "실제값이 없다: \(message)")
    }

    @Test("컴파일이 깨지면 결과가 비고, 이유로 첫 에러 진단을 보여준다")
    func compileFailureReportsFirstDiagnostic() async throws {
        // stderr 원문의 첫 줄은 `In file included from` 인 경우가 많아 도움이 안 된다.
        let body = """
            #include "solution.h"
            int sumOf(const std::vector<int>& values) { return "문자열"; }
            """
        let grading = try await grader().grade(
            solution: solutionFiles(body), tests: tests)
        #expect(grading.passed == false)
        #expect(grading.outcomes.isEmpty)
        let message = try #require(grading.result.tests.first?.message)
        #expect(message.contains("solution.cpp"), "메시지: \(message)")
    }
}
