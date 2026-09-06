import CryptoKit
import Foundation

/// 임시 디렉터리에 복사한 팩을 손대는 도구.
///
/// 픽스처를 **깨진 상태로 커밋하지 않는** 이유는 해시다. 손으로 적은 sha256 은 반드시
/// 낡고, 낡은 순간 픽스처는 자기가 검사하려던 것과 다른 이유로 실패한다. 그래서 정상
/// 팩 하나만 커밋하고, 깨뜨린 뒤 필요한 항목만 여기서 다시 계산한다.
struct PackEditor {
    let root: URL

    static func copyOfValidPack(label: String) throws -> PackEditor {
        PackEditor(root: try FixturePacks.copyToTemporary(FixturePacks.valid, label: label))
    }

    func discard() { FixturePacks.remove(root) }

    // MARK: - 파일

    /// 파일 내용을 바꾸고 매니페스트의 sha256·bytes 를 다시 계산한다.
    func replace(_ relativePath: String, with contents: String) throws {
        try Data(contents.utf8).write(to: root.appendingPathComponent(relativePath))
        try editManifest { manifest in
            Self.refresh(&manifest, path: relativePath, in: root)
        }
    }

    /// 파일 내용을 바꾸되 매니페스트는 **그대로 둔다** — 해시 불일치를 만들 때.
    func corrupt(_ relativePath: String, with contents: String) throws {
        try Data(contents.utf8).write(to: root.appendingPathComponent(relativePath))
    }

    func text(at relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func delete(_ relativePath: String) throws {
        try FileManager.default.removeItem(at: root.appendingPathComponent(relativePath))
    }

    // MARK: - 매니페스트

    func editManifest(_ body: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: url)
        guard var manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        body(&manifest)
        try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        ).write(to: url)
    }

    static func mutateFileEntry(
        _ manifest: inout [String: Any], path: String, _ body: (inout [String: Any]) -> Void
    ) {
        guard var files = manifest["files"] as? [[String: Any]],
            let index = files.firstIndex(where: { ($0["path"] as? String) == path })
        else { return }
        body(&files[index])
        manifest["files"] = files
    }

    static func refresh(_ manifest: inout [String: Any], path: String, in root: URL) {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(path)) else { return }
        mutateFileEntry(&manifest, path: path) { entry in
            entry["bytes"] = data.count
            entry["sha256"] = hex(SHA256.hash(data: data))
        }
    }

    static func hex(_ digest: some Sequence<UInt8>) -> String {
        let digits = Array("0123456789abcdef")
        var out = ""
        out.reserveCapacity(64)
        for byte in digest {
            out.append(digits[Int(byte >> 4)])
            out.append(digits[Int(byte & 0x0F)])
        }
        return out
    }
}
