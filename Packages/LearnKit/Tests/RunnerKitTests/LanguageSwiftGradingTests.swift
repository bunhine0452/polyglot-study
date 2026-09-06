import Testing
import Foundation
import LanguageKit
import LearnCore
@testable import RunnerKit

@Suite("Swift Testing 채점 실측", .serialized)
struct LanguageSwiftGradingTests {

    /// 예열된 템플릿은 **테스트 실행 사이에도 살아남아야** 의미가 있다.
    /// 고정 이름을 쓰는 이유가 그것이다 — 첫 실행만 비싸고 이후는 증분 빌드다.
    static let templateDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("learnkit-swift-template-tests", isDirectory: true)

    private static func grader() -> SwiftTestingGrader {
        // 채점은 SwiftPM 을 통째로 돌린다 — 병렬 스위트의 시간 측정과 겹치면 남의
        // 벤치마크가 깨지므로 잡 수를 낮추고, 호출도 `CompilerLoadGate` 로 묶는다.
        SwiftTestingGrader(configuration: .init(templateDirectory: templateDirectory, buildJobs: 2))
    }

    private static let solution = SourceFile(path: "Add.swift", contents: """
        public func add(_ a: Int, _ b: Int) -> Int { a + b }
        """)

    private static let passingTests = SourceFile(path: "AddTests.swift", contents: """
        import Testing
        @testable import Solution

        @Test("덧셈") func addition() { #expect(add(2, 3) == 5) }
        @Test("항등원") func identity() { #expect(add(7, 0) == 7) }
        """)

    @Test("예열 후 2회차 채점이 5초 이내에 끝난다")
    func warmedGradeIsFast() async throws {
        try await CompilerLoadGate.shared.withAccess {
            let grader = Self.grader()
            // 1회차는 하네스 컴파일까지 포함이라 비싸다. 그게 예열의 정의다.
            _ = try await grader.warmUp()
            _ = try await grader.grade(solution: [Self.solution], tests: [Self.passingTests])

            let clock = ContinuousClock()
            let started = clock.now
            let grading = try await grader.grade(solution: [Self.solution], tests: [Self.passingTests])
            let elapsed = started.duration(to: clock.now)

            #expect(grading.passed, "\(grading.rawOutput)")
            #expect(elapsed < .seconds(5), "2회차 채점이 \(elapsed) 걸렸다")
        }
    }

    @Test("이벤트 스트림에서 테스트 이름과 통과 여부를 읽는다")
    func readsTestOutcomes() async throws {
        try await CompilerLoadGate.shared.withAccess {
            let grading = try await Self.grader().grade(
                solution: [Self.solution],
                tests: [Self.passingTests]
            )
            let names = Set(grading.result.tests.map(\.name))
            #expect(names == ["덧셈", "항등원"], "\(grading.result.tests)")
            #expect(grading.result.tests.filter { !$0.passed }.isEmpty)
            #expect(grading.passed)
            #expect(!grading.buildFailed)
        }
    }

    @Test("실패한 테스트는 메시지와 함께 실패로 온다")
    func failingTestIsReported() async throws {
        let failing = SourceFile(path: "AddTests.swift", contents: """
            import Testing
            @testable import Solution

            @Test("틀린 기대") func wrong() { #expect(add(2, 3) == 6, "합이 다르다") }
            @Test("맞는 기대") func right() { #expect(add(2, 3) == 5) }
            """)
        try await CompilerLoadGate.shared.withAccess {
            let grading = try await Self.grader().grade(solution: [Self.solution], tests: [failing])

            #expect(!grading.passed)
            let byName = Dictionary(uniqueKeysWithValues: grading.result.tests.map { ($0.name, $0) })
            #expect(byName["맞는 기대"]?.passed == true)
            #expect(byName["틀린 기대"]?.passed == false)
            #expect(byName["틀린 기대"]?.message?.contains("합이 다르다") == true, "\(grading.result.tests)")
        }
    }

    @Test("컴파일이 실패하면 진단이 나오고 buildFailed 가 참이다")
    func buildFailureCarriesDiagnostics() async throws {
        let broken = SourceFile(
            path: "Add.swift",
            contents: "public func add(_ a: Int, _ b: Int) -> Int { a ++ b }"
        )
        try await CompilerLoadGate.shared.withAccess {
            let grading = try await Self.grader().grade(solution: [broken], tests: [Self.passingTests])

            #expect(!grading.passed)
            #expect(grading.buildFailed, "\(grading.rawOutput)")
            #expect(grading.result.diagnostics.contains { $0.severity == .error })
            #expect(!grading.result.tests.isEmpty)
        }
    }

    @Test("지난 채점의 소스가 다음 채점에 남지 않는다")
    func previousSubmissionDoesNotLeak() async throws {
        try await CompilerLoadGate.shared.withAccess {
            let grader = Self.grader()
            let extra = SourceFile(path: "Extra.swift", contents: "public let leaked = 1")
            _ = try await grader.grade(solution: [Self.solution, extra], tests: [Self.passingTests])

            let usesLeaked = SourceFile(path: "AddTests.swift", contents: """
                import Testing
                @testable import Solution

                @Test("남은 심볼") func leftover() { #expect(leaked == 1) }
                """)
            let grading = try await grader.grade(solution: [Self.solution], tests: [usesLeaked])
            // Extra.swift 가 지워졌으므로 `leaked` 는 더 이상 존재하지 않아 빌드가 실패해야 한다.
            #expect(grading.buildFailed, "\(grading.rawOutput)")
        }
    }
}

@Suite("Swift Testing 이벤트 스트림 파싱")
struct SwiftTestingEventStreamTests {

    @Test("function 기록만 결과가 되고 suite 는 제외된다")
    func onlyFunctionsBecomeOutcomes() {
        let lines = """
            {"kind":"test","payload":{"id":"S","kind":"suite","name":"Suite"},"version":0}
            {"kind":"test","payload":{"id":"A","kind":"function","name":"a()","displayName":"덧셈"},"version":0}
            {"kind":"event","payload":{"kind":"testStarted","testID":"A","instant":{"absolute":100.0}},"version":0}
            {"kind":"event","payload":{"kind":"testEnded","testID":"A","instant":{"absolute":100.25}},"version":0}
            """
        let outcomes = SwiftTestingEventStream.parse(jsonLines: Data(lines.utf8))
        #expect(outcomes.count == 1)
        #expect(outcomes[0].name == "덧셈")
        #expect(outcomes[0].passed)
        #expect(outcomes[0].durationMilliseconds == 250)
    }

    @Test("issueRecorded 가 있으면 실패이고 메시지가 붙는다")
    func issueMarksFailure() {
        let lines = """
            {"kind":"test","payload":{"id":"A","kind":"function","name":"a()"},"version":0}
            {"kind":"event","payload":{"kind":"testStarted","testID":"A","instant":{"absolute":1.0}},"version":0}
            {"kind":"event","payload":{"kind":"issueRecorded","testID":"A","messages":[{"symbol":"fail","text":"Expectation failed"},{"symbol":"details","text":"합이 다르다"}],"instant":{"absolute":1.1}},"version":0}
            {"kind":"event","payload":{"kind":"testEnded","testID":"A","instant":{"absolute":1.2}},"version":0}
            """
        let outcomes = SwiftTestingEventStream.parse(jsonLines: Data(lines.utf8))
        #expect(outcomes.count == 1)
        #expect(!outcomes[0].passed)
        #expect(outcomes[0].message?.contains("Expectation failed") == true)
        #expect(outcomes[0].message?.contains("합이 다르다") == true)
    }

    @Test("병렬 실행으로 줄 순서가 섞여도 시간은 instant 로 잰다")
    func durationUsesInstantNotLineOrder() {
        let lines = """
            {"kind":"test","payload":{"id":"A","kind":"function","name":"a()"},"version":0}
            {"kind":"test","payload":{"id":"B","kind":"function","name":"b()"},"version":0}
            {"kind":"event","payload":{"kind":"testStarted","testID":"B","instant":{"absolute":10.0}},"version":0}
            {"kind":"event","payload":{"kind":"testStarted","testID":"A","instant":{"absolute":10.5}},"version":0}
            {"kind":"event","payload":{"kind":"testEnded","testID":"A","instant":{"absolute":10.6}},"version":0}
            {"kind":"event","payload":{"kind":"testEnded","testID":"B","instant":{"absolute":12.0}},"version":0}
            """
        let outcomes = SwiftTestingEventStream.parse(jsonLines: Data(lines.utf8))
        let byName = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.name, $0) })
        #expect(byName["b()"]?.durationMilliseconds == 2000)
        #expect(byName["a()"]?.durationMilliseconds == 100)
    }

    @Test("xUnit 폴백도 통과·실패를 가른다")
    func xunitFallback() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <testsuites>
              <testsuite name="All" tests="2" failures="1">
                <testcase classname="T" name="ok" time="0.010"/>
                <testcase classname="T" name="bad" time="0.020">
                  <failure message="틀렸다"/>
                </testcase>
              </testsuite>
            </testsuites>
            """
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("learnkit-xunit-\(UUID().uuidString).xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let outcomes = SwiftTestingEventStream.parseXUnit(at: url)
        #expect(outcomes.count == 2)
        #expect(outcomes[0].name == "T.ok")
        #expect(outcomes[0].passed)
        #expect(outcomes[0].durationMilliseconds == 10)
        #expect(!outcomes[1].passed)
        #expect(outcomes[1].message == "틀렸다")
    }
}
