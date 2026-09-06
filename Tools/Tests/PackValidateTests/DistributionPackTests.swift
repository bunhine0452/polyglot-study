import ContentKit
import Foundation
import PackReport
import Testing

@testable import PackValidate

/// 배포 팩(`solutions/` 가 벗겨진 팩)을 검증기가 어떻게 보는가.
///
/// 팩을 `PackBuild` 로 굽지 않고 **손으로** 만드는 것은 의도다. 굽는 쪽이 고장 나도
/// 검증기의 계약은 그대로 서 있어야 하고, 두 타깃이 서로를 물면 그 독립이 사라진다.
@Suite("배포 팩 검증")
struct DistributionPackTests {
    /// 정상 팩에서 solutions 를 지우고 `distribution: true` 로 다시 센 팩.
    private static func distributionPack(label: String) throws -> PackEditor {
        let editor = try PackEditor.copyOfValidPack(label: label)
        try FileManager.default.removeItem(
            at: editor.root.appendingPathComponent(PackLayout.solutionsDirectory))
        try rewriteManifest(in: editor.root)
        return editor
    }

    private static func rewriteManifest(in root: URL) throws {
        var manifest = try ContentPack(directory: root).manifest
        manifest.distribution = true
        manifest = try PackManifestBuilder.rebuildingFiles(of: manifest, in: root)
        try PackManifestBuilder.write(manifest, to: root)
    }

    private static func validate(_ root: URL) async -> ValidationOutcome {
        await PackValidator(
            packDirectory: root, options: ValidationOptions(validatedAt: 0)
        ).validate()
    }

    @Test("배포 팩은 정적 세 단계를 통과한다 — solutions 가 없는 것이 정상이다")
    func distributionPackIsClean() async throws {
        let editor = try Self.distributionPack(label: "dist-clean")
        defer { editor.discard() }

        let outcome = await Self.validate(editor.root)
        #expect(outcome.isClean, note(TextReport.render(outcome)))
    }

    @Test("배포 팩에서는 실행 게이트가 돌지 않고, 돌지 않았다고 남는다")
    func executionStageIsNotClaimed() async throws {
        let editor = try Self.distributionPack(label: "dist-stages")
        defer { editor.discard() }

        let outcome = await Self.validate(editor.root)
        #expect(!outcome.report.executionStageRan, "solutions 없이 실행 게이트를 돌았다고 주장한다")
        #expect(!outcome.report.stagesRun.contains(.execution))
        #expect(outcome.skipNotes.contains { $0.contains("배포 팩") })
        // 사람이 읽는 출력에도 반드시 뜬다 — 이 결과를 '통과' 로 읽으면 안 되기 때문이다.
        #expect(TextReport.render(outcome).contains("배포 팩"))
    }

    @Test("배포 팩에 solutions 가 남아 있으면 잡는다 — 검사를 끄는 게 아니라 뒤집는다")
    func leftoverSolutionIsCaught() async throws {
        let editor = try PackEditor.copyOfValidPack(label: "dist-leftover")
        defer { editor.discard() }

        // solutions 를 그대로 둔 채 배포 팩이라고 주장한다.
        try editor.editManifest { manifest in manifest["distribution"] = true }

        let outcome = await Self.validate(editor.root)
        #expect(!outcome.isClean, "벗겨졌어야 할 solutions 가 남았는데 통과했다")
        let summaries = outcome.report.lessons.flatMap { $0.failures.map(\.summary) }
        #expect(
            summaries.contains { $0.contains("벗겨졌어야 할") && $0.contains("solutions/") },
            note(summaries.joined(separator: "\n")))
    }

    @Test("소스 팩에서는 solutions 가 없으면 여전히 실패다")
    func sourcePackStillNeedsSolutions() async throws {
        let editor = try PackEditor.copyOfValidPack(label: "source-missing")
        defer { editor.discard() }

        // distribution 을 세우지 않고 solutions 만 지운다.
        try FileManager.default.removeItem(
            at: editor.root.appendingPathComponent(PackLayout.solutionsDirectory))
        var manifest = try ContentPack(directory: editor.root).manifest
        manifest = try PackManifestBuilder.rebuildingFiles(of: manifest, in: editor.root)
        try PackManifestBuilder.write(manifest, to: editor.root)

        let outcome = await Self.validate(editor.root)
        #expect(!outcome.isClean)
        let summaries = outcome.report.lessons.flatMap { $0.failures.map(\.summary) }
        #expect(
            summaries.contains { $0.contains("solutions/") && $0.contains("files 에 없다") },
            note(summaries.joined(separator: "\n")))
    }
}
