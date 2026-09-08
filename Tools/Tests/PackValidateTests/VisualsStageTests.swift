import ContentKit
import Foundation
import PackReport
import Testing

@testable import PackValidate

/// 시각화 사이드카(`visuals/<id>.json`) 검증.
///
/// ``VisualFrameSet`` 자체의 디코딩·의미 검증은 `ContentKitTests` 가 이미 촘촘히
/// 본다(``VisualFrameSetDecodingTests``). 여기서 다시 보는 것은 그 디코더를 **팩
/// 검증 게이트에 올바르게 태웠는가** 뿐이다 — 파일마다 돌리는가, 실패가 리포트
/// 모양(어느 파일인지 알 수 있는 요약 + 원문 증거)으로 나오는가, 파일 이름과 id 가
/// 어긋나면 잡히는가, 그리고 `visuals/` 가 없는(지금 리포의 모든 팩이 이 모양인)
/// 팩은 그대로 통과하는가.
@Suite("시각화 사이드카 검증")
struct VisualsStageTests {
    private static let healthyArrayJSON = """
        {
          "schemaVersion": 1,
          "id": "binary-search-v1",
          "kind": "array",
          "values": [1, 3, 5, 7, 9, 11],
          "frames": [
            {"caption": "탐색 시작", "pointers": [{"name": "lo", "index": 0}], "segments": []}
          ]
        }
        """

    /// 프레임이 하나도 없다 — ``VisualFrameSetError/noFrames``.
    private static let noFramesJSON = """
        {"schemaVersion": 1, "id": "empty-v1", "kind": "array", "values": [1, 2, 3], "frames": []}
        """

    /// `id` 필드가 통째로 빠졌다 — `VisualFrameSetError` 이전에 일반 디코딩 실패다.
    private static let missingIDFieldJSON = """
        {"schemaVersion": 1, "kind": "array", "values": [1], "frames": [{"caption": "x"}]}
        """

    /// 임시로 복사한 정상 픽스처 팩의 `visuals/` 아래에 파일을 하나 만든다.
    ///
    /// `PackEditor` 를 쓰지 않는 이유는 이 파일들이 매니페스트에 등록될 필요가 없기
    /// 때문이다 — `visuals/` 는 아직 `PackLayout` 의 등록 대상 디렉터리가 아니고,
    /// 이 검사는 애초에 매니페스트가 아니라 디스크를 직접 본다.
    private static func addVisual(_ json: String, named fileName: String, to pack: PackEditor) throws {
        let directory = pack.root.appendingPathComponent("visuals", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent(fileName))
    }

    @Test("visuals/ 가 없는 팩은 통과한다 — 지금 리포의 모든 팩이 이 모양이다")
    func noVisualsDirectoryIsClean() throws {
        let pack = try ContentPack(directory: FixturePacks.valid)
        #expect(VisualsStage.failures(in: pack).isEmpty)
    }

    @Test("id 와 파일 이름이 일치하는 정상 사이드카는 통과한다")
    func healthySidecarIsClean() throws {
        let editor = try PackEditor.copyOfValidPack(label: "visuals-healthy")
        defer { editor.discard() }
        try Self.addVisual(Self.healthyArrayJSON, named: "binary-search-v1.json", to: editor)

        let pack = try ContentPack(directory: editor.root)
        #expect(VisualsStage.failures(in: pack).isEmpty)
    }

    @Test("여러 사이드카가 있으면 전부 디코드한다 — 건강한 것들 사이에 하나만 깨져도 잡는다")
    func decodesEveryFileInDirectory() throws {
        let editor = try PackEditor.copyOfValidPack(label: "visuals-multiple")
        defer { editor.discard() }
        try Self.addVisual(Self.healthyArrayJSON, named: "binary-search-v1.json", to: editor)
        try Self.addVisual(Self.noFramesJSON, named: "empty-v1.json", to: editor)

        let pack = try ContentPack(directory: editor.root)
        let failures = VisualsStage.failures(in: pack)
        #expect(failures.count == 1)
        #expect(failures.first?.summary.contains("empty-v1.json") == true)
    }

    @Test("VisualFrameSetError 는 description 을 증거로 그대로 싣는다")
    func visualFrameSetErrorCarriesDescription() throws {
        let editor = try PackEditor.copyOfValidPack(label: "visuals-no-frames")
        defer { editor.discard() }
        try Self.addVisual(Self.noFramesJSON, named: "empty-v1.json", to: editor)

        let pack = try ContentPack(directory: editor.root)
        let failure = try #require(VisualsStage.failures(in: pack).first)
        #expect(failure.stage == .structural)
        #expect(failure.kind == .brokenReference)
        #expect(failure.summary.contains("visuals/empty-v1.json"))
        #expect(failure.evidence?.contains("frames 가 비어 있다") == true)
    }

    @Test("id 필드가 아예 빠진 JSON 은 일반 디코딩 실패로 잡힌다")
    func malformedJSONFailsWithGenericMessage() throws {
        let editor = try PackEditor.copyOfValidPack(label: "visuals-malformed")
        defer { editor.discard() }
        try Self.addVisual(Self.missingIDFieldJSON, named: "broken.json", to: editor)

        let pack = try ContentPack(directory: editor.root)
        let failure = try #require(VisualsStage.failures(in: pack).first)
        #expect(failure.summary.contains("broken.json"))
        #expect(failure.summary.contains("디코딩할 수 없다"))
    }

    @Test("파일 이름과 id 가 어긋나면 실패한다 — 레슨이 id 로 사이드카를 찾는다")
    func fileNameIDMismatchFails() throws {
        let editor = try PackEditor.copyOfValidPack(label: "visuals-mismatch")
        defer { editor.discard() }
        // JSON 의 id 는 "binary-search-v1" 인데 파일 이름은 다르게 저작했다.
        try Self.addVisual(Self.healthyArrayJSON, named: "wrong-name.json", to: editor)

        let pack = try ContentPack(directory: editor.root)
        let failure = try #require(VisualsStage.failures(in: pack).first)
        #expect(failure.summary.contains("wrong-name.json"))
        #expect(failure.summary.contains("binary-search-v1"))
    }

    @Test("StructuralStage 에 배선돼 있다 — run 을 통해서도 같은 실패가 팩 전체 슬롯에 붙는다")
    func wiredIntoStructuralStage() throws {
        let editor = try PackEditor.copyOfValidPack(label: "visuals-wiring")
        defer { editor.discard() }
        try Self.addVisual(Self.noFramesJSON, named: "empty-v1.json", to: editor)

        let pack = try ContentPack(directory: editor.root)
        var table = FailureTable()
        StructuralStage.run(pack: pack, into: &table)

        // `visuals/` 는 아직 PackLayout 의 등록 대상 디렉터리가 아니라 `compareFiles` 도
        // 별도로(무관한 이유로) 실패를 하나 더 얹는다 — 그래서 정확한 개수가 아니라
        // 우리 검사가 낸 메시지가 들어 있는지만 본다.
        let failures = table.failures(of: FailureTable.packLevelStableID)
        #expect(failures.contains { $0.summary.contains("visuals/empty-v1.json") })
    }
}
