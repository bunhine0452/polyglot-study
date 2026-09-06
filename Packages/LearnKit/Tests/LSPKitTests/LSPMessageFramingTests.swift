import Foundation
import Testing

@testable import LSPKit

@Suite("LSP 프레이밍 — Content-Length")
struct LSPMessageFramingTests {
    static func bytes(_ text: String) -> [UInt8] { [UInt8](Data(text.utf8)) }

    @Test("프레임을 만들면 바이트 수가 헤더에 들어간다")
    func frameCarriesByteCount() {
        let payload = Data(#"{"a":1}"#.utf8)
        let framed = LSPFraming.frame(payload)
        #expect(String(decoding: framed, as: UTF8.self) == "Content-Length: 7\r\n\r\n{\"a\":1}")
    }

    @Test("Content-Length 는 문자 수가 아니라 바이트 수다")
    func contentLengthCountsBytesNotCharacters() throws {
        // 한국어 6글자 = UTF-8 18바이트. 문자 수로 세면 두 번째 메시지부터 어긋난다.
        let payload = Data(#"{"m":"안녕하세요네"}"#.utf8)
        #expect(payload.count > 15)
        let framed = LSPFraming.frame(payload)

        var framer = LSPMessageFramer()
        framer.append(framed)
        let decoded = try #require(try framer.nextMessage())
        #expect(decoded == payload)
        #expect(framer.bufferedByteCount == 0)
    }

    @Test("한 덩어리에 메시지가 여럿이면 전부 뽑는다")
    func multipleMessagesInOneChunk() throws {
        var buffer = Data()
        for index in 0..<3 {
            buffer.append(LSPFraming.frame(Data(#"{"i":\#(index)}"#.utf8)))
        }
        var framer = LSPMessageFramer()
        framer.append(buffer)
        let messages = try framer.drain()
        #expect(messages.count == 3)
        #expect(String(decoding: messages[2], as: UTF8.self) == #"{"i":2}"#)
    }

    @Test("한 바이트씩 먹여도 경계를 정확히 찾는다")
    func byteByByteDeliveryStillFindsBoundaries() throws {
        let first = LSPFraming.frame(Data(#"{"a":1}"#.utf8))
        let second = LSPFraming.frame(Data(#"{"b":2}"#.utf8))
        var stream = Data()
        stream.append(first)
        stream.append(second)

        var framer = LSPMessageFramer()
        var messages: [Data] = []
        for byte in stream {
            framer.append(Data([byte]))
            while let message = try framer.nextMessage() { messages.append(message) }
        }
        #expect(messages.count == 2)
        #expect(String(decoding: messages[0], as: UTF8.self) == #"{"a":1}"#)
        #expect(String(decoding: messages[1], as: UTF8.self) == #"{"b":2}"#)
    }

    @Test("헤더가 중간에서 잘려 도착해도 기다린다")
    func splitHeaderWaitsForMore() throws {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes("Content-Le"))
        #expect(try framer.nextMessage() == nil)
        framer.append(Self.bytes("ngth: 7\r\n"))
        #expect(try framer.nextMessage() == nil)
        framer.append(Self.bytes("\r\n{\"a\":1}"))
        let message = try #require(try framer.nextMessage())
        #expect(String(decoding: message, as: UTF8.self) == #"{"a":1}"#)
    }

    @Test("본문이 모자라면 nil 이고 버퍼는 그대로 남는다")
    func partialBodyIsNotConsumed() throws {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes("Content-Length: 7\r\n\r\n{\"a\":"))
        #expect(try framer.nextMessage() == nil)
        #expect(framer.bufferedByteCount > 0)
        framer.append(Self.bytes("1}"))
        #expect(try framer.nextMessage() != nil)
    }

    /// 본문 안에 헤더 종결자와 같은 바이트열이 들어 있어도 경계를 다시 찾지 않는다 —
    /// 선언된 길이만큼 정확히 잘라내기 때문이다.
    @Test("본문 안의 \\r\\n\\r\\n 이 경계로 오인되지 않는다")
    func crlfInsideBodyIsNotABoundary() throws {
        // **진짜 CR LF 바이트**여야 의미가 있다. 원시 문자열 안의 `\r\n` 은 역슬래시와
        // r 두 글자라 이 함정을 전혀 건드리지 못한다.
        let payload = Data(("{\"m\":\"a" + "\r\n\r\n" + "b\"}").utf8)
        #expect(payload.contains(0x0D))
        var framer = LSPMessageFramer()
        framer.append(LSPFraming.frame(payload))
        let message = try #require(try framer.nextMessage())
        #expect(message == payload)
        #expect(framer.bufferedByteCount == 0)
    }

    @Test("Content-Type 같은 다른 헤더는 무시한다")
    func extraHeadersAreIgnored() throws {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes(
            "Content-Type: application/vscode-jsonrpc; charset=utf-8\r\nContent-Length: 7\r\n\r\n{\"a\":1}"
        ))
        let message = try #require(try framer.nextMessage())
        #expect(String(decoding: message, as: UTF8.self) == #"{"a":1}"#)
    }

    @Test("헤더 이름의 대소문자는 상관없다")
    func headerNameIsCaseInsensitive() throws {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes("content-length: 7\r\n\r\n{\"a\":1}"))
        #expect(try framer.nextMessage() != nil)
    }

    @Test("Content-Length 가 아예 없으면 던진다")
    func missingContentLengthThrows() {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes("Content-Type: text/plain\r\n\r\n{}"))
        #expect(throws: LSPFramingError.self) { try framer.nextMessage() }
    }

    /// 서버가 stdout 으로 로그나 크래시 덤프를 흘리면 그 앞부분이 헤더 블록으로
    /// 빨려 들어간다. 거기서 그냥 던지면 **세션이 통째로 끝난다** — 뒤에 멀쩡한
    /// 프레임이 이어져 있어도.
    @Test("프레임 앞의 잡음을 건너뛰고 다음 메시지를 찾는다")
    func resynchronizesPastGarbage() throws {
        var framer = LSPMessageFramer()
        var stream = Data("warning: something happened\nnot a frame at all\n".utf8)
        stream.append(LSPFraming.frame(Data(#"{"ok":1}"#.utf8)))
        framer.append(stream)

        let message = try #require(try framer.nextMessage())
        #expect(String(decoding: message, as: UTF8.self) == #"{"ok":1}"#)
        #expect(framer.bufferedByteCount == 0)
    }

    @Test("재동기화 뒤에도 이어지는 메시지를 계속 읽는다")
    func keepsReadingAfterResynchronization() throws {
        var framer = LSPMessageFramer()
        var stream = Data("junk\n".utf8)
        stream.append(LSPFraming.frame(Data(#"{"a":1}"#.utf8)))
        stream.append(LSPFraming.frame(Data(#"{"b":2}"#.utf8)))
        framer.append(stream)

        let messages = try framer.drain()
        #expect(messages.count == 2)
        #expect(String(decoding: messages[1], as: UTF8.self) == #"{"b":2}"#)
    }

    /// 재동기화가 무한 재귀가 되면 안 된다 — 값이 깨진 헤더는 **던져야** 한다.
    @Test("Content-Length 값이 깨졌는데 뒤에 아무것도 없으면 던진다")
    func brokenContentLengthWithNothingAfterThrows() {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes("Content-Length: nope\r\n\r\n{}"))
        #expect(throws: LSPFramingError.self) { try framer.nextMessage() }
    }

    @Test("Content-Length 가 정수가 아니면 던진다")
    func nonNumericContentLengthThrows() {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes("Content-Length: many\r\n\r\n{}"))
        #expect(throws: LSPFramingError.self) { try framer.nextMessage() }
    }

    /// 서버가 stdout 으로 크래시 로그를 뱉으면 헤더 종결자가 영영 안 온다.
    /// 상한이 없으면 버퍼가 무한히 자란다.
    @Test("헤더 종결자 없이 상한을 넘으면 던진다 — 무한 버퍼링 금지")
    func runawayHeaderThrows() {
        var framer = LSPMessageFramer()
        framer.append([UInt8](repeating: 0x41, count: LSPFraming.maximumHeaderBytes + 1))
        #expect(throws: LSPFramingError.self) { try framer.nextMessage() }
    }

    @Test("길이 0 짜리 본문도 메시지다")
    func zeroLengthBodyIsAMessage() throws {
        var framer = LSPMessageFramer()
        framer.append(Self.bytes("Content-Length: 0\r\n\r\n"))
        let message = try #require(try framer.nextMessage())
        #expect(message.isEmpty)
    }

    @Test("프레임 왕복 — 인코더가 만든 것을 디코더가 그대로 되돌린다")
    func roundTrip() throws {
        let payloads = [
            Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#.utf8),
            Data(#"{"message":"'self' 는 불변입니다"}"#.utf8),
            Data("{}".utf8),
        ]
        var stream = Data()
        for payload in payloads { stream.append(LSPFraming.frame(payload)) }

        var framer = LSPMessageFramer()
        framer.append(stream)
        let messages = try framer.drain()
        #expect(messages == payloads)
    }
}
