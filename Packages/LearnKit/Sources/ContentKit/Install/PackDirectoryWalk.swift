internal import Foundation

/// 팩 디렉터리를 훑으며 **상대 경로를 직접 조립하는** 워커.
///
/// `FileManager.enumerator(at:)` 를 쓰지 않는 이유는 실측 때문이다 — enumerator 가
/// 내놓는 URL 은 베이스 경로의 심볼릭 링크를 해석해 버린다. macOS 임시 디렉터리에서
/// `/var/folders/…` 로 시작하는 루트를 넘기면 `/private/var/folders/…` 로 시작하는 항목이
/// 돌아오고, 접두사를 잘라 상대 경로를 얻는 방식이 통째로 무너진다(항목 0개로 조용히
/// 성공한다 — 최악의 실패 방식이다).
///
/// 그래서 재귀하며 `lastPathComponent` 를 이어 붙인다. 상대 경로가 항상 정확하고,
/// 심볼릭 링크를 만나면 **내려가지 않는다**.
enum PackDirectoryWalk {
    struct Item {
        var url: URL
        /// 루트 기준 상대 경로. 항상 정확하다.
        var relativePath: String
        var isDirectory: Bool
        var isSymbolicLink: Bool
        var byteCount: Int
    }

    /// 깊이 우선, 각 디렉터리 안에서는 이름 사전순.
    static func items(in root: URL) throws -> [Item] {
        var items: [Item] = []
        try walk(root, prefix: "", into: &items)
        return items
    }

    private static func walk(_ directory: URL, prefix: String, into items: inout [Item]) throws {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [])

        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = entry.lastPathComponent
            let relative = prefix.isEmpty ? name : prefix + "/" + name
            let values = try? entry.resourceValues(forKeys: Set(keys))
            // 링크 판정이 먼저다. 디렉터리를 가리키는 링크는 `isDirectory` 가 true 로 오고,
            // 그걸 믿고 내려가면 팩 밖으로 걸어 나간다.
            let isLink = values?.isSymbolicLink == true
            let isDirectory = !isLink && values?.isDirectory == true

            items.append(
                Item(
                    url: entry, relativePath: relative, isDirectory: isDirectory,
                    isSymbolicLink: isLink, byteCount: values?.fileSize ?? 0))

            if isDirectory { try walk(entry, prefix: relative, into: &items) }
        }
    }
}
