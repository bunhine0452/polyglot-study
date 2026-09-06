public import Foundation

internal import CryptoKit

/// Ed25519 서명·검증. 키를 **어디서 읽을지는 이 타입이 정하지 않는다** — 호출자가
/// 환경변수에서 읽어 base64 문자열로 건넨다.
public enum PackSigning {
    /// 개인키 base64(32바이트 원문)로 정규 매니페스트 바이트에 서명한다.
    ///
    /// 실패해도 에러에 키가 담기지 않는다 (``PackSignatureError/invalidPrivateKey``).
    public static func sign(
        manifestBytes: Data, privateKeyBase64: String
    ) throws(PackSignatureError) -> PackSignature {
        let key = try privateKey(fromBase64: privateKeyBase64)
        guard let raw = try? key.signature(for: manifestBytes) else {
            // CryptoKit 의 Ed25519 서명은 실패 경로가 사실상 없지만, 삼키지는 않는다.
            throw .signatureInvalid
        }
        return try PackSignature(
            publicKey: key.publicKey.rawRepresentation, signature: Data(raw))
    }

    /// 서명이 이 바이트열에 대한 것이고, **우리가 아는 공개키**의 것인지 본다.
    ///
    /// 공개키 대조가 먼저다. 서명 파일이 자기 공개키를 들고 다니므로, 그것만 믿으면
    /// 아무나 자기 키로 다시 서명해 통과시킬 수 있다.
    public static func verify(
        manifestBytes: Data, signature: PackSignature, expectedPublicKeyBase64: String
    ) throws(PackSignatureError) {
        guard let expected = Data(base64Encoded: expectedPublicKeyBase64), expected.count == 32
        else {
            throw .expectedPublicKeyMalformed
        }
        guard expected == signature.publicKey else {
            throw .publicKeyMismatch(
                expected: expected.base64EncodedString(), actual: signature.publicKeyBase64)
        }
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: expected) else {
            throw .expectedPublicKeyMalformed
        }
        guard key.isValidSignature(signature.signature, for: manifestBytes) else {
            throw .signatureInvalid
        }
    }

    /// 새 키 쌍. `packtool keygen` 하나만 부른다 — 개인키는 파일로만 나가고 stdout 에는
    /// 공개키만 찍힌다.
    public static func generateKeyPair() -> (privateKeyBase64: String, publicKeyBase64: String) {
        let key = Curve25519.Signing.PrivateKey()
        return (
            key.rawRepresentation.base64EncodedString(),
            key.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    private static func privateKey(
        fromBase64 text: String
    ) throws(PackSignatureError) -> Curve25519.Signing.PrivateKey {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Data(base64Encoded: trimmed), raw.count == 32,
            let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw)
        else {
            throw .invalidPrivateKey
        }
        return key
    }
}

/// 디스크의 팩 하나를 검증한다 — **서명과 해시 둘 다.**
///
/// 서명만 보면 안 되는 이유는 서명 대상이 매니페스트 한 파일이기 때문이다. 레슨 본문을
/// 바꿔도 매니페스트는 그대로라 서명은 통과한다. 그 변조를 잡는 것은 `files[].sha256`
/// 대조이고, 그 대조표가 진짜인지를 보장하는 것이 서명이다. 둘은 한 쌍이다.
public enum PackSignatureVerification {
    /// 서명 파일 경로.
    public static func signatureURL(in directory: URL) -> URL {
        directory.appendingPathComponent(PackLayout.signatureFileName)
    }

    /// 디스크의 매니페스트 원문 바이트. **서명 대상은 이 바이트열 그대로**다.
    ///
    /// 읽은 바이트가 정규형인지도 함께 본다. 정규형이 아닌 매니페스트에 서명하면
    /// "무엇에 서명했는가" 가 인코더 설정에 달리게 되고, 그때부터 서명은 계약이 아니다.
    public static func canonicalManifestBytes(
        in directory: URL
    ) throws(PackVerificationError) -> Data {
        let url = directory.appendingPathComponent(PackLayout.manifestFileName)
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw .pack(.manifestMissing(directory.path))
        }
        let decoded: PackManifest
        do {
            decoded = try CanonicalJSON.decode(PackManifest.self, from: data)
        } catch {
            throw .pack(.manifestUndecodable("\(error)"))
        }
        guard let recoded = try? CanonicalJSON.encode(decoded), recoded == data else {
            throw .signature(.manifestNotCanonical)
        }
        return data
    }

    /// 서명 + 해시. 하나라도 어긋나면 던진다.
    public static func verifyPack(
        at directory: URL, expectedPublicKeyBase64: String
    ) throws(PackVerificationError) {
        let bytes = try canonicalManifestBytes(in: directory)

        let signatureURL = signatureURL(in: directory)
        guard let signatureData = FileManager.default.contents(atPath: signatureURL.path) else {
            throw .signature(.missing(PackLayout.signatureFileName))
        }
        do {
            let signature = try PackSignature.parse(
                String(decoding: signatureData, as: UTF8.self))
            try PackSigning.verify(
                manifestBytes: bytes, signature: signature,
                expectedPublicKeyBase64: expectedPublicKeyBase64)
        } catch {
            throw .signature(error)
        }

        // 서명이 보증하는 것은 해시표까지다. 내용물은 그 표와 대조해야 한다.
        let pack: ContentPack
        do {
            pack = try ContentPack(directory: directory)
        } catch {
            throw .pack(error)
        }
        do {
            try pack.verifyChecksums()
        } catch {
            throw .pack(error)
        }
    }
}

public enum PackVerificationError: Error, Hashable, Sendable, CustomStringConvertible {
    case pack(ContentPackError)
    case signature(PackSignatureError)

    public var description: String {
        switch self {
        case .pack(let error): "\(error)"
        case .signature(let error): "\(error)"
        }
    }
}
