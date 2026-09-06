import Foundation
import Testing

@testable import ContentKit

/// 샘플 팩의 `manifest.json` 을 디스크 상태로 다시 굽는다.
///
/// 평소에는 돌지 않는다. 샘플 팩의 파일을 고친 뒤 `REGEN=1 swift test --filter
/// regenerateSamplePackManifest` 로 한 번 돌리면 해시와 크기가 갱신된다.
/// `packtool build` 가 생기면 이 테스트는 그쪽으로 옮겨가고 여기서 사라진다.
@Test(
    "샘플 팩 매니페스트 재생성 (REGEN=1 일 때만)",
    .enabled(if: ProcessInfo.processInfo.environment["REGEN"] != nil))
func regenerateSamplePackManifest() throws {
    let pack = RepoPaths.samplePack
    let manifestURL = pack.appendingPathComponent(PackLayout.manifestFileName)
    let data = try #require(FileManager.default.contents(atPath: manifestURL.path))
    let manifest = try CanonicalJSON.decode(PackManifest.self, from: data)

    // 잠금 파일이 `files` 에 들어가므로 잠금을 먼저 쓰고 매니페스트를 나중에 굽는다.
    try PackManifestBuilder.writeLock(StableIDLock.from(manifest: manifest), to: pack)
    let rebuilt = try PackManifestBuilder.rebuildingFiles(of: manifest, in: pack)
    try PackManifestBuilder.write(rebuilt, to: pack)
}
