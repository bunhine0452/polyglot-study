public import Foundation

/// 정규 매니페스트 바이트에 대한 **분리 서명**.
///
/// ## 왜 매니페스트만 서명하는가
///
/// 매니페스트가 팩의 나머지 전부를 sha256 으로 이미 덮고 있다. 파일 하나를 바꾸면
/// 그 해시가 매니페스트와 어긋나고, 해시를 맞추려면 매니페스트를 고쳐야 하고, 그러면
/// 서명이 깨진다. 그래서 서명 대상은 `manifest.json` 한 파일이면 충분하다 —
/// 단, **검증은 반드시 해시 대조까지 함께** 해야 한다. 서명만 보면 내용물이 바뀐 팩을
/// 통과시킨다 (``PackSignatureVerification`` 참조).
///
/// ## 파일 형식
///
/// ```
/// polyglot-pack-signature v1
/// algorithm: ed25519
/// publicKey: <base64 32B>
/// signature: <base64 64B>
/// ```
///
/// UTF-8·LF·끝에 개행 하나. 서명이 공개키를 함께 들고 다니는 이유는 **"다른 키로
/// 서명됐다" 와 "변조됐다" 를 갈라서 보고**하기 위해서다. 이 필드가 신뢰의 근거는
/// 아니다 — 검증기는 자기가 아는 공개키와 대조하고, 다르면 서명을 계산해 보지도 않는다.
public struct PackSignature: Hashable, Sendable {
    /// 현재 유일한 알고리즘.
    ///
    /// **Apple 의 CryptoKit 구현은 결정적이지 않다**(실측). RFC 8032 의 순수 Ed25519 는
    /// 논스를 키와 메시지에서 유도하지만, CryptoKit 은 거기에 난수를 섞는다 — 같은 키로
    /// 같은 바이트에 두 번 서명하면 서로 다른 64바이트가 나오고 **둘 다 유효**하다.
    /// 그래서 서명 파일은 재현 대상이 아니다. 배포 팩의 재현성은 서명을 뺀 나머지
    /// 전부에 걸린다 (``PackLayout/signatureFileName``).
    public static let algorithm = "ed25519"
    public static let formatHeader = "polyglot-pack-signature v1"

    /// 32바이트 원문.
    public let publicKey: Data
    /// 64바이트 원문.
    public let signature: Data

    public init(publicKey: Data, signature: Data) throws(PackSignatureError) {
        guard publicKey.count == 32 else { throw .invalidPublicKeyLength(publicKey.count) }
        guard signature.count == 64 else { throw .invalidSignatureLength(signature.count) }
        self.publicKey = publicKey
        self.signature = signature
    }

    public var publicKeyBase64: String { publicKey.base64EncodedString() }

    /// 파일에 그대로 쓰는 정규 텍스트.
    public func canonicalText() -> String {
        """
        \(Self.formatHeader)
        algorithm: \(Self.algorithm)
        publicKey: \(publicKey.base64EncodedString())
        signature: \(signature.base64EncodedString())

        """
    }

    /// 서명 파일을 읽는다. 형식 위반은 전부 서로 다른 에러다.
    public static func parse(_ text: String) throws(PackSignatureError) -> PackSignature {
        var fields: [String: String] = [:]
        var sawHeader = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if !sawHeader {
                guard line == formatHeader else { throw .unknownFormat(line) }
                sawHeader = true
                continue
            }
            guard let separator = line.firstIndex(of: ":") else {
                throw .malformedLine(line)
            }
            let key = String(line[line.startIndex..<separator])
            let value = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            guard fields[key] == nil else { throw .duplicateField(key) }
            fields[key] = value
        }

        guard sawHeader else { throw .unknownFormat("") }
        guard let algorithm = fields["algorithm"] else { throw .missingField("algorithm") }
        guard algorithm == Self.algorithm else { throw .unsupportedAlgorithm(algorithm) }
        guard let publicKeyText = fields["publicKey"] else { throw .missingField("publicKey") }
        guard let signatureText = fields["signature"] else { throw .missingField("signature") }
        guard let publicKey = Data(base64Encoded: publicKeyText) else {
            throw .malformedBase64("publicKey")
        }
        guard let signature = Data(base64Encoded: signatureText) else {
            throw .malformedBase64("signature")
        }
        return try PackSignature(publicKey: publicKey, signature: signature)
    }
}

public enum PackSignatureError: Error, Hashable, Sendable, CustomStringConvertible {
    /// 팩에 서명 파일이 없다.
    case missing(String)
    case unknownFormat(String)
    case malformedLine(String)
    case duplicateField(String)
    case missingField(String)
    case unsupportedAlgorithm(String)
    case malformedBase64(String)
    case invalidPublicKeyLength(Int)
    case invalidSignatureLength(Int)
    /// 개인키가 32바이트 base64 가 아니다. **값은 담지 않는다.**
    case invalidPrivateKey
    /// 서명은 멀쩡하지만 우리가 아는 공개키가 아니다.
    case publicKeyMismatch(expected: String, actual: String)
    /// 대조할 공개키(환경변수 쪽)가 32바이트 base64 가 아니다. 팩의 문제가 아니라
    /// **부르는 쪽의 문제**라 서명 파일의 길이 오류와 갈라 둔다.
    case expectedPublicKeyMalformed
    /// 서명이 이 매니페스트 바이트에 맞지 않는다.
    case signatureInvalid
    /// 디스크의 매니페스트가 정규형이 아니다 — 서명 대상 바이트가 애매해진다.
    case manifestNotCanonical

    public var description: String {
        switch self {
        case .missing(let path): "서명 파일이 없다: \(path)"
        case .unknownFormat(let line):
            "서명 파일 형식을 모른다 (첫 줄이 '\(PackSignature.formatHeader)' 여야 한다): \(line)"
        case .malformedLine(let line): "서명 파일에 'key: value' 가 아닌 줄이 있다: \(line)"
        case .duplicateField(let key): "서명 파일에 \(key) 가 두 번 나온다"
        case .missingField(let key): "서명 파일에 \(key) 가 없다"
        case .unsupportedAlgorithm(let name):
            "지원하지 않는 서명 알고리즘: \(name) (\(PackSignature.algorithm) 만 안다)"
        case .malformedBase64(let key): "서명 파일의 \(key) 가 base64 가 아니다"
        case .invalidPublicKeyLength(let count): "공개키가 32바이트가 아니다: \(count)B"
        case .invalidSignatureLength(let count): "서명이 64바이트가 아니다: \(count)B"
        case .invalidPrivateKey: "개인키가 32바이트 base64 가 아니다"
        case .publicKeyMismatch(let expected, let actual):
            "다른 키로 서명된 팩이다\n  기대 \(expected)\n  실제 \(actual)"
        case .expectedPublicKeyMalformed:
            "대조할 공개키가 32바이트 base64 가 아니다 — 팩이 아니라 넘겨준 공개키를 보라"
        case .signatureInvalid: "서명이 매니페스트와 맞지 않는다 — 매니페스트가 변조됐다"
        case .manifestNotCanonical:
            "디스크의 \(PackLayout.manifestFileName) 이 정규형이 아니다 — 서명 대상 바이트를 확정할 수 없다"
        }
    }
}
