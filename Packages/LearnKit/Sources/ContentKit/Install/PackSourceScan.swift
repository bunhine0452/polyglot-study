public import Foundation

/// 설치 **전에** 팩 소스 트리를 훑어 악성 경로를 걸러낸다.
///
/// 순서가 중요하다. 스테이징 디렉터리를 먼저 만들고 나서 검사하면, 거부된 팩도
/// 디스크에 흔적을 남긴다 — 그리고 심볼릭 링크는 복사하는 순간 이미 늦었다
/// (`copyItem` 은 링크를 따라가 링크 대상의 내용을 가져온다).
/// 그래서 스캔은 아무것도 만들기 전에 끝난다.
public struct PackSourceScan: Sendable {
    public struct Entry: Hashable, Sendable {
        public var path: PackRelativePath
        public var byteCount: Int
    }

    /// 팩 루트 기준 상대 경로 → 항목. `manifest.json` 은 제외한다(자기 해시를 담을 수 없다).
    public let files: [String: Entry]

    public init(files: [String: Entry]) { self.files = files }

    /// 소스 디렉터리를 훑는다. 위반이 있으면 **처음 만난 것**에서 던진다.
    public static func scan(directory: URL) throws(PackInstallError) -> PackSourceScan {
        let manager = FileManager.default

        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw .sourceNotADirectory(directory.path)
        }
        // 소스 루트 자체가 링크면 그 아래 전부를 신뢰할 수 없다.
        let rootAttributes = try? manager.attributesOfItem(atPath: directory.path)
        if rootAttributes?[.type] as? FileAttributeType == .typeSymbolicLink {
            throw .symbolicLink(path: ".")
        }

        let items: [PackDirectoryWalk.Item]
        do {
            items = try PackDirectoryWalk.items(in: directory)
        } catch {
            throw .sourceNotADirectory(directory.path)
        }

        var files: [String: Entry] = [:]
        for item in items {
            if item.isSymbolicLink { throw .symbolicLink(path: item.relativePath) }

            let path: PackRelativePath
            do {
                path = try PackRelativePath(validating: item.relativePath)
            } catch {
                throw .unsafeEntry(path: item.relativePath, reason: error)
            }
            // 디렉터리 이름도 경로 규칙을 지켜야 하지만 `files` 에는 들어가지 않는다.
            if item.isDirectory { continue }
            if path.rawValue == PackLayout.manifestFileName { continue }
            guard PackLayout.isRegisterable(path) else {
                throw .fileOutsideLayout(path: path.rawValue)
            }
            files[path.rawValue] = Entry(path: path, byteCount: item.byteCount)
        }
        return PackSourceScan(files: files)
    }

    /// 매니페스트가 선언한 경로들도 같은 검사를 통과해야 한다. 디스크에 없는 악성
    /// 경로(`../x`, `/etc/passwd`)는 스캔이 아니라 여기서 잡힌다.
    public static func validateDeclaredPaths(_ manifest: PackManifest) throws(PackInstallError) {
        for entry in manifest.files {
            let path: PackRelativePath
            do {
                path = try PackRelativePath(validating: entry.path)
            } catch {
                throw .unsafeEntry(path: entry.path, reason: error)
            }
            guard PackLayout.isRegisterable(path) else {
                throw .fileOutsideLayout(path: entry.path)
            }
        }
    }
}
