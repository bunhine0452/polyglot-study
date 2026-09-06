public import Foundation
internal import CryptoKit

/// 프로브 캐시 키.
///
/// 툴체인 감지는 후보마다 프로세스를 띄우므로 온보딩에서 수백 ms 를 먹는다. 캐시가
/// 필요하지만, **툴체인이 바뀌었는데 낡은 답을 주는 것**이 캐시가 없는 것보다 훨씬 나쁘다.
/// 그래서 키에 "바뀌면 답이 달라질 수 있는" 것을 전부 넣는다.
///
///   - 스키마 버전   판정 규칙 자체가 바뀌면 전부 무효
///   - 툴 id
///   - 해석된 절대경로
///   - `st_dev` + `st_ino` + `st_size` + `st_mtimespec`   같은 경로의 교체를 잡는다
///   - 수확된 PATH   순서만 바뀌어도 후보 집합이 달라진다
///   - OS 빌드      `/usr/bin` shim 은 OS 업데이트로 바뀐다
///   - `xcode-select -p`   Xcode ↔ CLT 전환
///   - 앱 버전      카탈로그·최소 버전이 앱과 함께 바뀐다
///
/// 여기에 24시간 TTL 을 더한다 — 키에 안 잡히는 변화(예: conda 환경 전환)에 대한 안전망.
public struct ToolchainProbeCacheKey: Hashable, Sendable {
    /// 판정 규칙이 바뀌면 올린다.
    public static let schemaVersion = 1

    public var toolID: String
    public var resolvedPath: String
    public var fileIdentity: FileIdentity?
    public var searchPath: [String]
    public var osBuild: String
    public var developerDirectory: String?
    public var appVersion: String

    public init(
        toolID: String,
        resolvedPath: String,
        fileIdentity: FileIdentity?,
        searchPath: [String],
        osBuild: String,
        developerDirectory: String?,
        appVersion: String
    ) {
        self.toolID = toolID
        self.resolvedPath = resolvedPath
        self.fileIdentity = fileIdentity
        self.searchPath = searchPath
        self.osBuild = osBuild
        self.developerDirectory = developerDirectory
        self.appVersion = appVersion
    }

    /// SHA-256 hex. 파일명·딕셔너리 키로 그대로 쓸 수 있는 형태.
    public var fingerprint: String {
        var material = "v\(Self.schemaVersion)\u{1F}\(toolID)\u{1F}\(resolvedPath)\u{1F}"
        material += (fileIdentity?.fingerprintFragment ?? "-") + "\u{1F}"
        material += searchPath.joined(separator: ":") + "\u{1F}"
        material += osBuild + "\u{1F}"
        material += (developerDirectory ?? "-") + "\u{1F}"
        material += appVersion
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// 현재 머신의 캐시 키 재료.
public struct ToolchainEnvironmentFingerprint: Sendable {
    public var searchPath: [String]
    public var osBuild: String
    public var developerDirectory: String?
    public var appVersion: String

    public init(searchPath: [String], osBuild: String, developerDirectory: String?, appVersion: String) {
        self.searchPath = searchPath
        self.osBuild = osBuild
        self.developerDirectory = developerDirectory
        self.appVersion = appVersion
    }

    /// `sw_vers -buildVersion` 과 같은 값을 프로세스 없이 얻는다.
    public static func currentOSBuild() -> String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else {
            return ProcessInfo.processInfo.operatingSystemVersionString
        }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 else {
            return ProcessInfo.processInfo.operatingSystemVersionString
        }
        return String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
    }

    public static func current(probe: ToolchainProbe, appVersion: String? = nil) -> ToolchainEnvironmentFingerprint {
        let version = appVersion
            ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "dev"
        return ToolchainEnvironmentFingerprint(
            searchPath: probe.searchPath,
            osBuild: currentOSBuild(),
            developerDirectory: probe.developerDirectory,
            appVersion: version
        )
    }

    public func key(toolID: String, resolvedPath: String, fileIdentity: FileIdentity?) -> ToolchainProbeCacheKey {
        ToolchainProbeCacheKey(
            toolID: toolID,
            resolvedPath: resolvedPath,
            fileIdentity: fileIdentity,
            searchPath: searchPath,
            osBuild: osBuild,
            developerDirectory: developerDirectory,
            appVersion: appVersion
        )
    }
}

/// 24시간 TTL 캐시. 값 자체는 후보 판정 하나다.
public actor ToolchainProbeCache {
    public struct Entry: Sendable, Hashable, Codable {
        public var fingerprint: String
        public var storedAt: Date
        /// `ToolCandidateResult.Verdict` 를 문자열 두 개로 납작하게 — 디스크 포맷을
        /// 열거형 케이스 이름에 묶지 않는다.
        public var verdictKind: String
        public var detail: String

        public init(fingerprint: String, storedAt: Date, verdictKind: String, detail: String) {
            self.fingerprint = fingerprint
            self.storedAt = storedAt
            self.verdictKind = verdictKind
            self.detail = detail
        }
    }

    public static let defaultTimeToLive: Duration = .seconds(24 * 60 * 60)

    private var entries: [String: Entry] = [:]
    private let timeToLive: Duration
    private let now: @Sendable () -> Date

    public init(
        timeToLive: Duration = ToolchainProbeCache.defaultTimeToLive,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.timeToLive = timeToLive
        self.now = now
    }

    public func entry(for key: ToolchainProbeCacheKey) -> Entry? {
        let fingerprint = key.fingerprint
        guard let entry = entries[fingerprint] else { return nil }
        guard !isExpired(entry) else {
            entries[fingerprint] = nil
            return nil
        }
        return entry
    }

    public func store(_ verdict: ToolCandidateResult.Verdict, for key: ToolchainProbeCacheKey) {
        let (kind, detail) = Self.flatten(verdict)
        let fingerprint = key.fingerprint
        entries[fingerprint] = Entry(
            fingerprint: fingerprint,
            storedAt: now(),
            verdictKind: kind,
            detail: detail
        )
    }

    public func verdict(for key: ToolchainProbeCacheKey) -> ToolCandidateResult.Verdict? {
        guard let entry = entry(for: key) else { return nil }
        return Self.inflate(kind: entry.verdictKind, detail: entry.detail)
    }

    /// 만료 항목을 걷어낸다. 저장 직전에 부르면 파일이 무한히 자라지 않는다.
    @discardableResult
    public func removeExpired() -> Int {
        let before = entries.count
        entries = entries.filter { !isExpired($0.value) }
        return before - entries.count
    }

    public func removeAll() {
        entries.removeAll()
    }

    public var count: Int { entries.count }

    private func isExpired(_ entry: Entry) -> Bool {
        let age = now().timeIntervalSince(entry.storedAt)
        let limit = Double(timeToLive.components.seconds)
        return age < 0 || age > limit
    }

    // MARK: - 디스크

    public func snapshot() -> [Entry] { Array(entries.values) }

    public func load(_ snapshot: [Entry]) {
        for entry in snapshot where !isExpired(entry) {
            entries[entry.fingerprint] = entry
        }
    }

    public func save(to url: URL) throws {
        removeExpired()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Array(entries.values).sorted { $0.fingerprint < $1.fingerprint })
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        load(try decoder.decode([Entry].self, from: data))
    }

    static func flatten(_ verdict: ToolCandidateResult.Verdict) -> (String, String) {
        switch verdict {
        case let .ready(version): return ("ready", version.raw)
        case let .belowMinimum(version): return ("belowMinimum", version.raw)
        case let .stub(reason): return ("stub", reason)
        case let .failed(reason): return ("failed", reason)
        case .skippedWithoutDeveloperDirectory: return ("skipped", "")
        }
    }

    static func inflate(kind: String, detail: String) -> ToolCandidateResult.Verdict? {
        switch kind {
        case "ready":
            guard let version = ToolVersion(detail) else { return nil }
            return .ready(version: version)
        case "belowMinimum":
            guard let version = ToolVersion(detail) else { return nil }
            return .belowMinimum(version: version)
        case "stub": return .stub(reason: detail)
        case "failed": return .failed(reason: detail)
        case "skipped": return .skippedWithoutDeveloperDirectory
        default: return nil
        }
    }
}
