import ContentKit
import Foundation
import Testing

@testable import PackBuild

@Suite("배포 팩 굽기")
struct DistributionBuildTests {
    /// 한 번 굽는다. 반환은 (결과, 아카이브 URL, 스테이징 URL).
    private static func build(
        in workspace: URL, name: String, source: URL, signingKey: String? = nil
    ) throws -> (DistributionResult, URL, URL) {
        let archive = workspace.appendingPathComponent("\(name).tar")
        let staging = workspace.appendingPathComponent("\(name).staging", isDirectory: true)
        let result = try DistributionBuilder.build(
            source: source, staging: staging, archiveURL: archive, signingKeyBase64: signingKey)
        return (result, archive, staging)
    }

    @Test("두 번 구운 tar 는 바이트가 같다")
    func archiveIsReproducible() throws {
        let workspace = try BuildFixtures.workspace("repro")
        defer { BuildFixtures.remove(workspace) }

        let (_, first, _) = try Self.build(
            in: workspace, name: "first", source: BuildFixtures.sourcePack)
        let (_, second, _) = try Self.build(
            in: workspace, name: "second", source: BuildFixtures.sourcePack)

        let a = try Data(contentsOf: first)
        let b = try Data(contentsOf: second)
        #expect(a == b, "같은 소스를 두 번 구웠는데 바이트가 다르다 (\(a.count)B vs \(b.count)B)")
        #expect(!a.isEmpty)
    }

    /// 서명한 팩에서 재현되는 것과 재현되지 않는 것을 갈라서 못 박는다.
    ///
    /// CryptoKit 의 Ed25519 는 논스에 난수를 섞는다 — 같은 키로 같은 바이트에 두 번
    /// 서명하면 다른 64바이트가 나오고 **둘 다 유효**하다(실측). RFC 8032 의 순수
    /// Ed25519 를 기대하고 "서명까지 재현된다" 고 적었다가 이 테스트에 잡혔다.
    /// 그래서 재현성 계약은 **서명 파일을 뺀 트리 전부**다.
    @Test("서명 파일만 매번 다르고 나머지는 바이트가 같다")
    func signedBuildReproducesEverythingButTheSignature() throws {
        let workspace = try BuildFixtures.workspace("repro-signed")
        defer { BuildFixtures.remove(workspace) }
        let keys = BuildFixtures.keyPair()

        let (first, _, firstStaging) = try Self.build(
            in: workspace, name: "first", source: BuildFixtures.sourcePack,
            signingKey: keys.private)
        let (_, _, secondStaging) = try Self.build(
            in: workspace, name: "second", source: BuildFixtures.sourcePack,
            signingKey: keys.private)
        #expect(first.signed)

        // 서명을 뺀 모든 파일이 바이트 단위로 같다. 매니페스트도 포함이다 —
        // 매니페스트가 흔들리면 서명 대상 자체가 흔들린다.
        var compared = 0
        for entry in first.manifest.files.map(\.path) + [PackLayout.manifestFileName] {
            let a = try Data(contentsOf: firstStaging.appendingPathComponent(entry))
            let b = try Data(contentsOf: secondStaging.appendingPathComponent(entry))
            #expect(a == b, "\(entry) 가 두 빌드에서 다르다")
            compared += 1
        }
        #expect(compared == first.manifest.files.count + 1)

        // 서명은 다르다. 그리고 둘 다 유효하다.
        let signatures = try [firstStaging, secondStaging].map { staging in
            try PackSignature.parse(
                String(
                    contentsOf: PackSignatureVerification.signatureURL(in: staging),
                    encoding: .utf8))
        }
        #expect(signatures[0] != signatures[1], "CryptoKit 이 결정적으로 바뀌었다면 계약을 다시 보라")
        for staging in [firstStaging, secondStaging] {
            try PackSignatureVerification.verifyPack(
                at: staging, expectedPublicKeyBase64: keys.public)
        }
    }

    @Test("배포 팩에 solutions 가 없다")
    func solutionsAreStripped() throws {
        let workspace = try BuildFixtures.workspace("strip")
        defer { BuildFixtures.remove(workspace) }

        let (result, _, staging) = try Self.build(
            in: workspace, name: "dist", source: BuildFixtures.sourcePack)

        #expect(!result.strippedPaths.isEmpty)
        #expect(result.strippedPaths.allSatisfy { $0.hasPrefix("solutions/") })
        #expect(result.manifest.isDistribution)
        #expect(!result.manifest.files.contains { $0.path.hasPrefix("solutions/") })
        #expect(
            !FileManager.default.fileExists(
                atPath: staging.appendingPathComponent("solutions").path),
            "스테이징에 solutions 디렉터리가 남아 있다")
    }

    @Test("벗긴 것 말고는 소스와 같은 파일이 같은 해시로 남는다")
    func remainingFilesKeepTheirDigests() throws {
        let workspace = try BuildFixtures.workspace("digests")
        defer { BuildFixtures.remove(workspace) }

        let source = try ContentPack(directory: BuildFixtures.sourcePack)
        let (result, _, _) = try Self.build(
            in: workspace, name: "dist", source: BuildFixtures.sourcePack)

        let sourceIndex = source.manifest.fileIndex()
        for entry in result.manifest.files {
            let original = sourceIndex[entry.path]
            #expect(original?.sha256 == entry.sha256, "\(entry.path) 의 해시가 바뀌었다")
        }
        let kept = source.manifest.files.count - result.strippedPaths.count
        #expect(result.manifest.files.count == kept)
    }

    @Test("배포 매니페스트는 소스와 generatedAt 이 같다 — 굽는 시각을 읽지 않는다")
    func generatedAtComesFromSource() throws {
        let workspace = try BuildFixtures.workspace("timestamp")
        defer { BuildFixtures.remove(workspace) }

        let source = try ContentPack(directory: BuildFixtures.sourcePack)
        let (result, _, _) = try Self.build(
            in: workspace, name: "dist", source: BuildFixtures.sourcePack)
        #expect(result.manifest.generatedAt == source.manifest.generatedAt)
    }

    @Test("이미 배포 팩인 것은 다시 굽지 않는다")
    func doubleBuildIsRefused() throws {
        let workspace = try BuildFixtures.workspace("double")
        defer { BuildFixtures.remove(workspace) }

        let (_, _, staging) = try Self.build(
            in: workspace, name: "first", source: BuildFixtures.sourcePack)

        #expect(throws: DistributionError.self) {
            _ = try Self.build(in: workspace, name: "second", source: staging)
        }
    }

    @Test("스테이징이 이미 있어도 남은 것이 섞이지 않는다")
    func stagingIsReset() throws {
        let workspace = try BuildFixtures.workspace("stale")
        defer { BuildFixtures.remove(workspace) }

        let staging = workspace.appendingPathComponent("dist.staging", isDirectory: true)
        try FileManager.default.createDirectory(
            at: staging.appendingPathComponent("lessons"), withIntermediateDirectories: true)
        let intruder = staging.appendingPathComponent("lessons/intruder.md")
        try Data("남은 것".utf8).write(to: intruder)

        let archive = workspace.appendingPathComponent("dist.tar")
        let result = try DistributionBuilder.build(
            source: BuildFixtures.sourcePack, staging: staging, archiveURL: archive)

        #expect(!FileManager.default.fileExists(atPath: intruder.path))
        #expect(!result.manifest.files.contains { $0.path == "lessons/intruder.md" })
    }
}

@Suite("구운 tar")
struct ArchiveTests {
    @Test("/usr/bin/tar 가 읽고, 푼 것이 그대로 팩이다")
    func systemTarCanExtract() throws {
        let workspace = try BuildFixtures.workspace("extract")
        defer { BuildFixtures.remove(workspace) }

        let archive = workspace.appendingPathComponent("dist.tar")
        let result = try DistributionBuilder.build(
            source: BuildFixtures.sourcePack,
            staging: workspace.appendingPathComponent("staging", isDirectory: true),
            archiveURL: archive)

        let extracted = workspace.appendingPathComponent("extracted", isDirectory: true)
        try BuildFixtures.extract(archive, into: extracted)

        let root = extracted.appendingPathComponent(result.rootName, isDirectory: true)
        #expect(
            FileManager.default.fileExists(atPath: root.path),
            "아카이브가 \(result.rootName)/ 아래로 풀리지 않았다")

        // 푼 팩이 그대로 열리고, 해시가 전부 맞는다.
        let pack = try ContentPack(directory: root)
        #expect(pack.manifest.isDistribution)
        try pack.verifyChecksums()
        #expect(
            !FileManager.default.fileExists(atPath: root.appendingPathComponent("solutions").path))
    }

    @Test("아카이브에 굽는 사람과 굽는 시각이 남지 않는다")
    func headersCarryNoIdentity() throws {
        let workspace = try BuildFixtures.workspace("headers")
        defer { BuildFixtures.remove(workspace) }

        let archive = workspace.appendingPathComponent("dist.tar")
        let result = try DistributionBuilder.build(
            source: BuildFixtures.sourcePack,
            staging: workspace.appendingPathComponent("staging", isDirectory: true),
            archiveURL: archive)

        let bytes = [UInt8](try Data(contentsOf: archive))
        let expectedMTime = DistributionBuilder.epochSeconds(
            fromTimestamp: result.manifest.generatedAt)
        var headers = 0

        var offset = 0
        while offset + 512 <= bytes.count {
            let block = Array(bytes[offset..<(offset + 512)])
            if block.allSatisfy({ $0 == 0 }) { break }
            headers += 1

            func field(_ start: Int, _ width: Int) -> String {
                String(decoding: block[start..<(start + width)].prefix { $0 != 0 && $0 != 0x20 }, as: UTF8.self)
            }
            #expect(field(108, 8) == "0000000", "uid 가 0 이 아니다")
            #expect(field(116, 8) == "0000000", "gid 가 0 이 아니다")
            #expect(block[265] == 0, "uname 이 비어 있지 않다")
            #expect(block[297] == 0, "gname 이 비어 있지 않다")
            #expect(field(136, 12) == String(format: "%011o", expectedMTime), "mtime 이 generatedAt 이 아니다")
            #expect(field(257, 6) == "ustar")

            let size = UInt64(field(124, 12), radix: 8) ?? 0
            offset += 512 + Int((size + 511) / 512) * 512
        }
        #expect(headers > 0)
    }

    @Test("100바이트를 넘는 경로는 조용히 잘리지 않고 거부된다")
    func longPathsAreRefused() {
        let long = String(repeating: "a", count: 101)
        #expect(throws: TarWriter.Failure.self) {
            _ = try TarWriter.archive([.file(path: long, data: Data())], modificationTime: 0)
        }
    }

    @Test("generatedAt 을 epoch 초로 옮긴다")
    func timestampConversion() {
        #expect(DistributionBuilder.epochSeconds(fromTimestamp: "1970-01-01T00:00:00Z") == 0)
        #expect(DistributionBuilder.epochSeconds(fromTimestamp: "2026-09-06T00:00:00Z") == 1_788_652_800)
        // 형식이 어긋나도 **결정적**이어야 재현성이 지켜진다.
        #expect(DistributionBuilder.epochSeconds(fromTimestamp: "언제였더라") == 0)
    }
}
