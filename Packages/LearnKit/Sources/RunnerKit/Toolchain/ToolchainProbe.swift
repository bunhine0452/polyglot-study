public import LanguageKit
public import LearnCore
public import Foundation
internal import Darwin

/// 파일 신원 — 캐시 키와 후보 중복 제거의 근거.
public struct FileIdentity: Hashable, Sendable {
    public var device: UInt64
    public var inode: UInt64
    public var size: UInt64
    public var modifiedSeconds: Int64
    public var modifiedNanoseconds: Int64

    public init(device: UInt64, inode: UInt64, size: UInt64, modifiedSeconds: Int64, modifiedNanoseconds: Int64) {
        self.device = device
        self.inode = inode
        self.size = size
        self.modifiedSeconds = modifiedSeconds
        self.modifiedNanoseconds = modifiedNanoseconds
    }

    /// `st_dev` + `st_ino` + `st_size` + `st_mtimespec`.
    /// 같은 경로에 다른 바이너리가 앉으면 이 넷 중 하나는 반드시 바뀐다.
    public static func of(path: String) -> FileIdentity? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        return FileIdentity(
            device: UInt64(bitPattern: Int64(info.st_dev)),
            inode: info.st_ino,
            size: UInt64(bitPattern: Int64(info.st_size)),
            modifiedSeconds: Int64(info.st_mtimespec.tv_sec),
            modifiedNanoseconds: Int64(info.st_mtimespec.tv_nsec)
        )
    }

    var fingerprintFragment: String {
        "\(device):\(inode):\(size):\(modifiedSeconds).\(modifiedNanoseconds)"
    }
}

/// 발견된 후보 하나.
public struct ToolCandidate: Sendable, Hashable {
    public var path: String
    public var resolvedPath: String
    public var identity: FileIdentity?
    public var origin: ToolCandidateOrigin

    public init(path: String, resolvedPath: String, identity: FileIdentity?, origin: ToolCandidateOrigin) {
        self.path = path
        self.resolvedPath = resolvedPath
        self.identity = identity
        self.origin = origin
    }
}

/// 툴 하나에 대한 감지 결과 전체.
public struct ToolProbeReport: Sendable, Hashable {
    public var toolID: String
    public var language: LanguageID
    public var availability: ModuleAvailability
    /// 실행해 본 모든 후보. 사용자가 "왜 이게 골라졌나"를 볼 수 있어야 한다.
    public var candidates: [ToolCandidateResult]

    public init(toolID: String, language: LanguageID, availability: ModuleAvailability, candidates: [ToolCandidateResult]) {
        self.toolID = toolID
        self.language = language
        self.availability = availability
        self.candidates = candidates
    }
}

/// `xcode-select -p` 게이트.
///
/// 활성 개발자 디렉터리가 없을 때 `/usr/bin/swiftc` 같은 shim 을 **실행하면**
/// macOS 가 "Command Line Tools 를 설치하시겠습니까?" 다이얼로그를 띄운다.
/// 학습 앱이 툴체인 스캔 도중 시스템 모달을 띄우는 것은 사고이므로, 실행 전에 막는다.
public enum DeveloperDirectory {
    public static func active(timeout: Duration = .seconds(2)) async -> String? {
        let result = await BoundedCommand.run(
            executable: "/usr/bin/xcode-select",
            arguments: ["-p"],
            timeout: timeout
        )
        guard result.succeeded else { return nil }
        let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return path
    }
}

/// PATH 와 관례 경로의 **모든** 후보를 열거해 각각 `--version` 을 실제로 실행하고
/// 버전 정책으로 하나를 고른다.
public struct ToolchainProbe: Sendable {
    public var searchPath: [String]
    /// `xcode-select -p`. `nil` 이면 개발자 도구 shim 을 실행하지 않는다.
    public var developerDirectory: String?
    /// `--version` 한 건의 상한.
    public var versionTimeout: Duration
    public var homeDirectory: String

    public init(
        searchPath: [String],
        developerDirectory: String?,
        versionTimeout: Duration = .seconds(2),
        homeDirectory: String = NSHomeDirectory()
    ) {
        self.searchPath = searchPath
        self.developerDirectory = developerDirectory
        self.versionTimeout = versionTimeout
        self.homeDirectory = homeDirectory
    }

    /// 로그인 PATH 수확 + `xcode-select` 게이트까지 실제로 수행한 표준 구성.
    public static func standard(
        harvest: LoginPathHarvest? = nil,
        versionTimeout: Duration = .seconds(2)
    ) async -> ToolchainProbe {
        let harvested: LoginPathHarvest
        if let harvest {
            harvested = harvest
        } else {
            harvested = await LoginPathHarvester.harvest()
        }
        let developer = await DeveloperDirectory.active()
        return ToolchainProbe(
            searchPath: harvested.directories,
            developerDirectory: developer,
            versionTimeout: versionTimeout
        )
    }

    // MARK: - 후보 열거

    public func candidates(for spec: ToolSpec) async -> [ToolCandidate] {
        var directories: [(String, ToolCandidateOrigin)] = []
        for (index, directory) in searchPath.enumerated() {
            directories.append((directory, .searchPath(index: index)))
        }
        for directory in spec.additionalDirectories {
            directories.append((expandTilde(directory), .specDirectory))
        }
        for pattern in spec.additionalDirectoryPatterns {
            for directory in Self.expand(pattern: expandTilde(pattern)) {
                directories.append((directory, .specDirectory))
            }
        }

        var found: [ToolCandidate] = []
        var seenIdentities = Set<FileIdentity>()
        var seenPaths = Set<String>()
        let fileManager = FileManager.default

        func consider(path: String, origin: ToolCandidateOrigin) {
            guard fileManager.isExecutableFile(atPath: path) else { return }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return }
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            let identity = FileIdentity.of(path: resolved)
            if let identity {
                guard !seenIdentities.contains(identity) else { return }
                seenIdentities.insert(identity)
            } else {
                guard !seenPaths.contains(resolved) else { return }
            }
            seenPaths.insert(resolved)
            found.append(ToolCandidate(path: path, resolvedPath: resolved, identity: identity, origin: origin))
        }

        for (directory, origin) in directories {
            for name in spec.executableNames {
                consider(path: "\(directory)/\(name)", origin: origin)
            }
        }

        // `xcrun --find` 는 개발자 디렉터리가 있을 때만. 없으면 xcrun 자체가 다이얼로그를 띄운다.
        if spec.searchViaXcrun, developerDirectory != nil {
            for name in spec.executableNames {
                let result = await BoundedCommand.run(
                    executable: "/usr/bin/xcrun",
                    arguments: ["--find", name],
                    timeout: versionTimeout
                )
                guard result.succeeded else { continue }
                let path = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty else { continue }
                consider(path: path, origin: .xcrun)
            }
        }

        return found
    }

    // MARK: - 감지

    public func probe(_ spec: ToolSpec) async -> ToolProbeReport {
        let candidates = await candidates(for: spec)
        var results: [ToolCandidateResult] = []
        for candidate in candidates {
            results.append(await evaluate(candidate: candidate, spec: spec))
        }
        return ToolProbeReport(
            toolID: spec.id,
            language: spec.language,
            availability: ToolchainVerdict.select(spec: spec, candidates: results),
            candidates: results
        )
    }

    public func probeAll(_ specs: [ToolSpec] = ToolchainCatalog.all) async -> [ToolProbeReport] {
        var reports: [ToolProbeReport] = []
        for spec in specs {
            reports.append(await probe(spec))
        }
        return reports
    }

    /// 캐시를 끼고 감지한다.
    ///
    /// 캐싱하는 것은 **`--version` 실행 결과뿐**이다. 후보 열거(디렉터리 스캔 + stat)는
    /// 매번 다시 한다 — 그걸 캐싱하면 방금 `brew install` 한 툴을 24시간 못 본다.
    /// 반대로 실행은 후보 하나당 프로세스 하나라 비싸고, 파일 신원이 그대로면 결과도 같다.
    public func probe(
        _ spec: ToolSpec,
        cache: ToolchainProbeCache,
        fingerprint: ToolchainEnvironmentFingerprint
    ) async -> ToolProbeReport {
        let candidates = await candidates(for: spec)
        var results: [ToolCandidateResult] = []
        for candidate in candidates {
            let key = fingerprint.key(
                toolID: spec.id,
                resolvedPath: candidate.resolvedPath,
                fileIdentity: candidate.identity
            )
            if let cached = await cache.verdict(for: key) {
                results.append(ToolCandidateResult(
                    path: candidate.path,
                    resolvedPath: candidate.resolvedPath,
                    verdict: cached,
                    origin: candidate.origin
                ))
                continue
            }
            let result = await evaluate(candidate: candidate, spec: spec)
            await cache.store(result.verdict, for: key)
            results.append(result)
        }
        return ToolProbeReport(
            toolID: spec.id,
            language: spec.language,
            availability: ToolchainVerdict.select(spec: spec, candidates: results),
            candidates: results
        )
    }

    public func probeAll(
        _ specs: [ToolSpec] = ToolchainCatalog.all,
        cache: ToolchainProbeCache,
        fingerprint: ToolchainEnvironmentFingerprint
    ) async -> [ToolProbeReport] {
        var reports: [ToolProbeReport] = []
        for spec in specs {
            reports.append(await probe(spec, cache: cache, fingerprint: fingerprint))
        }
        return reports
    }

    func evaluate(candidate: ToolCandidate, spec: ToolSpec) async -> ToolCandidateResult {
        if shouldSkipForDeveloperDirectory(candidate: candidate, spec: spec) {
            return ToolCandidateResult(
                path: candidate.path,
                resolvedPath: candidate.resolvedPath,
                verdict: .skippedWithoutDeveloperDirectory,
                origin: candidate.origin
            )
        }
        let result = await BoundedCommand.run(
            executable: candidate.path,
            arguments: spec.versionArguments,
            timeout: versionTimeout
        )
        return ToolCandidateResult(
            path: candidate.path,
            resolvedPath: candidate.resolvedPath,
            verdict: ToolchainVerdict.classify(spec: spec, result: result),
            origin: candidate.origin
        )
    }

    /// CLT 다이얼로그 회피 게이트. 개발자 디렉터리가 없을 때 `/usr/bin` 아래의
    /// 개발도구 shim 만 건드리지 않는다 — conda 의 python3 까지 막을 이유는 없다.
    func shouldSkipForDeveloperDirectory(candidate: ToolCandidate, spec: ToolSpec) -> Bool {
        guard spec.needsDeveloperDirectory, developerDirectory == nil else { return false }
        return candidate.path.hasPrefix("/usr/bin/") || candidate.resolvedPath.hasPrefix("/usr/bin/")
    }

    func expandTilde(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        if path == "~" { return homeDirectory }
        guard path.hasPrefix("~/") else { return path }
        return homeDirectory + String(path.dropFirst(1))
    }

    /// `*` 하나만 지원하는 얕은 확장. glob(3) 을 끌어올 만한 요구가 아직 없다.
    static func expand(pattern: String) -> [String] {
        guard let star = pattern.firstIndex(of: "*") else { return [pattern] }
        let prefix = String(pattern[pattern.startIndex..<star])
        let suffix = String(pattern[pattern.index(after: star)...])
        guard let slash = prefix.lastIndex(of: "/") else { return [] }
        let root = String(prefix[prefix.startIndex..<slash])
        let namePrefix = String(prefix[prefix.index(after: slash)...])
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        return names.sorted()
            .filter { $0.hasPrefix(namePrefix) && !$0.hasPrefix(".") }
            .map { "\(root)/\($0)\(suffix)" }
    }
}
