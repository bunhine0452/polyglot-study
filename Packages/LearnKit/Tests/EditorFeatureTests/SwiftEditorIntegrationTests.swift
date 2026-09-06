import DesignSystem
import Foundation
import LanguageKit
import LearnCore
import RunnerKit
import Testing

@testable import EditorFeature

/// `{#screen-editor-console}`·`{#inline-diagnostic-row}` 종단 검증 — **목 데이터가
/// 아니라** 실제 `swiftc` 를 돌려 나온 `Diagnostic` 으로 그린다. `run()` 은 팩토리를
/// 주입하지 않는다 — `EditorModel` 의 기본 배선(`SwiftLanguageModule`)이 검증 대상이다.
@Suite("Swift 에디터 · 실제 swiftc 종단 검증", .serialized)
struct SwiftEditorIntegrationTests {
    /// `design/Editor.dc.html` 의 예시 그대로 — `mutating` 없이 `self` 를 바꾸려는 코드.
    static let mutatingSelfBug = """
        struct Counter {
            var count = 0
            func increment() {
                count += 1
            }
        }
        var counter = Counter()
        counter.increment()
        counter.increment()
        print(counter.count)
        """

    @Test("mutating 누락은 swiftc 가 실제로 4행 진단을 낸다")
    func realSwiftcReportsMutatingDiagnostic() async throws {
        RealToolchainEnvironment.install()
        let model = EditorModel(task: SampleTask.swift(starter: Self.mutatingSelfBug))
        await model.run()

        if case .failed = model.runState {
            Issue.record("swiftc 를 실행할 수 없었다(툴체인 부재) — 이 환경에선 Xcode 26.6 가 있어야 한다")
            return
        }

        let errors = model.diagnostics.filter { $0.severity == .error }
        #expect(!errors.isEmpty, "swiftc 가 에러를 내지 않았다: \(model.diagnostics)")
        #expect(errors.contains { $0.line == 4 }, "\(model.diagnostics)")

        let row = try #require(model.diagnosticRows.first { $0.line == 4 })
        #expect(row.codeLine.contains("count += 1"))
        #expect(row.locationLabel.contains("swiftc"))
        let message = row.message.lowercased()
        #expect(message.contains("mutating") || message.contains("immutable"), "\(row.message)")
    }

    @Test("mutating 을 붙이면 실제로 컴파일·실행되어 stdout 에 2 가 찍힌다")
    func realSwiftcCompilesFixedVersion() async {
        RealToolchainEnvironment.install()
        let fixed = Self.mutatingSelfBug.replacingOccurrences(
            of: "func increment()", with: "mutating func increment()"
        )
        let model = EditorModel(task: SampleTask.swift(starter: fixed))
        await model.run()

        guard case .finished(let succeeded, let exitCode, _) = model.runState else {
            Issue.record("finished 상태가 아니다: \(model.runState)")
            return
        }
        #expect(succeeded)
        #expect(exitCode == 0)
        #expect(model.transcript.standardOutputText.contains("2"))
        #expect(model.diagnosticRows.isEmpty)
    }
}

/// `{#screen-editor-console}` 의 "제출" — 숨은 테스트를 실제 `SwiftTestingGrader` 로
/// 돌린다. 템플릿 디렉터리는 체크아웃 경로 해시를 써서 병렬 워크트리가 같은
/// SwiftPM 캐시를 밟지 않게 한다 — `RunnerKitTests.LanguageSwiftGradingTests` 와
/// 같은 이유·같은 방식이다.
@Suite("Swift 에디터 · 실제 제출 채점", .serialized)
struct SwiftEditorSubmitIntegrationTests {
    nonisolated static let templateDirectory: URL = {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in #filePath.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("editorfeature-swift-template-\(String(hash, radix: 36))", isDirectory: true)
    }()

    /// `EditorModel.defaultGrade` 의 `.swift` 분기와 같은 모양이다 — 다른 것은 그
    /// 안의 `SwiftTestingGrader` 가 쓰는 작업 디렉터리뿐이다. 여전히 진짜
    /// `swift test` 를 돈다.
    private static func graderFactory() -> EditorGraderFactory {
        { task, code in
            guard let testSource = task.testSource else {
                throw RunFailure.backend("이 과제에는 숨은 테스트가 없습니다")
            }
            let grader = SwiftTestingGrader(configuration: .init(templateDirectory: templateDirectory, buildJobs: 2))
            let grading = try await grader.grade(
                solution: [SourceFile(path: "Solution.swift", contents: code)],
                tests: [SourceFile(path: "SolutionTests.swift", contents: testSource)]
            )
            return EditorGradeOutcome(result: grading.result)
        }
    }

    /// `@testable import Solution` 이 internal 멤버까지 보므로 `public` 이 필요 없다.
    /// 라이브러리 타깃 파일이라 `mutatingSelfBug` 와 달리 최상위 실행문은 없다 —
    /// `main.swift` 가 아닌 파일에 최상위 문이 있으면 그 자체로 컴파일이 깨진다.
    static let counterWithMutating = """
        struct Counter {
            var count = 0
            mutating func increment() {
                count += 1
            }
        }
        """

    static let counterWithoutMutating = """
        struct Counter {
            var count = 0
            func increment() {
                count += 1
            }
        }
        """

    static let hiddenTests = """
        import Testing
        @testable import Solution

        @Test("count 는 0 에서 시작한다") func startsAtZero() { #expect(Counter().count == 0) }
        @Test("increment 를 두 번 호출하면 2") func incrementsTwice() {
            var c = Counter(); c.increment(); c.increment()
            #expect(c.count == 2)
        }
        """

    @Test("올바른 제출은 실제 swift test 로 통과한다")
    func realSubmitPasses() async throws {
        let model = EditorModel(
            task: SampleTask.swift(starter: Self.counterWithMutating, testSource: Self.hiddenTests),
            graderFactory: Self.graderFactory()
        )
        await model.submit()

        guard case .graded(let result) = model.gradeState else {
            Issue.record("채점 상태가 아니다: \(model.gradeState)")
            return
        }
        #expect(result.passed, "\(result.tests)")
        #expect(model.activeTab == .tests)
    }

    @Test("mutating 이 없는 제출은 실제로 빌드가 실패해 오답이 된다")
    func realSubmitFailsOnBuildError() async throws {
        let model = EditorModel(
            task: SampleTask.swift(starter: Self.counterWithoutMutating, testSource: Self.hiddenTests),
            graderFactory: Self.graderFactory()
        )
        await model.submit()
        guard case .graded(let result) = model.gradeState else {
            Issue.record("채점 상태가 아니다: \(model.gradeState)")
            return
        }
        #expect(!result.passed)
        #expect(result.hasErrors)
    }
}
