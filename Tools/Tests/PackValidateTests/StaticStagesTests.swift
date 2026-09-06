import Foundation
import PackReport
import Testing

@testable import PackValidate

/// 툴체인을 하나도 쓰지 않는 세 단계 — 구조·문법·의미.
@Suite("정적 단계")
struct StaticStagesTests {
    private static func validateStatic(_ directory: URL) async -> ValidationOutcome {
        await PackValidator(
            packDirectory: directory,
            options: ValidationOptions(runExecution: false, validatedAt: 0)
        ).validate()
    }

    @Test("정상 픽스처 팩은 정적 세 단계를 통과한다")
    func validPackIsClean() async {
        let outcome = await Self.validateStatic(FixturePacks.valid)
        #expect(outcome.report.isClean, note(TextReport.render(outcome)))
        #expect(outcome.report.lessons.count == 2)
    }

    @Test("실행 게이트를 돌리지 않으면 stagesRun 에 execution 이 없다")
    func skippedExecutionIsVisibleInReport() async {
        let outcome = await Self.validateStatic(FixturePacks.valid)
        #expect(!outcome.report.executionStageRan)
        #expect(outcome.report.stagesRun == [.structural, .syntax, .semantic])
    }

    @Test("망가뜨린 픽스처는 전부 실패한다", arguments: BrokenPack.allCases)
    func brokenFixtureFails(_ broken: BrokenPack) async throws {
        let pack = try broken.materialize()
        defer { pack.discard() }
        let outcome = await Self.validateStatic(pack.root)
        #expect(!outcome.report.isClean, "\(broken.rawValue) 가 통과해 버렸다")
    }

    @Test("망가뜨린 픽스처 10종이 서로 다른 메시지로 실패한다")
    func brokenFixturesFailWithDistinctMessages() async throws {
        var messages: [String: String] = [:]
        for broken in BrokenPack.allCases {
            let pack = try broken.materialize()
            defer { pack.discard() }
            let outcome = await Self.validateStatic(pack.root)
            let first = outcome.report.failedLessons.first?.failures.first
            let summary = try #require(first?.summary, "\(broken.rawValue) 에 실패가 없다")
            messages[broken.rawValue] = summary
        }
        #expect(messages.count == BrokenPack.allCases.count)
        let distinct = Set(messages.values)
        #expect(
            distinct.count == messages.count,
            note(
                "메시지가 겹친다:\n"
                    + messages.sorted { $0.key < $1.key }
                    .map { "  \($0.key): \($0.value)" }.joined(separator: "\n")))
    }

    @Test("깨진 매니페스트는 팩 전체 슬롯에 붙고 packID 는 디렉터리 이름으로 떨어진다")
    func manifestFailureLandsOnPackSlot() async throws {
        let pack = try BrokenPack.manifestMissing.materialize()
        defer { pack.discard() }
        let outcome = await Self.validateStatic(pack.root)
        #expect(outcome.report.lessons.count == 1)
        #expect(outcome.report.lessons.first?.stableID == PackValidator.packLevelStableID)
        #expect(outcome.report.packID == "fixture-mvp")
        #expect(outcome.report.stagesRun == [.structural])
    }

    @Test("문법 실패는 line:column 을 들고 온다")
    func syntaxFailureCarriesPosition() async throws {
        let pack = try BrokenPack.malformedDirective.materialize()
        defer { pack.discard() }
        let outcome = await Self.validateStatic(pack.root)
        let failure = try #require(
            outcome.report.failedLessons.first?.failures.first(where: { $0.stage == .syntax }))
        #expect(failure.kind == .malformedDirective)
        #expect(failure.line == 1)
        #expect(failure.column == 1)
    }

    @Test("잠금 개명은 구조 단계에서 잡힌다")
    func lockRenameIsStructural() async throws {
        let pack = try BrokenPack.lockRename.materialize()
        defer { pack.discard() }
        let outcome = await Self.validateStatic(pack.root)
        let failure = try #require(outcome.report.failedLessons.first?.failures.first)
        #expect(failure.stage == .structural)
        #expect(failure.summary.contains("stableids.lock"))
        #expect(failure.evidence?.contains("개명") == true)
    }
}
