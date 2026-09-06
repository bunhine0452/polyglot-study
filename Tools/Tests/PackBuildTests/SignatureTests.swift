import ContentKit
import Foundation
import Testing

@testable import PackBuild

@Suite("팩 서명과 검증")
struct SignatureTests {
    /// 소스 팩을 임시 공간에 복사하고 서명까지 붙인다.
    private static func signedPack(
        _ label: String
    ) throws -> (workspace: URL, pack: URL, keys: (private: String, public: String)) {
        let workspace = try BuildFixtures.workspace(label)
        let pack = try BuildFixtures.copySource(into: workspace)
        let keys = BuildFixtures.keyPair()
        let bytes = try PackSignatureVerification.canonicalManifestBytes(in: pack)
        let signature = try PackSigning.sign(manifestBytes: bytes, privateKeyBase64: keys.private)
        try Data(signature.canonicalText().utf8).write(
            to: PackSignatureVerification.signatureURL(in: pack))
        return (workspace, pack, keys)
    }

    @Test("서명한 팩은 서명·해시 둘 다 통과한다")
    func signedPackVerifies() throws {
        let fixture = try Self.signedPack("verify-ok")
        defer { BuildFixtures.remove(fixture.workspace) }

        try PackSignatureVerification.verifyPack(
            at: fixture.pack, expectedPublicKeyBase64: fixture.keys.public)
    }

    @Test("서명이 없는 팩은 거부된다 — 없으면 통과가 아니다")
    func unsignedPackIsRefused() throws {
        let workspace = try BuildFixtures.workspace("verify-unsigned")
        defer { BuildFixtures.remove(workspace) }
        let pack = try BuildFixtures.copySource(into: workspace)
        let keys = BuildFixtures.keyPair()

        #expect(throws: PackVerificationError.signature(.missing(PackLayout.signatureFileName))) {
            try PackSignatureVerification.verifyPack(
                at: pack, expectedPublicKeyBase64: keys.public)
        }
    }

    @Test("매니페스트를 고치면 서명이 깨진다")
    func tamperedManifestBreaksSignature() throws {
        let fixture = try Self.signedPack("verify-manifest")
        defer { BuildFixtures.remove(fixture.workspace) }

        // 정규형을 유지한 채 값만 바꾼다 — 서명이 잡아야 하는 것은 형식이 아니라 내용이다.
        let url = fixture.pack.appendingPathComponent(PackLayout.manifestFileName)
        var manifest = try CanonicalJSON.decode(PackManifest.self, from: try Data(contentsOf: url))
        manifest.displayName = "바뀐 이름"
        try CanonicalJSON.encode(manifest).write(to: url)

        #expect(throws: PackVerificationError.signature(.signatureInvalid)) {
            try PackSignatureVerification.verifyPack(
                at: fixture.pack, expectedPublicKeyBase64: fixture.keys.public)
        }
    }

    @Test("레슨 본문을 고치면 해시 대조가 잡는다 — 서명만으로는 못 잡는 변조")
    func tamperedContentIsCaughtByDigests() throws {
        let fixture = try Self.signedPack("verify-content")
        defer { BuildFixtures.remove(fixture.workspace) }

        let manifest = try ContentPack(directory: fixture.pack).manifest
        guard let lesson = manifest.files.first(where: { $0.path.hasPrefix("lessons/") }) else {
            Issue.record("픽스처에 레슨 파일이 없다")
            return
        }
        let url = fixture.pack.appendingPathComponent(lesson.path)
        try (try String(contentsOf: url, encoding: .utf8) + "\n변조\n").write(
            to: url, atomically: true, encoding: .utf8)

        // 서명 자체는 여전히 유효하다 — 매니페스트는 손대지 않았다. 잡는 것은 해시다.
        let bytes = try PackSignatureVerification.canonicalManifestBytes(in: fixture.pack)
        let signature = try PackSignature.parse(
            try String(
                contentsOf: PackSignatureVerification.signatureURL(in: fixture.pack),
                encoding: .utf8))
        try PackSigning.verify(
            manifestBytes: bytes, signature: signature,
            expectedPublicKeyBase64: fixture.keys.public)

        #expect(throws: PackVerificationError.self) {
            try PackSignatureVerification.verifyPack(
                at: fixture.pack, expectedPublicKeyBase64: fixture.keys.public)
        }
    }

    @Test("다른 키로 서명한 팩은 '변조' 가 아니라 '다른 키' 로 갈려 보고된다")
    func foreignKeyIsItsOwnVerdict() throws {
        let fixture = try Self.signedPack("verify-foreign")
        defer { BuildFixtures.remove(fixture.workspace) }
        let other = BuildFixtures.keyPair()

        do {
            try PackSignatureVerification.verifyPack(
                at: fixture.pack, expectedPublicKeyBase64: other.public)
            Issue.record("다른 키인데 통과했다")
        } catch .signature(.publicKeyMismatch(let expected, let actual)) {
            #expect(expected == other.public)
            #expect(actual == fixture.keys.public)
        } catch {
            Issue.record("기대와 다른 에러: \(error)")
        }
    }

    @Test("정규형이 아닌 매니페스트에는 서명 대상 바이트가 없다")
    func nonCanonicalManifestIsRefused() throws {
        let workspace = try BuildFixtures.workspace("noncanonical")
        defer { BuildFixtures.remove(workspace) }
        let pack = try BuildFixtures.copySource(into: workspace)

        let url = pack.appendingPathComponent(PackLayout.manifestFileName)
        let manifest = try CanonicalJSON.decode(PackManifest.self, from: try Data(contentsOf: url))
        // 값은 같고 인코딩만 다르다 (들여쓰기 없음).
        try JSONEncoder().encode(manifest).write(to: url)

        #expect(throws: PackVerificationError.signature(.manifestNotCanonical)) {
            _ = try PackSignatureVerification.canonicalManifestBytes(in: pack)
        }
    }

    @Test("구운 팩은 그 자리에서 검증된다 — build --sign 의 왕복")
    func builtPackVerifies() throws {
        let workspace = try BuildFixtures.workspace("build-sign")
        defer { BuildFixtures.remove(workspace) }
        let keys = BuildFixtures.keyPair()

        let staging = workspace.appendingPathComponent("staging", isDirectory: true)
        let result = try DistributionBuilder.build(
            source: BuildFixtures.sourcePack,
            staging: staging,
            archiveURL: workspace.appendingPathComponent("dist.tar"),
            signingKeyBase64: keys.private)

        #expect(result.signed)
        try PackSignatureVerification.verifyPack(
            at: staging, expectedPublicKeyBase64: keys.public)
    }

    @Test("서명 파일은 files 에 등록되지 않는다 — 자기 참조라 등록될 수 없다")
    func signatureIsNotRegistered() throws {
        let fixture = try Self.signedPack("registration")
        defer { BuildFixtures.remove(fixture.workspace) }

        let manifest = try ContentPack(directory: fixture.pack).manifest
        #expect(!manifest.files.contains { $0.path == PackLayout.signatureFileName })
        // 그런데도 양방향 대조는 "디스크에 있는데 files 에 없다" 로 걸리지 않아야 한다.
        let scanned = try PackManifestBuilder.scanFiles(in: fixture.pack)
        #expect(!scanned.contains { $0.path == PackLayout.signatureFileName })
        #expect(scanned.map(\.path) == manifest.files.map(\.path))
    }
}

@Suite("서명 파일 형식")
struct SignatureFormatTests {
    private static func sample() throws -> PackSignature {
        try PackSigning.sign(
            manifestBytes: Data("바이트".utf8),
            privateKeyBase64: PackSigning.generateKeyPair().privateKeyBase64)
    }

    @Test("정규 텍스트를 다시 읽으면 같은 값이다")
    func roundTrip() throws {
        let signature = try Self.sample()
        #expect(try PackSignature.parse(signature.canonicalText()) == signature)
    }

    @Test("첫 줄이 다르면 형식을 모른다고 한다")
    func unknownHeader() throws {
        #expect(throws: PackSignatureError.unknownFormat("something-else v9")) {
            _ = try PackSignature.parse("something-else v9\nalgorithm: ed25519\n")
        }
    }

    @Test("모르는 알고리즘은 조용히 넘기지 않는다")
    func unsupportedAlgorithm() throws {
        let text = """
            \(PackSignature.formatHeader)
            algorithm: rsa4096
            publicKey: AA==
            signature: AA==

            """
        #expect(throws: PackSignatureError.unsupportedAlgorithm("rsa4096")) {
            _ = try PackSignature.parse(text)
        }
    }

    @Test("필드가 빠지면 어느 필드인지 말한다")
    func missingField() throws {
        let text = """
            \(PackSignature.formatHeader)
            algorithm: \(PackSignature.algorithm)
            publicKey: AA==

            """
        #expect(throws: PackSignatureError.missingField("signature")) {
            _ = try PackSignature.parse(text)
        }
    }

    @Test("길이가 안 맞는 키·서명은 거부된다")
    func lengths() throws {
        let short = Data(repeating: 0, count: 8).base64EncodedString()
        let text = """
            \(PackSignature.formatHeader)
            algorithm: \(PackSignature.algorithm)
            publicKey: \(short)
            signature: \(short)

            """
        #expect(throws: PackSignatureError.invalidPublicKeyLength(8)) {
            _ = try PackSignature.parse(text)
        }
    }

    @Test("대조할 공개키가 망가진 것은 팩의 결함과 갈려 보고된다")
    func malformedExpectedKey() throws {
        let signature = try Self.sample()
        #expect(throws: PackSignatureError.expectedPublicKeyMalformed) {
            try PackSigning.verify(
                manifestBytes: Data("바이트".utf8), signature: signature,
                expectedPublicKeyBase64: "이건 base64 가 아니다")
        }
    }

    @Test("개인키가 32바이트가 아니면 서명하지 않는다 — 에러에 값은 담기지 않는다")
    func badPrivateKey() {
        #expect(throws: PackSignatureError.invalidPrivateKey) {
            _ = try PackSigning.sign(manifestBytes: Data(), privateKeyBase64: "not-base64!!")
        }
        let error = PackSignatureError.invalidPrivateKey
        #expect(!"\(error)".contains("not-base64"))
    }
}

@Suite("서명 키 주입")
struct SigningEnvironmentTests {
    @Test("환경변수가 없으면 안내와 함께 던진다")
    func notSet() {
        #expect(throws: SigningEnvironmentError.notSet(SigningEnvironment.privateKeyVariable)) {
            _ = try SigningEnvironment.privateKey([:])
        }
    }

    @Test("공백뿐이면 비어 있는 것으로 본다")
    func empty() {
        #expect(throws: SigningEnvironmentError.empty(SigningEnvironment.publicKeyVariable)) {
            _ = try SigningEnvironment.publicKey([SigningEnvironment.publicKeyVariable: "   "])
        }
    }

    @Test("안내 문구에 키 값이 실리지 않는다")
    func guidanceCarriesNoValue() {
        let text = "\(SigningEnvironmentError.notSet(SigningEnvironment.privateKeyVariable))"
        #expect(text.contains(SigningEnvironment.privateKeyVariable))
        #expect(text.contains("keygen"))
    }
}
