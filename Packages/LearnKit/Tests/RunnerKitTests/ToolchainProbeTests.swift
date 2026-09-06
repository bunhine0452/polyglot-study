import Testing
import Foundation
import LanguageKit
import LearnCore
@testable import RunnerKit

/// 이 머신에서 **실제로** 툴체인을 감지한다.
@Suite("툴체인 실측 감지", .serialized)
struct ToolchainProbeTests {
    static func makeProbe() async -> ToolchainProbe {
        await ToolchainProbe.standard()
    }

    @Test("xcode-select 게이트가 활성 개발자 디렉터리를 읽는다", .timeLimit(.minutes(1)))
    func developerDirectoryGate() async {
        let directory = await DeveloperDirectory.active()
        if let directory {
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
        }
        // 없어도 정상 — 그 경우 CLT 게이트가 켜진다.
    }

    @Test("개발자 디렉터리가 없으면 /usr/bin 개발도구를 실행하지 않는다", .timeLimit(.minutes(1)))
    func cltDialogGuardSkipsUsrBin() async {
        // `/usr/bin` 만 놓고 본다. 다른 곳의 진짜 툴체인은 게이트 대상이 아니다.
        var spec = ToolchainCatalog.swift
        spec.additionalDirectories = []
        spec.additionalDirectoryPatterns = []
        spec.searchViaXcrun = false

        let probe = ToolchainProbe(searchPath: ["/usr/bin"], developerDirectory: nil)
        let report = await probe.probe(spec)

        #expect(!report.candidates.isEmpty, "/usr/bin/swiftc 가 후보로 잡혀야 한다")
        for candidate in report.candidates {
            #expect(
                candidate.verdict == .skippedWithoutDeveloperDirectory,
                "\(candidate.path) 를 실행했다 — CLT 설치 다이얼로그가 뜬다"
            )
        }
        guard case .stub = report.availability else {
            Issue.record("전부 건너뛰었으면 stub 이어야 한다: \(report.availability)")
            return
        }
    }

    @Test("게이트는 /usr/bin 밖의 진짜 툴체인까지 막지 않는다", .timeLimit(.minutes(1)))
    func gateOnlyAppliesToUsrBin() async {
        let probe = ToolchainProbe(searchPath: ["/usr/bin"], developerDirectory: nil)
        let report = await probe.probe(ToolchainCatalog.swift)

        for candidate in report.candidates where candidate.path.hasPrefix("/usr/bin/") {
            #expect(candidate.verdict == .skippedWithoutDeveloperDirectory)
        }
        // CLT 디렉터리가 실재하면 그쪽은 실행해도 다이얼로그가 뜨지 않는다.
        for candidate in report.candidates where !candidate.path.hasPrefix("/usr/bin/") {
            #expect(candidate.verdict != .skippedWithoutDeveloperDirectory)
        }
    }

    @Test("게이트는 개발도구가 아닌 툴까지 막지 않는다", .timeLimit(.minutes(1)))
    func gateDoesNotBlockNonDeveloperTools() async {
        let probe = ToolchainProbe(searchPath: ["/usr/bin"], developerDirectory: nil)
        let report = await probe.probe(ToolchainCatalog.python)
        #expect(!report.candidates.contains { $0.verdict == .skippedWithoutDeveloperDirectory })
    }

    @Test("python3 는 PATH 앞의 3.9.6 이 아니라 최고 버전이 선택된다", .timeLimit(.minutes(1)))
    func picksNewestPythonNotFirstOnPath() async {
        let probe = await Self.makeProbe()
        let report = await probe.probe(ToolchainCatalog.python)

        let candidatePaths = report.candidates.map(\.path)
        // 전수 열거가 되고 있는지 — 후보가 하나뿐이면 정책을 검증할 수 없다.
        #expect(candidatePaths.count >= 1)

        guard case let .ready(version, path) = report.availability else {
            Issue.record("python3 는 이 머신에서 ready 여야 한다: \(report.availability)")
            return
        }
        let selected = try! #require(ToolVersion(version))

        // 발견된 모든 ready 후보 중 최고여야 한다.
        for candidate in report.candidates {
            if let other = candidate.readyVersion {
                #expect(!(selected < other), "\(candidate.path) 의 \(other) 가 선택된 \(version) 보다 높다")
            }
        }
        // `/usr/bin/python3`(3.9.6) 도 후보에 있었다면 그것이 선택돼선 안 된다.
        if report.candidates.contains(where: { $0.path == "/usr/bin/python3" && $0.readyVersion != nil }),
           report.candidates.count > 1 {
            #expect(path != "/usr/bin/python3" || selected >= ToolVersion("3.10")!)
        }
    }

    @Test("후보는 inode 로 중복 제거된다", .timeLimit(.minutes(1)))
    func candidatesAreDeduplicated() async {
        let probe = await Self.makeProbe()
        let candidates = await probe.candidates(for: ToolchainCatalog.node)
        let identities = candidates.compactMap(\.identity)
        #expect(Set(identities).count == identities.count, "같은 바이너리를 두 번 실행하고 있다")
    }

    @Test("캐시가 채워지고, 두 번째 감지는 실행을 건너뛴다", .timeLimit(.minutes(1)))
    func cacheShortCircuitsExecution() async {
        let probe = ToolchainProbe(searchPath: ["/usr/bin"], developerDirectory: nil)
        let cache = ToolchainProbeCache()
        let fingerprint = ToolchainEnvironmentFingerprint.current(probe: probe, appVersion: "test")

        let first = await probe.probe(ToolchainCatalog.python, cache: cache, fingerprint: fingerprint)
        #expect(first.candidates.count > 0)
        #expect(await cache.count == first.candidates.count)

        // 캐시 항목을 일부러 거짓으로 덮어쓴다. 두 번째 감지가 이 값을 그대로 돌려주면
        // 실제로 캐시를 보고 있다는 뜻이다 (프로세스를 다시 띄웠다면 3.9.6 이 나온다).
        let candidate = first.candidates[0]
        let key = fingerprint.key(
            toolID: ToolchainCatalog.python.id,
            resolvedPath: candidate.resolvedPath,
            fileIdentity: FileIdentity.of(path: candidate.resolvedPath)
        )
        await cache.store(.ready(version: ToolVersion("99.0.0")!), for: key)

        let second = await probe.probe(ToolchainCatalog.python, cache: cache, fingerprint: fingerprint)
        #expect(second.candidates.contains { $0.readyVersion == ToolVersion("99.0.0")! })
        guard case let .ready(version, _) = second.availability else {
            Issue.record("ready 여야 한다: \(second.availability)")
            return
        }
        #expect(version == "99.0.0")
    }

    @Test("이 머신의 10 개 트랙 감지 결과", .timeLimit(.minutes(3)))
    func detectAllToolchains() async {
        let harvest = await LoginPathHarvester.harvest()
        let probe = await ToolchainProbe.standard(harvest: harvest)
        let reports = await probe.probeAll()

        var table = "\n=== LearnKit 툴체인 감지 (실측) ===\n"
        table += "PATH 항목 \(probe.searchPath.count)개, xcode-select: \(probe.developerDirectory ?? "없음")"
        table += ", PATH 폴백: \(harvest.usedFallback)\n"
        table += "| 언어 | 툴 | 판정 | 버전 | 경로 | 후보수 |\n|---|---|---|---|---|---|\n"
        for report in reports {
            let (verdict, version, path) = Self.describe(report.availability)
            table += "| \(report.language.rawValue) | \(report.toolID) | \(verdict) | \(version) | \(path) | \(report.candidates.count) |\n"
        }
        table += "\n--- 후보별 상세 ---\n"
        for report in reports {
            for candidate in report.candidates {
                table += "\(report.toolID): \(candidate.path) → \(candidate.verdict)\n"
            }
        }
        print(table)

        #expect(reports.count == 10)
        // MVP 3종은 이 머신에서 추가 설치 없이 동작해야 한다는 것이 설계 전제다.
        for id in ["python3", "sqlite3", "swiftc"] {
            let report = try! #require(reports.first { $0.toolID == id })
            #expect(report.availability.isReady, "\(id) 가 ready 가 아니다: \(report.availability)")
        }
        // 모든 판정에 사용자에게 보여줄 문자열이 있어야 한다.
        for report in reports {
            let (_, _, _) = Self.describe(report.availability)
        }
    }

    static func describe(_ availability: ModuleAvailability) -> (String, String, String) {
        switch availability {
        case let .ready(version, path): return ("ready", version, path)
        case let .missing(hint): return ("missing", "-", hint)
        case let .stub(path, reason): return ("stub", "-", "\(path) — \(reason)")
        case let .unsupported(path, version, minimum):
            return ("unsupported", version, "\(path) — 최소 \(minimum) 필요")
        }
    }
}
