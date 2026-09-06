import Testing
import Foundation
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("Python 어댑터 실측", .serialized)
struct LanguagePythonTests {

    private func runner(_ container: URL? = nil) throws -> SubprocessRunner {
        try SubprocessTestSupport.runner(program: PythonProgram(), workspaceContainer: container)
    }

    @Test("input() 을 쓰는 프로그램이 정답을 낸다")
    func inputProducesCorrectAnswer() async throws {
        let source = """
            a = int(input())
            b = int(input())
            print(a + b)
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(
                files: [SourceFile(path: "main.py", contents: source)],
                standardInput: Data("17\n25\n".utf8)
            )
        )
        #expect(observation.failure == nil, "\(String(describing: observation.failure))")
        #expect(observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) == "42")
        #expect(observation.termination?.succeeded == true)
    }

    @Test("-I 는 PYTHON 계열 환경변수와 사용자 site-packages 를 차단한다")
    func isolatedModeBlocksUserEnvironment() async throws {
        let source = """
            import os, sys, site
            print("PYTHONPATH" in os.environ, sys.flags.isolated, sys.flags.no_user_site, sys.flags.dont_write_bytecode)
            """
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [SourceFile(path: "main.py", contents: source)])
        )
        #expect(observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) == "False 1 1 1")
    }

    @Test("사용할 인터프리터는 PATH 순서가 아니라 버전 정책이 고른다")
    func interpreterComesFromVersionPolicy() async throws {
        let path = try await LanguageToolchain.shared.executablePath(for: ToolchainCatalog.python)
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [
                SourceFile(path: "main.py", contents: "import sys; print('%d.%d' % sys.version_info[:2])")
            ])
        )
        let reported = observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 3.9 로 떨어지면 정책이 무너진 것이다 — `/usr/bin/python3` 이 PATH 앞에 있다.
        #expect(reported != "3.9", "선택된 인터프리터: \(path)")
        #expect(!reported.isEmpty)
    }

    @Test("__pycache__ 를 만들지 않는다 — -B")
    func doesNotWriteBytecode() async throws {
        let container = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("learnkit-py-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: container) }

        let observation = await SubprocessTestSupport.observe(
            try runner(container),
            RunRequest(files: [
                SourceFile(path: "main.py", contents: "import os\nprint(os.path.isdir('__pycache__'))")
            ])
        )
        #expect(observation.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) == "False")
    }

    @Test("진입점이 없으면 백엔드 실패로 거부한다")
    func missingEntryPointIsRejected() async throws {
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [SourceFile(path: "main.py", contents: "pass")], entryPoint: "other.py")
        )
        guard case .backend = observation.failure else {
            Issue.record("진입점 누락이 backend 실패로 오지 않았다: \(String(describing: observation.failure))")
            return
        }
    }

    @Test("종료 코드를 그대로 보고한다")
    func exitCodeIsReported() async throws {
        let observation = await SubprocessTestSupport.observe(
            try runner(),
            RunRequest(files: [SourceFile(path: "main.py", contents: "import sys\nsys.exit(42)")])
        )
        #expect(observation.termination?.status == .failed(code: 42))
    }
}

@Suite("Python unittest 채점 실측", .serialized)
struct PythonGradingTests {

    private func grader() throws -> PythonUnittestGrader {
        PythonUnittestGrader(runnerConfiguration: try SubprocessTestSupport.configuration())
    }

    private static let hiddenTests = """
        import unittest
        from solution import add, boom

        class T(unittest.TestCase):
            def test_passes(self):
                self.assertEqual(add(2, 3), 5)

            def test_fails(self):
                self.assertEqual(add(2, 3), 6)

            def test_errors(self):
                boom()
        """

    private static let solution = SourceFile(path: "solution.py", contents: """
        print("사용자 stdout 은 여기로 나간다")

        def add(a, b):
            return a + b

        def boom():
            raise ValueError("터졌다")
        """)

    @Test("통과·실패·에러 세 종류가 구별된다")
    func threeOutcomesAreDistinct() async throws {
        let grading = try await grader().grade(solution: [Self.solution], tests: Self.hiddenTests)
        let byName = Dictionary(uniqueKeysWithValues: grading.outcomes.map { ($0.name, $0) })

        #expect(grading.outcomes.count == 3, "\(grading.outcomes)")
        #expect(byName["T.test_passes"]?.status == .passed)
        #expect(byName["T.test_fails"]?.status == .failed)
        #expect(byName["T.test_errors"]?.status == .error)
        #expect(!grading.passed)
        // 실패는 단언 메시지, 에러는 트레이스백까지.
        #expect(byName["T.test_fails"]?.message?.contains("AssertionError") == true)
        #expect(byName["T.test_errors"]?.message?.contains("ValueError") == true)
        #expect(byName["T.test_errors"]?.message?.contains("Traceback") == true)
    }

    @Test("사용자 코드의 stdout 이 테스트 JSON 을 오염시키지 않는다")
    func userStdoutDoesNotPolluteResults() async throws {
        let grading = try await grader().grade(solution: [Self.solution], tests: Self.hiddenTests)
        // 사용자 출력은 stdout 으로 흘렀고, 결과는 그것과 무관하게 온전하다.
        #expect(grading.result.stdout.contains("사용자 stdout 은 여기로 나간다"))
        #expect(grading.outcomes.count == 3)
    }

    @Test("전부 통과하면 passed 다")
    func allPassing() async throws {
        let tests = """
            import unittest
            from solution import add

            class T(unittest.TestCase):
                def test_one(self):
                    self.assertEqual(add(1, 1), 2)
            """
        let grading = try await grader().grade(
            solution: [SourceFile(path: "solution.py", contents: "def add(a, b):\n    return a + b\n")],
            tests: tests
        )
        #expect(grading.passed)
        #expect(grading.result.tests.filter { !$0.passed }.isEmpty)
        #expect(grading.result.presenter == .console)
    }

    @Test("제출이 임포트 단계에서 터져도 결과가 나온다")
    func importFailureIsReported() async throws {
        let grading = try await grader().grade(
            solution: [SourceFile(path: "solution.py", contents: "raise RuntimeError('임포트 실패')\n")],
            tests: "import unittest\nfrom solution import add\n\nclass T(unittest.TestCase):\n    def test_one(self):\n        pass\n"
        )
        #expect(!grading.passed)
        #expect(!grading.result.tests.isEmpty)
    }

    @Test("무한 루프 제출은 벽시계 상한에서 끊기고 실패로 보고된다")
    func infiniteSubmissionIsBounded() async throws {
        let grading = try await grader().grade(
            solution: [SourceFile(path: "solution.py", contents: "while True:\n    pass\n")],
            tests: "import unittest\nimport solution\n\nclass T(unittest.TestCase):\n    def test_one(self):\n        pass\n",
            limits: ResourceLimits(wallClockSeconds: 2, cpuSeconds: 30)
        )
        #expect(!grading.passed)
        #expect(grading.failure == .wallClockExceeded(seconds: 2))
    }

    @Test("JSON Lines 파서는 요약 줄을 결과로 세지 않는다")
    func parserIgnoresSummaryLine() {
        let lines = """
            {"kind":"test","name":"T.a","status":"passed","message":null,"durationMilliseconds":3}
            {"kind":"test","name":"T.b","status":"error","message":"boom","durationMilliseconds":1}
            {"kind":"summary","passed":false,"count":2,"durationMilliseconds":4}
            """
        let outcomes = PythonUnittestGrader.parse(jsonLines: Data(lines.utf8))
        #expect(outcomes.count == 2)
        #expect(outcomes[0].status == .passed)
        #expect(outcomes[1].status == .error)
        #expect(outcomes[1].graded.message == "에러: boom")
        #expect(outcomes[0].graded.passed)
    }
}
