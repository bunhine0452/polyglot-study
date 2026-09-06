public import Foundation

/// LSP 는 stdio 위에서 **`Content-Length` 헤더 + 빈 줄 + JSON 본문**으로 메시지를 나눈다
/// (HTTP 의 base protocol 을 빌려 온 것이다). 줄바꿈은 항상 `\r\n` 이고, 헤더는 대소문자를
/// 구분하지 않는다.
///
/// 이 파일에는 프로세스가 없다. 프레이밍은 바이트 → 메시지 경계 계산일 뿐이라
/// 서버를 띄우지 않고 전부 검증할 수 있어야 한다는 것이 이 저장소의 규약이다.
public enum LSPFraming {
    /// 헤더 끝을 찾기 전에 이만큼 넘게 쌓이면 스트림이 LSP 가 아니라고 판정한다.
    ///
    /// 이게 없으면 헤더 종결자(`\r\n\r\n`)를 영영 못 만나는 스트림에서 버퍼가 무한히
    /// 자란다 — 서버가 크래시 로그를 stdout 으로 뱉는 경우가 실제로 그렇다.
    public static let maximumHeaderBytes = 8 * 1024

    /// 본문 한 덩어리를 전송 가능한 프레임으로 감싼다.
    ///
    /// `Content-Length` 는 **바이트 수**다. 문자 수가 아니다 — 한국어 메시지가 오가는
    /// 이 앱에서 이걸 틀리면 두 번째 메시지부터 통째로 어긋난다.
    public static func frame(_ payload: Data) -> Data {
        var data = Data("Content-Length: \(payload.count)\r\n\r\n".utf8)
        data.append(payload)
        return data
    }
}

public enum LSPFramingError: Error, Hashable, Sendable, CustomStringConvertible {
    case missingContentLength(header: String)
    case invalidContentLength(String)
    case headerTooLarge(bytes: Int)

    public var description: String {
        switch self {
        case .missingContentLength(let header):
            "Content-Length 헤더가 없다: \(header.debugDescription)"
        case .invalidContentLength(let value):
            "Content-Length 값이 정수가 아니다: \(value.debugDescription)"
        case .headerTooLarge(let bytes):
            "헤더 종결자 없이 \(bytes) 바이트가 쌓였다 — LSP 스트림이 아니다."
        }
    }
}

/// 바이트 조각을 계속 먹여 주면 완성된 메시지 본문을 하나씩 돌려주는 증분 디코더.
///
/// 파이프에서 오는 덩어리는 메시지 경계와 아무 상관이 없다. 헤더 중간에서 잘리기도 하고,
/// 한 덩어리에 메시지가 셋 들어 있기도 하다. 그래서 상태를 들고 있는 값 타입이다.
public struct LSPMessageFramer: Sendable {
    private var buffer: Data = Data()

    public init() {}

    /// 아직 소비되지 않은 바이트 수. 테스트가 "다 먹었는지" 를 볼 때 쓴다.
    public var bufferedByteCount: Int { buffer.count }

    public mutating func append(_ bytes: Data) {
        buffer.append(bytes)
    }

    public mutating func append(_ bytes: [UInt8]) {
        buffer.append(contentsOf: bytes)
    }

    /// 완성된 메시지 본문 하나. 아직 모자라면 `nil` — 더 먹여야 한다는 뜻이다.
    ///
    /// 본문은 **선언된 바이트 수만큼 정확히** 잘라낸다. JSON 안에 `\r\n\r\n` 이 들어
    /// 있어도(문자열 리터럴 안의 개행) 경계를 다시 찾지 않기 때문에 안전하다.
    public mutating func nextMessage() throws -> Data? {
        guard let separator = headerTerminatorRange() else {
            guard buffer.count <= LSPFraming.maximumHeaderBytes else {
                throw LSPFramingError.headerTooLarge(bytes: buffer.count)
            }
            return nil
        }

        let headerData = buffer[buffer.startIndex..<separator.lowerBound]
        let header = String(decoding: headerData, as: UTF8.self)

        let contentLength: Int
        do {
            contentLength = try Self.contentLength(in: header)
        } catch {
            // 헤더 블록에 `Content-Length` 가 없다. 프레임이 아닌 바이트가 앞에 섞인
            // 것일 수 있다 — 서버가 stdout 에 로그나 크래시 덤프를 흘리는 경우다.
            //
            // 여기서 그냥 던지면 **세션이 통째로 끝난다.** 실제로는 그 뒤에 멀쩡한
            // 프레임이 이어지는 경우가 대부분이라, 다음 `Content-Length` 로 한 번
            // 재동기화해 본다. 그것도 없으면 진짜 LSP 스트림이 아니므로 던진다.
            guard try resynchronize() else { throw error }
            return try nextMessage()
        }

        let bodyStart = separator.upperBound
        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= contentLength else {
            return nil
        }
        let bodyEnd = buffer.index(bodyStart, offsetBy: contentLength)
        // `Data` 의 슬라이스는 원본 인덱스를 그대로 물려받는다. 0-기반으로 되돌리지
        // 않으면 `JSONDecoder` 에 넘길 때는 문제가 없지만 테스트에서 비교가 어긋난다.
        let body = Data(buffer[bodyStart..<bodyEnd])
        buffer.removeSubrange(buffer.startIndex..<bodyEnd)
        return body
    }

    /// 남은 버퍼에서 뽑을 수 있는 메시지를 전부 뽑는다.
    public mutating func drain() throws -> [Data] {
        var messages: [Data] = []
        while let message = try nextMessage() {
            messages.append(message)
        }
        return messages
    }

    /// 버퍼 앞쪽의 프레임 아닌 바이트를 버리고 다음 `Content-Length` 에 맞춘다.
    ///
    /// - Returns: 버릴 것을 찾아 실제로 버렸으면 `true`. 이 스트림에 `Content-Length`
    ///   자체가 더 없으면 `false` — 그때는 호출자가 원래 오류를 던진다.
    private mutating func resynchronize() throws -> Bool {
        // 대소문자를 가리지 않는 탐색을 `Data` 위에서 하려면 손으로 훑어야 한다.
        // 실제 서버는 전부 정규 표기(`Content-Length`)를 쓰므로 그것만 찾는다 —
        // 못 찾으면 어차피 아래에서 원래 오류가 나간다.
        let needle = Data("Content-Length".utf8)
        // 맨 앞에서 찾으면 그건 방금 실패한 그 헤더다(값이 깨졌다는 뜻) — 무한 재귀가
        // 되지 않도록 **두 번째** 등장부터 본다.
        let searchStart = buffer.index(buffer.startIndex, offsetBy: 1, limitedBy: buffer.endIndex)
            ?? buffer.endIndex
        guard let found = buffer.range(of: needle, in: searchStart..<buffer.endIndex) else {
            return false
        }
        buffer.removeSubrange(buffer.startIndex..<found.lowerBound)
        return true
    }

    private func headerTerminatorRange() -> Range<Data.Index>? {
        let terminator = Data([0x0D, 0x0A, 0x0D, 0x0A])  // \r\n\r\n
        return buffer.range(of: terminator)
    }

    /// 헤더 블록에서 `Content-Length` 를 뽑는다. 필드 이름은 대소문자를 구분하지 않고,
    /// `Content-Type` 같은 다른 헤더는 조용히 무시한다(LSP 스펙이 허용한다).
    static func contentLength(in header: String) throws -> Int {
        // `components(separatedBy:)` 를 쓰는 이유: Swift 에서 `"\r\n"` 은 **Character 하나**라
        // `split(separator:)` 의 두 오버로드(Character / Collection)가 서로 다른 것을
        // 가리킬 수 있다. 이 저장소는 같은 함정을 OpenRouter SSE 파싱에서 이미 밟았다.
        for line in header.components(separatedBy: "\r\n") where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            guard name.lowercased() == "content-length" else { continue }
            let raw = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard let value = Int(raw), value >= 0 else {
                throw LSPFramingError.invalidContentLength(raw)
            }
            return value
        }
        throw LSPFramingError.missingContentLength(header: header)
    }
}
