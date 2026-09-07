import ContentKit
import Foundation
import LearnCore
import PackReport
import Testing

@testable import PackValidate

/// 실행 게이트.
///
/// SQL 트랙만으로 단언하는 검사가 많은 것은 의도다 — 인프로세스 러너는 외부 바이너리를
/// 하나도 쓰지 않으므로 python·swift 가 없는 머신에서도 **같은 결과**가 나온다.
/// python·swift 가 걸린 검사는 `--allow-missing-toolchain` 을 켜 두어, 툴체인이 없는
/// 머신에서는 건너뛰고 있는 머신에서는 실제로 태운다.
@Suite("실행 게이트")
struct ExecutionGateTests {
    private static func validate(
        _ directory: URL, allowMissingToolchain: Bool = true
    ) async -> ValidationOutcome {
        await PackValidator(
            packDirectory: directory,
            options: ValidationOptions(
                allowMissingToolchain: allowMissingToolchain, validatedAt: 0)
        ).validate()
    }

    private static func failure(
        _ outcome: ValidationOutcome, lesson: String, kind: PackValidationReport.Failure.Kind
    ) -> PackValidationReport.Failure? {
        outcome.report.lessons
            .first { $0.stableID == lesson }?
            .failures.first { $0.kind == kind }
    }

    // MARK: - 툴체인 정책

    @Test("SQL 은 툴체인 없이도 준비 완료다 — 인프로세스 러너다")
    func sqlNeedsNoToolchain() async {
        guard case .ready = await ExecutionStage.readiness(for: .sql, launcher: nil) else {
            Issue.record("SQL 이 준비되지 않았다고 한다")
            return
        }
    }

    @Test("런처가 없으면 python·swift 는 준비되지 않은 것이다")
    func missingLauncherBlocksSubprocessTracks() async {
        for language in [LanguageID.python, .swift] {
            guard case .unavailable(let reason) = await ExecutionStage.readiness(
                for: language, launcher: nil)
            else {
                Issue.record("\(language.rawValue) 가 런처 없이 준비됐다고 한다")
                continue
            }
            #expect(reason.contains("learn-launcher"))
        }
    }

    /// Swift 예제는 `swiftc` 를 직접 띄운다. `SDKROOT` 이 비어 있으면 표준 라이브러리를
    /// 못 찾아 **멀쩡한 레슨이 전부 컴파일 실패로 뒤집힌다** — 실측으로 겪은 오탐이다.
    @Test("Swift 게이트 전에 SDKROOT 이 채워진다")
    func sdkRootIsEnsured() async throws {
        try #require(
            FileManager.default.isExecutableFile(atPath: "/usr/bin/xcrun"),
            "xcrun 이 없는 머신에서는 Swift 트랙 자체가 성립하지 않는다")
        await ToolchainEnvironment.ensureSDKRoot()
        let root = try #require(ToolchainEnvironment.current, "SDKROOT 이 비어 있다")
        #expect(FileManager.default.fileExists(atPath: root))
    }

    @Test("실행기가 없는 언어는 태우지 않는다")
    func unknownLanguageIsUnavailable() async {
        // 예전에는 `rust` 가 이 자리의 예시였다. 2026-09-07 에 Rust·C++ 실행기와 채점기가
        // 생기면서 실제로 태울 수 있게 됐으므로, 아직 백엔드가 없는 언어로 바꾼다.
        // 이 테스트가 지키는 것은 "특정 언어" 가 아니라 **모르는 언어를 조용히 통과시키지
        // 않는다** 는 성질이다 — 통과도 실패도 아닌 채로 지나가면 검증되지 않은 콘텐츠가
        // 팩에 들어간다.
        for language in ["go", "java", "typescript", "assembly"] {
            guard case .unavailable = await ExecutionStage.readiness(
                for: LanguageID(language), launcher: URL(fileURLWithPath: "/bin/echo"))
            else {
                Issue.record("\(language) 를 태울 수 있다고 한다")
                return
            }
        }
    }

    @Test("툴체인이 없으면 스킵이 아니라 실패가 기본이다")
    func missingToolchainFailsByDefault() async throws {
        let pack = try ContentPack(directory: FixturePacks.valid)
        let lessons = try #require(parsedLessons(of: pack))
        let stage = ExecutionStage(
            pack: pack, options: ValidationOptions(allowMissingToolchain: false),
            probe: { _, _ in .unavailable("테스트가 없다고 했다") })
        let result = await stage.run(lessons)

        #expect(!result.failures.isEmpty)
        #expect(result.ranEverything, "돌지 못한 것을 스킵으로 접으면 안 된다 — 실패로 남아야 한다")
        #expect(result.skipNotes.isEmpty)
        let first = try #require(result.failures.first?.failure)
        #expect(first.stage == .execution)
        #expect(first.evidence?.contains("--allow-missing-toolchain") == true)
    }

    @Test("--allow-missing-toolchain 을 명시하면 건너뛰고 그 사실이 남는다")
    func explicitFlagSkipsAndRecords() async throws {
        let pack = try ContentPack(directory: FixturePacks.valid)
        let lessons = try #require(parsedLessons(of: pack))
        let stage = ExecutionStage(
            pack: pack, options: ValidationOptions(allowMissingToolchain: true),
            probe: { _, _ in .unavailable("테스트가 없다고 했다") })
        let result = await stage.run(lessons)

        #expect(result.failures.isEmpty)
        #expect(!result.ranEverything, "건너뛴 실행을 '돌았다'로 보고하면 안 된다")
        #expect(!result.skipNotes.isEmpty)
    }

    // MARK: - SwiftPM 템플릿 자리

    /// 머신 전역으로 고정된 템플릿 경로는 병렬 워크트리에서 SwiftPM 락을 물고,
    /// 대기 끝에 **이전 실행의 결과**를 돌려준다(실측). 그래서 팩 경로로 갈라야 한다.
    @Test("Swift 템플릿 경로는 팩마다 갈리고 같은 팩에는 고정이다")
    func swiftTemplateIsKeyedByPack() {
        let a = SwiftTemplateLocation.directory(for: URL(fileURLWithPath: "/x/packs/one"))
        let b = SwiftTemplateLocation.directory(for: URL(fileURLWithPath: "/x/packs/two"))
        let again = SwiftTemplateLocation.directory(for: URL(fileURLWithPath: "/x/packs/one/"))
        #expect(a != b)
        #expect(a == again)
        #expect(a.lastPathComponent.hasPrefix("packtool-swift-template-"))
        #expect(a.lastPathComponent != "packtool-swift-template-")
    }

    // MARK: - 실제 실행

    @Test("정상 픽스처 팩은 실행 게이트까지 통과한다")
    func validPackPassesExecution() async {
        let outcome = await Self.validate(FixturePacks.valid)
        #expect(outcome.report.isClean, note(TextReport.render(outcome)))
        // 전부 태웠으면 execution 이 stagesRun 에 있고, 하나라도 건너뛰었으면 없다.
        #expect(outcome.report.executionStageRan == outcome.skipNotes.isEmpty)
    }

    @Test("starter 가 이미 통과하면 잡는다 — 가장 흔한 결함이다")
    func starterAlreadyPassesIsCaught() async throws {
        let pack = try PackEditor.copyOfValidPack(label: "starter-passes")
        defer { pack.discard() }
        let solution = try pack.text(at: "solutions/fx-0002-count.sql")
        try pack.replace("starters/fx-0002-count.sql", with: solution)

        let outcome = await Self.validate(pack.root)
        let failure = try #require(
            Self.failure(outcome, lesson: "fx-0002-count", kind: .starterAlreadyPasses),
            note(TextReport.render(outcome)))
        #expect(failure.stage == .execution)
        #expect(failure.blockID == "top-price")
    }

    @Test("solution 이 숨은 테스트를 통과하지 못하면 잡는다")
    func solutionFailingTestsIsCaught() async throws {
        let pack = try PackEditor.copyOfValidPack(label: "solution-fails")
        defer { pack.discard() }
        try pack.replace(
            "solutions/fx-0002-count.sql", with: "SELECT kind, MIN(price) AS price\nFROM item\nGROUP BY kind;\n")

        let outcome = await Self.validate(pack.root)
        let failure = try #require(
            Self.failure(outcome, lesson: "fx-0002-count", kind: .solutionFailsTests),
            note(TextReport.render(outcome)))
        #expect(failure.evidence?.contains("결과셋 일치") == true)
    }

    @Test("예제 출력이 다르면 줄 단위 diff 가 증거에 실린다")
    func exampleMismatchCarriesDiff() async throws {
        let pack = try PackEditor.copyOfValidPack(label: "example-mismatch")
        defer { pack.discard() }
        try pack.replace("expected/fx-0002-count-run.txt", with: "kind | n\na | 99\nb | 1\n")

        let outcome = await Self.validate(pack.root)
        let failure = try #require(
            Self.failure(outcome, lesson: "fx-0002-count", kind: .exampleOutputMismatch),
            note(TextReport.render(outcome)))
        let evidence = try #require(failure.evidence)
        #expect(evidence.contains("- a | 99"))
        #expect(evidence.contains("+ a | 2"))
        #expect(evidence.contains("[stdout"))
    }

    @Test("예제가 아예 실행되지 않으면 러너 원문이 증거로 실린다")
    func exampleFailureCarriesRunnerOutput() async throws {
        let pack = try PackEditor.copyOfValidPack(label: "example-broken")
        defer { pack.discard() }
        let lesson = try pack.text(at: "lessons/fx-0002-count.md")
        try pack.replace(
            "lessons/fx-0002-count.md",
            with: lesson.replacingOccurrences(of: "FROM item", with: "FROM no_such_table"))

        let outcome = await Self.validate(pack.root)
        let failure = try #require(
            Self.failure(outcome, lesson: "fx-0002-count", kind: .exampleFailedToRun),
            note(TextReport.render(outcome)))
        #expect(failure.evidence?.contains("no_such_table") == true)
    }

    // MARK: -

    /// 파싱까지만 돌려 실행 단위를 만든다.
    private func parsedLessons(of pack: ContentPack) -> [ParsedLesson]? {
        var table = FailureTable()
        let parsed = SyntaxStage.run(pack: pack, into: &table)
        return parsed.isEmpty ? nil : parsed
    }
}
