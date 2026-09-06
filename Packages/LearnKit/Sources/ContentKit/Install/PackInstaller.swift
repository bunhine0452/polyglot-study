public import LearnCore

public import Foundation
internal import Darwin

/// 설치 단계. 테스트가 "이 지점에서 프로세스가 죽었다"를 흉내낼 때 쓴다.
public enum InstallPhase: String, Hashable, Sendable, CaseIterable {
    /// 매니페스트 디코딩·검증과 경로 검사가 끝났다. 아직 디스크에 아무것도 쓰지 않았다.
    case validated
    /// 스테이징 디렉터리에 전 파일을 풀었다.
    case staged
    /// 스테이징 안의 전 파일 sha256 을 대조했다.
    case verified
    /// 스테이징을 버전 디렉터리로 옮겼다. `current` 는 **아직 이전 버전**을 가리킨다.
    case versionPlaced
    /// `current` 를 새 버전으로 원자적으로 옮겼다.
    case pointerMoved
}

public struct InstalledPack: Hashable, Sendable {
    public let packID: PackID
    public let version: String
    public let directory: URL
    public let manifest: PackManifest
}

public enum PackInstallError: Error, Hashable, Sendable, CustomStringConvertible {
    case sourceNotADirectory(String)
    case manifestMissing(String)
    case manifestUnreadable(String)
    case manifestInvalid(PackManifestError)
    case incompatible(PackCompatibilityError)
    /// 경로가 팩 밖을 가리킨다.
    case unsafeEntry(path: String, reason: PackPathError)
    /// 심볼릭 링크는 팩에 들어올 수 없다.
    case symbolicLink(path: String)
    case fileOutsideLayout(path: String)
    /// 매니페스트에 있는 파일이 디스크에 없다.
    case fileMissing(path: String)
    /// 디스크에 있는 파일이 매니페스트에 없다.
    case unregisteredFileOnDisk(path: String)
    case checksumMismatch(path: String, expected: String, actual: String)
    case sizeMismatch(path: String, expected: Int, actual: Int)
    case ioFailure(operation: String, path: String, code: Int32)
    /// 테스트가 주입한 강제 종료 지점.
    case interrupted(InstallPhase)
    case versionAlreadyInstalled(packID: PackID, version: String)
    case versionNotInstalled(packID: PackID, version: String)
    /// `current` 가 가리키는 버전은 지울 수 없다.
    case versionInUse(packID: PackID, version: String)

    public var description: String {
        switch self {
        case .sourceNotADirectory(let path): "팩 소스가 디렉터리가 아니다: \(path)"
        case .manifestMissing(let path): "\(PackLayout.manifestFileName) 이 없다: \(path)"
        case .manifestUnreadable(let detail): "매니페스트를 읽을 수 없다: \(detail)"
        case .manifestInvalid(let reason): "매니페스트가 유효하지 않다 — \(reason)"
        case .incompatible(let reason): "\(reason.userMessage) (\(reason))"
        case .unsafeEntry(let path, let reason): "안전하지 않은 경로 \(path): \(reason)"
        case .symbolicLink(let path): "팩에 심볼릭 링크가 들어 있다: \(path)"
        case .fileOutsideLayout(let path): "팩 레이아웃 밖의 파일: \(path)"
        case .fileMissing(let path): "매니페스트에 등록된 \(path) 가 디스크에 없다"
        case .unregisteredFileOnDisk(let path): "매니페스트에 없는 파일이 팩에 있다: \(path)"
        case .checksumMismatch(let path, let expected, let actual):
            "\(path) 의 sha256 이 다르다 — 기대 \(expected), 실제 \(actual)"
        case .sizeMismatch(let path, let expected, let actual):
            "\(path) 의 크기가 다르다 — 기대 \(expected)B, 실제 \(actual)B"
        case .ioFailure(let operation, let path, let code):
            "\(operation) 실패 (errno \(code)): \(path)"
        case .interrupted(let phase): "설치가 \(phase.rawValue) 단계에서 중단됐다"
        case .versionAlreadyInstalled(let packID, let version):
            "\(packID.rawValue) \(version) 은 이미 설치돼 있다"
        case .versionNotInstalled(let packID, let version):
            "\(packID.rawValue) \(version) 은 설치돼 있지 않다"
        case .versionInUse(let packID, let version):
            "\(packID.rawValue) \(version) 은 current 가 가리키고 있어 지울 수 없다"
        }
    }
}

/// 팩을 원자적으로 설치한다.
///
/// 계약 하나: **어느 시점에 프로세스가 죽어도 `current` 는 유효한 팩을 가리킨다.**
/// 그래서 순서가 이렇다 — 검증 → 스테이징 → 해시 대조 → 버전 디렉터리로 rename →
/// `current` 를 rename 으로 교체. 앞의 네 단계 중 어디서 죽어도 `current` 는 건드려지지
/// 않았고, 마지막 rename 은 커널이 원자적으로 처리한다.
public struct PackInstaller: Sendable {
    public let store: PackStore
    /// 이 단계 **직후** 강제 종료를 흉내낸다. 정리 코드도 함께 죽은 것처럼 스테이징을
    /// 남긴다. 프로덕션 경로에서는 항상 nil 이다.
    let crashAfter: InstallPhase?

    public init(store: PackStore) {
        self.store = store
        self.crashAfter = nil
    }

    init(store: PackStore, crashAfter: InstallPhase?) {
        self.store = store
        self.crashAfter = crashAfter
    }

    /// 팩 디렉터리를 스토어에 설치하고 `current` 를 새 버전으로 옮긴다.
    ///
    /// - Parameters:
    ///   - source: `manifest.json` 이 들어 있는 팩 디렉터리.
    ///   - appVersion: 주면 `schemaVersion`·`minAppVersion` 게이트를 통과해야 설치된다.
    ///   - activate: false 면 버전 디렉터리만 놓고 `current` 는 그대로 둔다.
    @discardableResult
    public func install(
        from source: URL,
        appVersion: SemanticVersion? = nil,
        activate: Bool = true
    ) throws(PackInstallError) -> InstalledPack {
        // ── 1. 검증. 디스크에는 아직 아무것도 쓰지 않는다.
        //
        // 경로 검사를 매니페스트 검증보다 **먼저** 둔다. 둘 다 같은 결함을 잡지만,
        // 경로 문제는 경로 에러로 보고돼야 로그에서 공격과 실수를 구별할 수 있다.
        let manifest = try readManifest(at: source)
        try PackSourceScan.validateDeclaredPaths(manifest)
        do {
            try manifest.validate()
        } catch {
            throw .manifestInvalid(error)
        }
        if let appVersion {
            do {
                try manifest.checkCompatibility(appVersion: appVersion)
            } catch {
                throw .incompatible(error)
            }
        }
        let scan = try PackSourceScan.scan(directory: source)
        try crossCheck(manifest: manifest, against: scan)
        try crash(.validated)

        let packID = manifest.packID
        let version = manifest.version
        let versionDirectory = store.versionDirectory(packID, version: version)
        if FileManager.default.fileExists(atPath: versionDirectory.path) {
            throw .versionAlreadyInstalled(packID: packID, version: version)
        }

        // 중단된 이전 설치의 잔여물은 새 설치가 시작될 때 정리한다.
        store.sweepStagingResidue(packID)

        // ── 2. 스테이징.
        let staging = store.packDirectory(packID)
            .appendingPathComponent(PackStore.stagingPrefix + UUID().uuidString, isDirectory: true)
        var stagingLive = true
        defer {
            // 강제 종료를 흉내내는 중이면 정리하지 않는다 — 실제 SIGKILL 에서는
            // 이 defer 자체가 돌지 않기 때문이다.
            if stagingLive && crashAfter == nil {
                try? FileManager.default.removeItem(at: staging)
            }
        }
        try makeDirectory(staging)
        try copy(manifest: manifest, from: source, into: staging)
        try crash(.staged)

        // ── 3. 스테이징 안에서 해시 대조. 복사가 끝난 **실제 바이트**를 본다.
        try verifyChecksums(manifest: manifest, in: staging)
        try crash(.verified)

        // ── 4. 버전 디렉터리로 원자적 이동.
        try makeDirectory(store.packDirectory(packID))
        try atomicRename(from: staging, to: versionDirectory)
        stagingLive = false
        try crash(.versionPlaced)

        // ── 5. current 포인터 교체. 여기까지 와야 새 버전이 보인다.
        if activate {
            try repointCurrent(packID: packID, to: version)
        }
        try crash(.pointerMoved)

        return InstalledPack(
            packID: packID, version: version, directory: versionDirectory, manifest: manifest)
    }

    /// `current` 를 이미 설치된 다른 버전으로 옮긴다. 롤백.
    public func activate(packID: PackID, version: String) throws(PackInstallError) {
        let directory = store.versionDirectory(packID, version: version)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw .versionNotInstalled(packID: packID, version: version)
        }
        try repointCurrent(packID: packID, to: version)
    }

    /// 버전 디렉터리 하나를 지운다. `current` 가 가리키는 버전은 거부한다.
    public func uninstall(packID: PackID, version: String) throws(PackInstallError) {
        let directory = store.versionDirectory(packID, version: version)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw .versionNotInstalled(packID: packID, version: version)
        }
        if store.currentVersion(packID) == version {
            throw .versionInUse(packID: packID, version: version)
        }
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            throw .ioFailure(operation: "removeItem", path: directory.path, code: 0)
        }
    }

    // MARK: - 단계별 구현

    private func readManifest(at source: URL) throws(PackInstallError) -> PackManifest {
        let url = source.appendingPathComponent(PackLayout.manifestFileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw .manifestMissing(source.path)
        }
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw .manifestUnreadable(url.path)
        }
        do {
            return try CanonicalJSON.decode(PackManifest.self, from: data)
        } catch {
            throw .manifestUnreadable("\(url.path): \(error)")
        }
    }

    /// 매니페스트와 디스크가 **양방향으로** 일치하는지. 한쪽만 보면 등록되지 않은
    /// 파일이 팩에 실려 들어온다.
    private func crossCheck(manifest: PackManifest, against scan: PackSourceScan)
        throws(PackInstallError)
    {
        let declared = Set(manifest.files.map(\.path))
        for path in declared where scan.files[path] == nil {
            throw .fileMissing(path: path)
        }
        for path in scan.files.keys.sorted() where !declared.contains(path) {
            throw .unregisteredFileOnDisk(path: path)
        }
    }

    private func copy(manifest: PackManifest, from source: URL, into staging: URL)
        throws(PackInstallError)
    {
        let manager = FileManager.default
        // 매니페스트 자신은 `files` 에 없으므로 따로 옮긴다.
        try copyFile(
            from: source.appendingPathComponent(PackLayout.manifestFileName),
            to: staging.appendingPathComponent(PackLayout.manifestFileName))

        for entry in manifest.files {
            let destination = staging.appendingPathComponent(entry.path)
            let parent = destination.deletingLastPathComponent()
            if !manager.fileExists(atPath: parent.path) { try makeDirectory(parent) }
            try copyFile(from: source.appendingPathComponent(entry.path), to: destination)
        }
    }

    private func verifyChecksums(manifest: PackManifest, in directory: URL)
        throws(PackInstallError)
    {
        for entry in manifest.files {
            let url = directory.appendingPathComponent(entry.path)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            else {
                throw .fileMissing(path: entry.path)
            }
            let actualSize = (attributes[.size] as? Int) ?? -1
            guard actualSize == entry.bytes else {
                throw .sizeMismatch(path: entry.path, expected: entry.bytes, actual: actualSize)
            }
            guard let digest = try? FileDigest.sha256(ofFileAt: url) else {
                throw .ioFailure(operation: "sha256", path: entry.path, code: 0)
            }
            guard digest == entry.sha256 else {
                throw .checksumMismatch(
                    path: entry.path, expected: entry.sha256, actual: digest)
            }
        }
    }

    /// `current` 를 원자적으로 옮긴다.
    ///
    /// `FileManager` 에는 "심볼릭 링크를 원자적으로 교체"가 없다. 지우고 다시 만들면
    /// 그 사이에 `current` 가 **없는** 순간이 생기고, 하필 그때 죽으면 팩이 통째로
    /// 사라진 것처럼 보인다. 그래서 임시 이름으로 링크를 만들고 `rename(2)` 으로
    /// 덮는다 — 커널이 원자성을 보장하는 유일한 방법이다.
    private func repointCurrent(packID: PackID, to version: String) throws(PackInstallError) {
        let pointer = store.currentPointer(packID)
        let temporary = store.packDirectory(packID)
            .appendingPathComponent(".current-\(UUID().uuidString)")

        if symlink(version, temporary.path) != 0 {
            throw .ioFailure(operation: "symlink", path: temporary.path, code: errno)
        }
        if rename(temporary.path, pointer.path) != 0 {
            let code = errno
            unlink(temporary.path)
            throw .ioFailure(operation: "rename", path: pointer.path, code: code)
        }
    }

    private func atomicRename(from source: URL, to destination: URL) throws(PackInstallError) {
        if rename(source.path, destination.path) != 0 {
            throw .ioFailure(operation: "rename", path: destination.path, code: errno)
        }
    }

    private func makeDirectory(_ url: URL) throws(PackInstallError) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw .ioFailure(operation: "createDirectory", path: url.path, code: 0)
        }
    }

    private func copyFile(from source: URL, to destination: URL) throws(PackInstallError) {
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            throw .ioFailure(operation: "copyItem", path: source.path, code: 0)
        }
    }

    private func crash(_ phase: InstallPhase) throws(PackInstallError) {
        if crashAfter == phase { throw .interrupted(phase) }
    }
}
