internal import Foundation

/// 결정적 ustar(POSIX.1-1988) 아카이브 작성기.
///
/// ## 왜 직접 쓰는가
///
/// `/usr/bin/tar` 는 결정적이지 않다. 파일의 mtime·uid·gid·uname·gname 을 **파일
/// 시스템에서** 읽어 헤더에 싣기 때문에, 같은 팩을 두 머신에서 구우면 다른 바이트가
/// 나온다. 배포 팩의 완료 기준이 "두 번 구운 tar 바이트가 동일" 이므로 그 필드들을
/// 우리가 정해야 하고, 그러면 헤더를 직접 쓰는 것과 같은 일이다. 형식 자체는 512바이트
/// 블록 두 종류뿐이라 의존성을 하나 더 다는 편이 오히려 비싸다.
///
/// ## 무엇을 고정하는가
///
/// | 필드 | 값 | 이유 |
/// |---|---|---|
/// | mtime | `manifest.generatedAt` | 빌드 시각이 아니다. 매니페스트의 입력값이라 재현된다 |
/// | uid·gid | 0 | 굽는 사람의 계정이 아카이브에 남지 않는다 |
/// | uname·gname | 빈 문자열 | 위와 같은 이유 |
/// | mode | 파일 0644 · 디렉터리 0755 | 소스 트리의 실행 비트가 새어 들어오지 않는다 |
/// | 순서 | 경로 사전순 | 디렉터리 순회 순서(파일 시스템 의존)를 쓰지 않는다 |
///
/// gzip 을 걸지 않는 것도 같은 이유다 — gzip 헤더에 압축 시각이 들어간다.
enum TarWriter {
    enum Entry: Sendable {
        case directory(path: String)
        case file(path: String, data: Data)

        var path: String {
            switch self {
            case .directory(let path), .file(let path, _): path
            }
        }
    }

    enum Failure: Error, CustomStringConvertible {
        /// ustar 의 name 필드는 100바이트다. prefix 분할은 구현하지 않았다 —
        /// 팩 경로 규칙(ASCII 영숫자·`.`·`-`·`_`)에서 100자를 넘을 일이 없고,
        /// 넘는다면 조용히 자르는 것보다 거부하는 편이 맞다.
        case pathTooLong(String)
        case pathNotASCII(String)

        var description: String {
            switch self {
            case .pathTooLong(let path):
                "아카이브 경로가 100바이트를 넘는다 (ustar name 필드 한계): \(path)"
            case .pathNotASCII(let path): "아카이브 경로가 ASCII 가 아니다: \(path)"
            }
        }
    }

    static let blockSize = 512

    /// 엔트리들을 하나의 tar 바이트열로. 입력 순서와 무관하게 **경로 사전순**으로 굽는다.
    static func archive(_ entries: [Entry], modificationTime: UInt64) throws(Failure) -> Data {
        var out = Data()
        for entry in entries.sorted(by: { $0.path < $1.path }) {
            switch entry {
            case .directory(let path):
                let name = path.hasSuffix("/") ? path : path + "/"
                out.append(try header(name: name, size: 0, mode: 0o755, type: 0x35, mtime: modificationTime))
            case .file(let path, let data):
                out.append(
                    try header(
                        name: path, size: data.count, mode: 0o644, type: 0x30,
                        mtime: modificationTime))
                out.append(data)
                let remainder = data.count % blockSize
                if remainder != 0 {
                    out.append(Data(repeating: 0, count: blockSize - remainder))
                }
            }
        }
        // 끝 표식은 0으로 채운 블록 둘이다.
        out.append(Data(repeating: 0, count: blockSize * 2))
        return out
    }

    // MARK: - 헤더

    private static func header(
        name: String, size: Int, mode: UInt32, type: UInt8, mtime: UInt64
    ) throws(Failure) -> Data {
        guard let nameBytes = name.data(using: .ascii) else { throw .pathNotASCII(name) }
        guard nameBytes.count <= 100 else { throw .pathTooLong(name) }

        var block = [UInt8](repeating: 0, count: blockSize)
        write(nameBytes, into: &block, at: 0, width: 100)
        write(octal(UInt64(mode), width: 8), into: &block, at: 100, width: 8)
        write(octal(0, width: 8), into: &block, at: 108, width: 8)  // uid
        write(octal(0, width: 8), into: &block, at: 116, width: 8)  // gid
        write(octal(UInt64(size), width: 12), into: &block, at: 124, width: 12)
        write(octal(mtime, width: 12), into: &block, at: 136, width: 12)
        // 체크섬 자리는 계산 동안 공백 8개다 (형식이 그렇게 정의돼 있다).
        for index in 148..<156 { block[index] = 0x20 }
        block[156] = type
        write(Data("ustar".utf8), into: &block, at: 257, width: 6)
        block[263] = 0x30
        block[264] = 0x30
        // uname·gname 은 비운다. 굽는 사람의 계정 이름이 배포물에 남지 않는다.

        let checksum = block.reduce(UInt64(0)) { $0 + UInt64($1) }
        // 6자리 8진수 + NUL + 공백. 마지막 공백은 형식이 요구한다.
        write(octal(checksum, width: 7), into: &block, at: 148, width: 7)
        block[155] = 0x20

        return Data(block)
    }

    /// `width - 1` 자리 8진수 + NUL.
    private static func octal(_ value: UInt64, width: Int) -> Data {
        let digits = String(value, radix: 8)
        let padding = max(0, width - 1 - digits.count)
        return Data((String(repeating: "0", count: padding) + digits + "\0").utf8)
    }

    private static func write(_ data: Data, into block: inout [UInt8], at offset: Int, width: Int) {
        for (index, byte) in data.enumerated() where index < width {
            block[offset + index] = byte
        }
    }
}
