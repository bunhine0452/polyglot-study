public import Foundation

/// 팩 디렉터리를 훑어 `files` 목록을 다시 계산한다.
///
/// 해시를 손으로 적는 매니페스트는 반드시 낡는다. 그래서 `files` 는 **파생값**으로 두고,
/// 사람이 쓰는 것은 헤더와 `lessons` 뿐이다. `packtool build` 와 CI 의 "매니페스트가
/// 최신인가" 검사가 이 함수 하나를 공유한다.
public enum PackManifestBuilder {
    /// 기존 매니페스트의 헤더·레슨을 그대로 두고 `files` 만 디스크에서 재계산한다.
    ///
    /// 결과를 ``CanonicalJSON/encode(_:)`` 로 구우면 몇 번을 돌려도 같은 바이트가 나온다 —
    /// 정렬이 경로 사전순으로 고정돼 있고, `generatedAt` 은 입력이지 현재 시각이 아니다.
    public static func rebuildingFiles(of manifest: PackManifest, in directory: URL) throws
        -> PackManifest
    {
        var rebuilt = manifest
        rebuilt.files = try scanFiles(in: directory)
        return rebuilt
    }

    /// 팩 디렉터리의 등록 대상 파일 전부. 경로 사전순.
    public static func scanFiles(in directory: URL) throws -> [PackManifest.FileEntry] {
        var entries: [PackManifest.FileEntry] = []
        for item in try PackDirectoryWalk.items(in: directory) {
            if item.isDirectory || item.isSymbolicLink { continue }
            if item.relativePath == PackLayout.manifestFileName { continue }
            let path = try PackRelativePath(validating: item.relativePath)
            guard PackLayout.isRegisterable(path) else {
                throw PackInstallError.fileOutsideLayout(path: item.relativePath)
            }
            entries.append(
                PackManifest.FileEntry(
                    path: path.rawValue,
                    sha256: try FileDigest.sha256(ofFileAt: item.url),
                    bytes: item.byteCount))
        }
        return entries.sorted { $0.path < $1.path }
    }

    /// 매니페스트를 정규 바이트로 팩 디렉터리에 쓴다.
    public static func write(_ manifest: PackManifest, to directory: URL) throws {
        let data = try CanonicalJSON.encode(manifest)
        try data.write(
            to: directory.appendingPathComponent(PackLayout.manifestFileName), options: .atomic)
    }

    /// 잠금 파일을 정규 텍스트로 쓴다.
    public static func writeLock(_ lock: StableIDLock, to directory: URL) throws {
        let data = Data(lock.canonicalText().utf8)
        try data.write(
            to: directory.appendingPathComponent(PackLayout.lockFileName), options: .atomic)
    }
}
