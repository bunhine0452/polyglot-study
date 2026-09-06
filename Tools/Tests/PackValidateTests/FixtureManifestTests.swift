import ContentKit
import Foundation
import Testing

@Suite("픽스처 팩 매니페스트")
struct FixtureManifestTests {
    /// 픽스처 팩의 `files` 는 파생값이다. 손으로 적으면 반드시 낡는다.
    /// 낡았을 때 갱신: `PACKTOOL_REGEN=1 swift test --package-path Tools --filter 픽스처`
    @Test("files 가 디스크와 정확히 일치한다")
    func manifestIsCurrent() throws {
        let directory = FixturePacks.valid
        let url = directory.appendingPathComponent("manifest.json")
        let onDisk = try Data(contentsOf: url)
        let manifest = try CanonicalJSON.decode(PackManifest.self, from: onDisk)
        let rebuilt = try PackManifestBuilder.rebuildingFiles(of: manifest, in: directory)
        let canonical = try CanonicalJSON.encode(rebuilt)

        if ProcessInfo.processInfo.environment["PACKTOOL_REGEN"] == "1" {
            try PackManifestBuilder.write(rebuilt, to: directory)
            return
        }
        #expect(
            onDisk == canonical,
            "픽스처 매니페스트가 낡았다 — PACKTOOL_REGEN=1 로 다시 구워라")
    }

    @Test("잠금 파일이 매니페스트를 허락한다")
    func lockAllowsManifest() throws {
        let pack = try ContentPack(directory: FixturePacks.valid)
        try pack.checkStableIDLock()
        try pack.verifyChecksums()
    }
}
