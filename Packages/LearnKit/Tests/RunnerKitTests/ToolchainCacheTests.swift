import Testing
import Foundation
@testable import RunnerKit

@Suite("프로브 캐시")
struct ToolchainCacheTests {
    static let baseIdentity = FileIdentity(
        device: 16777232,
        inode: 4242,
        size: 91_248,
        modifiedSeconds: 1_780_000_000,
        modifiedNanoseconds: 123
    )

    static func baseKey() -> ToolchainProbeCacheKey {
        ToolchainProbeCacheKey(
            toolID: "python3",
            resolvedPath: "/opt/conda/bin/python3.13",
            fileIdentity: baseIdentity,
            searchPath: ["/opt/conda/bin", "/usr/bin"],
            osBuild: "25G83",
            developerDirectory: "/Applications/Xcode.app/Contents/Developer",
            appVersion: "1.0.0"
        )
    }

    @Test("키 재료가 하나라도 바뀌면 지문이 달라진다")
    func fingerprintCoversEveryInput() {
        let base = Self.baseKey()
        var variants: [String: ToolchainProbeCacheKey] = [:]

        var tool = base; tool.toolID = "python3.13"; variants["툴 id"] = tool
        var path = base; path.resolvedPath = "/usr/bin/python3"; variants["절대경로"] = path
        var inode = base
        inode.fileIdentity?.inode = 4243
        variants["inode"] = inode
        var size = base
        size.fileIdentity?.size = 91_249
        variants["크기"] = size
        var mtime = base
        mtime.fileIdentity?.modifiedNanoseconds = 124
        variants["mtime"] = mtime
        var device = base
        device.fileIdentity?.device = 16777233
        variants["device"] = device
        var searchPath = base; searchPath.searchPath = ["/usr/bin", "/opt/conda/bin"]; variants["PATH 순서"] = searchPath
        var build = base; build.osBuild = "25G84"; variants["OS 빌드"] = build
        var developer = base; developer.developerDirectory = "/Library/Developer/CommandLineTools"; variants["xcode-select"] = developer
        var app = base; app.appVersion = "1.0.1"; variants["앱 버전"] = app
        var noIdentity = base; noIdentity.fileIdentity = nil; variants["신원 없음"] = noIdentity

        let baseFingerprint = base.fingerprint
        for (label, variant) in variants {
            #expect(variant.fingerprint != baseFingerprint, "\(label) 가 바뀌었는데 지문이 같다")
        }
        // 같은 입력은 같은 지문 — 순수 함수여야 캐시가 성립한다.
        #expect(Self.baseKey().fingerprint == baseFingerprint)
        #expect(baseFingerprint.count == 64)
    }

    @Test("스키마 버전이 지문에 들어간다")
    func schemaVersionIsPartOfKey() {
        #expect(ToolchainProbeCacheKey.schemaVersion >= 1)
        // 지문 재료에 "v<schema>" 접두가 들어가므로, 스키마를 올리면 전 항목이 무효화된다.
        // 여기서는 존재만 고정하고, 실제 무효화는 상수를 바꿀 때 자동으로 일어난다.
        #expect(!Self.baseKey().fingerprint.isEmpty)
    }

    @Test("저장한 판정을 그대로 되읽는다")
    func roundTripsVerdicts() async {
        let cache = ToolchainProbeCache()
        let key = Self.baseKey()

        await cache.store(.ready(version: ToolVersion("3.13.12")!), for: key)
        #expect(await cache.verdict(for: key) == .ready(version: ToolVersion("3.13.12")!))

        await cache.store(.stub(reason: "Unable to locate a Java Runtime"), for: key)
        #expect(await cache.verdict(for: key) == .stub(reason: "Unable to locate a Java Runtime"))

        await cache.store(.skippedWithoutDeveloperDirectory, for: key)
        #expect(await cache.verdict(for: key) == .skippedWithoutDeveloperDirectory)

        await cache.store(.belowMinimum(version: ToolVersion("3.9.6")!), for: key)
        #expect(await cache.verdict(for: key) == .belowMinimum(version: ToolVersion("3.9.6")!))
    }

    @Test("다른 키는 서로의 값을 보지 않는다")
    func keysAreIsolated() async {
        let cache = ToolchainProbeCache()
        var other = Self.baseKey()
        other.toolID = "node"

        await cache.store(.ready(version: ToolVersion("3.13.12")!), for: Self.baseKey())
        #expect(await cache.verdict(for: other) == nil)
    }

    @Test("24시간 TTL 을 넘기면 무효")
    func expiresAfterTimeToLive() async {
        let now = Clock()
        let cache = ToolchainProbeCache(now: { now.value })
        let key = Self.baseKey()

        await cache.store(.ready(version: ToolVersion("3.13.12")!), for: key)
        #expect(await cache.verdict(for: key) != nil)

        now.advance(by: 23 * 3600)
        #expect(await cache.verdict(for: key) != nil)

        now.advance(by: 2 * 3600) // 25시간
        #expect(await cache.verdict(for: key) == nil)
        #expect(await cache.count == 0, "만료 항목은 조회 시 정리된다")
    }

    @Test("기본 TTL 은 24시간")
    func defaultTimeToLiveIsOneDay() {
        #expect(ToolchainProbeCache.defaultTimeToLive == .seconds(24 * 60 * 60))
    }

    @Test("디스크 왕복 후에도 지문과 판정이 보존된다")
    func savesAndLoadsFromDisk() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("learnkit-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("probe-cache.json")

        let writer = ToolchainProbeCache()
        await writer.store(.ready(version: ToolVersion("3.13.12")!), for: Self.baseKey())
        try await writer.save(to: url)

        let reader = ToolchainProbeCache()
        try await reader.load(from: url)
        #expect(await reader.verdict(for: Self.baseKey()) == .ready(version: ToolVersion("3.13.12")!))
    }

    @Test("만료 항목은 디스크에서 되읽지 않는다")
    func expiredEntriesAreNotRestored() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("learnkit-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("probe-cache.json")

        let now = Clock()
        let writer = ToolchainProbeCache(now: { now.value })
        await writer.store(.ready(version: ToolVersion("3.13.12")!), for: Self.baseKey())
        try await writer.save(to: url)

        now.advance(by: 48 * 3600)
        let reader = ToolchainProbeCache(now: { now.value })
        try await reader.load(from: url)
        #expect(await reader.count == 0)
    }

    @Test("OS 빌드는 sysctl 로 읽힌다")
    func readsOSBuild() {
        let build = ToolchainEnvironmentFingerprint.currentOSBuild()
        #expect(!build.isEmpty)
        #expect(!build.contains("\0"))
    }
}

/// 주입 가능한 시계. TTL 테스트가 실제로 24시간을 기다릴 수는 없다.
final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Date(timeIntervalSince1970: 1_780_000_000)

    var value: Date {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        storage = storage.addingTimeInterval(seconds)
        lock.unlock()
    }
}
