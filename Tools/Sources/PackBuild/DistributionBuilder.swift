public import ContentKit
public import Foundation

internal import LearnCore

/// 배포 팩 하나를 구운 결과.
public struct DistributionResult: Sendable {
    /// 배포 팩의 매니페스트 (`distribution: true`, `files` 재계산됨).
    public let manifest: PackManifest
    /// 벗겨진 파일들의 소스 경로. 사전순.
    public let strippedPaths: [String]
    /// 아카이브 안의 최상위 디렉터리 이름.
    public let rootName: String
    /// 구워진 tar 바이트 수.
    public let archiveBytes: Int
    /// 서명이 함께 구워졌는가.
    public let signed: Bool
}

public enum DistributionError: Error, CustomStringConvertible {
    /// 이미 배포 팩이다. 두 번 굽는 것은 언제나 실수다.
    case alreadyDistribution(packID: String)
    case source(PackInstallError)
    case pack(ContentPackError)
    case signature(PackSignatureError)
    case archive(String)
    case io(operation: String, path: String, underlying: String)
    /// 배포 팩에서 벗겨야 할 디렉터리가 소스에 아예 없다.
    case nothingToStrip(directory: String)

    public var description: String {
        switch self {
        case .alreadyDistribution(let packID):
            "\(packID) 는 이미 배포 팩이다 — solutions 가 이미 벗겨져 있어 다시 구울 수 없다"
        case .source(let error): "\(error)"
        case .pack(let error): "\(error)"
        case .signature(let error): "\(error)"
        case .archive(let detail): "아카이브를 만들 수 없다: \(detail)"
        case .io(let operation, let path, let underlying):
            "\(operation) 실패 — \(path): \(underlying)"
        case .nothingToStrip(let directory):
            "소스 팩에 \(directory)/ 가 없다 — 배포 팩을 이미 소스로 쓰고 있는 것은 아닌가"
        }
    }
}

/// `packtool build` 의 알맹이 — solutions 를 벗기고, 해시를 다시 세고, 결정적으로 굽는다.
///
/// ## 순서가 계약이다
///
/// 1. 소스를 스테이징에 복사한다. `solutions/` 만 빠진다.
/// 2. 매니페스트에 `distribution: true` 를 박고 `files` 를 **스테이징에서** 다시 센다.
///    소스에서 세고 항목만 빼면 "매니페스트가 말하는 것" 과 "디스크에 있는 것" 이
///    갈릴 여지가 생긴다. 세는 대상은 언제나 굽힐 그 디렉터리다.
/// 3. (선택) 그 매니페스트 바이트에 서명한다. 서명은 2 뒤여야 한다 — 서명 대상이
///    확정되기 전에 서명할 수는 없다.
/// 4. tar 로 굽는다. 시각은 `generatedAt`, 소유자는 0, 순서는 사전순.
///
/// 서명을 뺀 결과는 두 번 구워도 바이트가 같다. 서명 파일은 예외다 — CryptoKit 의
/// Ed25519 는 논스에 난수를 섞어서 같은 입력에 두 번 서명하면 다른 바이트가 나온다
/// (실측, 둘 다 유효). 그래서 재현성 단언의 대상은 `manifest.json.sig` 를 뺀 트리다.
public enum DistributionBuilder {
    /// 아카이브 안의 최상위 디렉터리. `tar xf` 가 현재 위치를 어지럽히지 않게 한다.
    public static func rootName(for manifest: PackManifest) -> String {
        "\(manifest.packID.rawValue)-\(manifest.version)"
    }

    /// 소스 팩을 배포 팩으로 굽는다.
    ///
    /// - Parameters:
    ///   - source: 소스 팩 디렉터리 (`solutions/` 가 있는 쪽).
    ///   - staging: 배포 트리를 펼칠 자리. 이미 있으면 **지우고** 다시 만든다.
    ///   - archiveURL: 구운 tar 를 쓸 자리.
    ///   - signingKeyBase64: 주면 `manifest.json.sig` 를 함께 굽는다.
    public static func build(
        source: URL,
        staging: URL,
        archiveURL: URL,
        signingKeyBase64: String? = nil
    ) throws(DistributionError) -> DistributionResult {
        let pack: ContentPack
        do {
            pack = try ContentPack(directory: source)
        } catch {
            throw .pack(error)
        }
        guard !pack.manifest.isDistribution else {
            throw .alreadyDistribution(packID: pack.manifest.packID.rawValue)
        }

        // 복사 전에 소스를 훑는다 — 심볼릭 링크는 복사하는 순간 이미 늦는다
        // (`copyItem` 이 링크를 따라가 내용을 가져온다).
        let scan: PackSourceScan
        do {
            scan = try PackSourceScan.scan(directory: source)
        } catch {
            throw .source(error)
        }

        let stripped = scan.files.keys
            .filter { isStripped($0) }
            .sorted()
        guard !stripped.isEmpty else {
            throw .nothingToStrip(directory: PackLayout.strippedInDistribution.joined(separator: ", "))
        }

        try reset(directory: staging)
        for path in scan.files.keys.sorted() where !isStripped(path) {
            try copy(
                from: source.appendingPathComponent(path),
                to: staging.appendingPathComponent(path))
        }

        var manifest = pack.manifest
        manifest.distribution = true
        do {
            manifest = try PackManifestBuilder.rebuildingFiles(of: manifest, in: staging)
            try PackManifestBuilder.write(manifest, to: staging)
        } catch {
            throw .io(operation: "매니페스트 재계산", path: staging.path, underlying: "\(error)")
        }

        let manifestBytes: Data
        do {
            manifestBytes = try PackSignatureVerification.canonicalManifestBytes(in: staging)
        } catch {
            throw .io(operation: "매니페스트 읽기", path: staging.path, underlying: "\(error)")
        }

        var signed = false
        if let signingKeyBase64 {
            let signature: PackSignature
            do {
                signature = try PackSigning.sign(
                    manifestBytes: manifestBytes, privateKeyBase64: signingKeyBase64)
            } catch {
                throw .signature(error)
            }
            let url = PackSignatureVerification.signatureURL(in: staging)
            do {
                try Data(signature.canonicalText().utf8).write(to: url, options: .atomic)
            } catch {
                throw .io(operation: "서명 쓰기", path: url.path, underlying: "\(error)")
            }
            signed = true
        }

        let archive = try archiveBytes(of: staging, manifest: manifest, signed: signed)
        do {
            try FileManager.default.createDirectory(
                at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try archive.write(to: archiveURL, options: .atomic)
        } catch {
            throw .io(operation: "아카이브 쓰기", path: archiveURL.path, underlying: "\(error)")
        }

        return DistributionResult(
            manifest: manifest,
            strippedPaths: stripped,
            rootName: rootName(for: manifest),
            archiveBytes: archive.count,
            signed: signed)
    }

    /// 배포 트리 하나를 tar 바이트로. `build` 가 마지막에 부르는 것과 같은 함수다.
    public static func archiveBytes(
        of directory: URL, manifest: PackManifest, signed: Bool
    ) throws(DistributionError) -> Data {
        let root = rootName(for: manifest)
        var entries: [TarWriter.Entry] = [.directory(path: root + "/")]
        var directories: Set<String> = []

        var relativePaths = manifest.files.map(\.path)
        relativePaths.append(PackLayout.manifestFileName)
        if signed { relativePaths.append(PackLayout.signatureFileName) }

        for path in relativePaths.sorted() {
            if let slash = path.lastIndex(of: "/") {
                directories.insert(String(path[path.startIndex..<slash]))
            }
            let url = directory.appendingPathComponent(path)
            guard let data = FileManager.default.contents(atPath: url.path) else {
                throw .io(operation: "아카이브에 담을 파일 읽기", path: url.path, underlying: "없음")
            }
            entries.append(.file(path: "\(root)/\(path)", data: data))
        }
        for name in directories {
            entries.append(.directory(path: "\(root)/\(name)/"))
        }

        do {
            return try TarWriter.archive(
                entries, modificationTime: epochSeconds(fromTimestamp: manifest.generatedAt))
        } catch {
            throw .archive("\(error)")
        }
    }

    // MARK: - 내부

    private static func isStripped(_ path: String) -> Bool {
        guard let slash = path.firstIndex(of: "/") else { return false }
        return PackLayout.strippedInDistribution.contains(String(path[path.startIndex..<slash]))
    }

    private static func reset(directory: URL) throws(DistributionError) {
        let manager = FileManager.default
        if manager.fileExists(atPath: directory.path) {
            do {
                try manager.removeItem(at: directory)
            } catch {
                throw .io(operation: "스테이징 비우기", path: directory.path, underlying: "\(error)")
            }
        }
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw .io(operation: "스테이징 만들기", path: directory.path, underlying: "\(error)")
        }
    }

    private static func copy(from source: URL, to destination: URL) throws(DistributionError) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.copyItem(at: source, to: destination)
        } catch {
            throw .io(operation: "복사", path: source.path, underlying: "\(error)")
        }
    }

    /// `2026-09-06T00:00:00Z` → epoch 초.
    ///
    /// 파싱에 실패하면 0 이다. 매니페스트 검증이 이미 형식을 본 뒤에 오는 값이라
    /// 여기서 던질 이유가 없고, 실패해도 **결정적**이면 아카이브의 재현성은 지켜진다.
    static func epochSeconds(fromTimestamp text: String) -> UInt64 {
        let digits = text.filter(\.isNumber)
        guard digits.count == 14 else { return 0 }
        func part(_ start: Int, _ length: Int) -> Int {
            let from = digits.index(digits.startIndex, offsetBy: start)
            let to = digits.index(from, offsetBy: length)
            return Int(digits[from..<to]) ?? 0
        }
        var components = DateComponents()
        components.year = part(0, 4)
        components.month = part(4, 2)
        components.day = part(6, 2)
        components.hour = part(8, 2)
        components.minute = part(10, 2)
        components.second = part(12, 2)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let date = calendar.date(from: components), date.timeIntervalSince1970 >= 0 else {
            return 0
        }
        return UInt64(date.timeIntervalSince1970)
    }
}
