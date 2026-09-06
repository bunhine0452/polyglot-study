public import Foundation

/// 127.0.0.1 에 뜨는 최소 HTTP/1.1 서버.
///
/// 스텁 전송은 ``HTTPTransport`` 경계 위쪽만 검증한다. 이 서버는 그 아래 —
/// `URLSession` 이 실제로 소켓을 열고, 우리가 조립한 헤더가 그대로 전선을 타고,
/// 상태 코드와 `retry-after` 가 진짜 HTTP 프레이밍으로 돌아오는 경로 — 를 검증한다.
/// **실제 OpenRouter 왕복의 대역은 아니다.** 다만 왕복 경로에서 우리가 책임지는 부분을
/// 키 없이 태워 볼 수 있는 가장 가까운 수단이다.
public final class LoopbackHTTPServer: @unchecked Sendable {
    public struct Reply: Sendable {
        public var status: Int
        public var headers: [String: String]
        public var body: Data

        public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
            self.status = status
            self.headers = headers
            self.body = body
        }
    }

    public struct ReceivedRequest: Sendable {
        public var method: String
        public var path: String
        /// 키가 전부 소문자.
        public var headers: [String: String]
        public var body: Data
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private var received: [ReceivedRequest] = []
    private var listenerDescriptor: Int32 = -1
    private var stopped = false

    public private(set) var port: UInt16 = 0

    /// 요청이 올 때마다 앞에서부터 하나씩 돌려준다. 다 쓰면 503.
    public init(replies: [Reply]) {
        self.replies = replies
    }

    public var requests: [ReceivedRequest] {
        lock.withLock { received }
    }

    public var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    public func start() throws {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw LoopbackServerError.socketFailed(errno) }

        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0  // 커널이 빈 포트를 고르게 한다.
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(descriptor)
            throw LoopbackServerError.bindFailed(errno)
        }
        guard listen(descriptor, 8) == 0 else {
            close(descriptor)
            throw LoopbackServerError.listenFailed(errno)
        }

        var bound = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &bound) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &length)
            }
        }
        port = UInt16(bigEndian: bound.sin_port)
        listenerDescriptor = descriptor

        Thread.detachNewThread { [weak self] in
            self?.acceptLoop(descriptor)
        }
    }

    public func stop() {
        let descriptor: Int32 = lock.withLock {
            stopped = true
            let value = listenerDescriptor
            listenerDescriptor = -1
            return value
        }
        if descriptor >= 0 { close(descriptor) }
    }

    private func acceptLoop(_ listener: Int32) {
        while true {
            let connection = accept(listener, nil, nil)
            if connection < 0 {
                if lock.withLock({ stopped }) { return }
                continue
            }
            handle(connection)
            close(connection)
        }
    }

    private func handle(_ connection: Int32) {
        guard let request = readRequest(connection) else { return }
        let reply: Reply = lock.withLock {
            received.append(request)
            guard !replies.isEmpty else {
                return Reply(status: 503, body: Data(#"{"error":{"code":503,"message":"no reply queued"}}"#.utf8))
            }
            return replies.removeFirst()
        }
        write(reply, to: connection)
    }

    private func readRequest(_ connection: Int32) -> ReceivedRequest? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        let terminator = Data("\r\n\r\n".utf8)

        // 헤더 끝까지.
        var headerEnd: Range<Data.Index>?
        while headerEnd == nil {
            let count = read(connection, &chunk, chunk.count)
            guard count > 0 else { return nil }
            buffer.append(contentsOf: chunk[0..<count])
            headerEnd = buffer.range(of: terminator)
        }
        guard let headerEnd else { return nil }

        let headerText = String(decoding: buffer[buffer.startIndex..<headerEnd.lowerBound], as: UTF8.self)
        var lines = headerText.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        // 본문을 Content-Length 만큼.
        var body = Data(buffer[headerEnd.upperBound...])
        let expected = Int(headers["content-length"] ?? "0") ?? 0
        while body.count < expected {
            let count = read(connection, &chunk, chunk.count)
            guard count > 0 else { break }
            body.append(contentsOf: chunk[0..<count])
        }

        return ReceivedRequest(
            method: String(requestLine[0]),
            path: String(requestLine[1]),
            headers: headers,
            body: body
        )
    }

    private func write(_ reply: Reply, to connection: Int32) {
        var head = "HTTP/1.1 \(reply.status) \(Self.reasonPhrase(reply.status))\r\n"
        head += "content-length: \(reply.body.count)\r\n"
        head += "content-type: application/json\r\n"
        head += "connection: close\r\n"
        for (name, value) in reply.headers.sorted(by: { $0.key < $1.key }) {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"

        var payload = Data(head.utf8)
        payload.append(reply.body)
        payload.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let written = Foundation.write(connection, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                if written <= 0 { return }
                offset += written
            }
        }
    }

    private static func reasonPhrase(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 429: "Too Many Requests"
        case 500: "Internal Server Error"
        case 529: "Overloaded"
        default: "Status"
        }
    }
}

public enum LoopbackServerError: Error, Sendable {
    case socketFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
}
