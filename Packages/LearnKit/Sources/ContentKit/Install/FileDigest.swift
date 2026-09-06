internal import CryptoKit
internal import Foundation

/// 팩 파일의 sha256. 매니페스트의 `files[].sha256` 와 대조하는 유일한 계산 지점.
enum FileDigest {
    /// 64KB 씩 읽어 해싱한다. 레슨 팩은 작지만 `assets/` 에 샘플 DB 가 들어오면
    /// 수십 MB 가 되고, 그때 통째로 메모리에 올릴 이유가 없다.
    private static let chunkSize = 64 * 1024

    static func sha256(ofFileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hex(hasher.finalize())
    }

    static func sha256(of data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    private static func hex(_ digest: some Sequence<UInt8>) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var out = [UInt8]()
        out.reserveCapacity(64)
        for byte in digest {
            out.append(digits[Int(byte >> 4)])
            out.append(digits[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }
}
