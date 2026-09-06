public import LearnCore

public import Foundation

/// 설치된 팩들이 사는 디렉터리.
///
/// ```
/// <root>/<packID>/1.0.0/          버전 디렉터리 — 한 번 쓰이면 내용이 바뀌지 않는다
/// <root>/<packID>/1.1.0/
/// <root>/<packID>/current -> 1.1.0    심볼릭 링크 포인터
/// <root>/<packID>/.staging-<uuid>/    설치 중인 임시 디렉터리
/// ```
///
/// 버전 디렉터리를 불변으로 두고 포인터만 바꾸는 이유는 롤백 때문이다. 새 버전이
/// 이상하면 링크 하나만 되돌리면 되고, 그 사이 앱이 열어둔 파일 핸들은 여전히 유효하다.
public struct PackStore: Sendable {
    /// `ContentPacks` 디렉터리.
    public let root: URL

    public init(root: URL) { self.root = root }

    public static let currentPointerName = "current"
    static let stagingPrefix = ".staging-"

    public func packDirectory(_ packID: PackID) -> URL {
        root.appendingPathComponent(packID.rawValue, isDirectory: true)
    }

    public func versionDirectory(_ packID: PackID, version: String) -> URL {
        packDirectory(packID).appendingPathComponent(version, isDirectory: true)
    }

    public func currentPointer(_ packID: PackID) -> URL {
        packDirectory(packID).appendingPathComponent(PackStore.currentPointerName)
    }

    /// `current` 가 가리키는 버전 문자열. 포인터가 없으면 nil.
    public func currentVersion(_ packID: PackID) -> String? {
        let pointer = currentPointer(packID)
        guard
            let destination = try? FileManager.default.destinationOfSymbolicLink(
                atPath: pointer.path)
        else { return nil }
        // 포인터는 항상 형제 디렉터리 이름 한 조각이다. 그보다 복잡한 것이 들어 있으면
        // 신뢰하지 않는다 — 링크를 손으로 고친 흔적이다.
        let trimmed = destination.hasSuffix("/") ? String(destination.dropLast()) : destination
        guard !trimmed.isEmpty, !trimmed.contains("/") else { return nil }
        return trimmed
    }

    /// `current` 가 가리키는 실제 디렉터리. 대상이 없으면 nil.
    public func currentDirectory(_ packID: PackID) -> URL? {
        guard let version = currentVersion(packID) else { return nil }
        let url = versionDirectory(packID, version: version)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 설치된 버전 디렉터리 이름들. semver 오름차순.
    public func installedVersions(_ packID: PackID) -> [String] {
        let directory = packDirectory(packID)
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])) ?? []
        let names = contents.compactMap { url -> String? in
            let name = url.lastPathComponent
            if name.hasPrefix(PackStore.stagingPrefix) { return nil }
            if name == PackStore.currentPointerName { return nil }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { return nil }
            return name
        }
        return names.sorted { left, right in
            switch (try? SemanticVersion(parsing: left), try? SemanticVersion(parsing: right)) {
            case (let l?, let r?): l < r
            default: left < right
            }
        }
    }

    public func installedPackIDs() -> [PackID] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [])) ?? []
        return
            contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .map { PackID($0.lastPathComponent) }
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// 중단된 설치가 남긴 `.staging-*` 디렉터리를 지운다. 지운 개수를 돌려준다.
    ///
    /// 강제 종료된 설치의 잔여물은 **여기서만** 정리된다. 설치 경로 자체는 잔여물을
    /// 지우려 애쓰지 않는다 — 프로세스가 죽으면 정리 코드도 함께 죽기 때문이다.
    @discardableResult
    public func sweepStagingResidue(_ packID: PackID) -> Int {
        let directory = packDirectory(packID)
        let manager = FileManager.default
        let contents =
            (try? manager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [])) ?? []
        var removed = 0
        for url in contents where url.lastPathComponent.hasPrefix(PackStore.stagingPrefix) {
            if (try? manager.removeItem(at: url)) != nil { removed += 1 }
        }
        return removed
    }
}
