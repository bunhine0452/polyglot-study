import Foundation

@testable import LSPKit

/// 프로세스 없는 통로. 세션의 모든 계약(상관·취소·알림·서버발 요청)을 여기 위에서
/// 검증한다 — 실제 서버를 띄우는 테스트는 따로 있고, 그쪽은 서버가 없는 머신에서 건너뛴다.
///
/// 두 방향을 모두 관찰할 수 있다:
///   - 세션이 **보낸** 것: `sent` 배열(프레임을 벗긴 JSON 본문, 나간 순서 그대로)
///   - 서버가 **보내는** 것: `deliver(_:)` / `deliverRaw(_:)`
actor FakeLSPTransport: LSPTransport {
    private var inbound: AsyncThrowingStream<[UInt8], any Error>.Continuation?
    private var framer = LSPMessageFramer()

    private(set) var openCount = 0
    private(set) var closeCount = 0
    /// 세션이 보낸 모든 메시지. 순서가 곧 바이트 순서다.
    private(set) var sent: [Data] = []
    /// `write` 가 던지게 만든다. 서버가 죽은 상황을 흉내 낼 때.
    private var writeFailure: (any Error)?
    /// `initialize` 에 자동으로 답한다. `SwiftLanguageService` 를 띄우는 테스트용 —
    /// 세션 자체를 보는 테스트는 응답 내용을 직접 정해야 하므로 기본은 꺼져 있다.
    private let autoAnswerInitialize: Bool

    init(autoAnswerInitialize: Bool = false) {
        self.autoAnswerInitialize = autoAnswerInitialize
    }

    // MARK: - LSPTransport

    func open() async throws -> AsyncThrowingStream<[UInt8], any Error> {
        openCount += 1
        let (stream, continuation) = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        inbound = continuation
        return stream
    }

    func write(_ bytes: [UInt8]) async throws {
        if let writeFailure { throw writeFailure }
        // 세션이 프레이밍까지 해서 준다. 프레임을 벗겨야 테스트가 JSON 을 본다 —
        // 이 왕복 자체가 프레이밍 인코더/디코더의 통합 검증이기도 하다.
        framer.append(bytes)
        for message in try framer.drain() {
            sent.append(message)
            // 진짜 서버는 `shutdown` 에 답한다. 답하지 않으면 세션이 유예 시간만큼
            // 기다리고, 모든 테스트에 그 시간이 그대로 얹힌다.
            if TestJSON.method(message) == LSPMethod.shutdown, let id = TestJSON.id(message) {
                deliver(TestJSON.encode(["jsonrpc": "2.0", "id": id, "result": NSNull()]))
            }
            if autoAnswerInitialize,
               TestJSON.method(message) == LSPMethod.initialize,
               let id = TestJSON.id(message)
            {
                deliver(TestJSON.response(id: id, result: [
                    "capabilities": ["completionProvider": ["triggerCharacters": [".", "("]]],
                ]))
            }
        }
    }

    func close() async {
        closeCount += 1
        inbound?.finish()
    }

    // MARK: - 서버 흉내

    /// 서버가 메시지 하나를 보낸 것으로 만든다.
    func deliver(_ payload: Data) {
        inbound?.yield([UInt8](LSPFraming.frame(payload)))
    }

    /// 프레이밍을 우리가 하지 않고 날바이트를 밀어 넣는다. 조각난 도착·붙은 도착을
    /// 흉내 낼 때.
    func deliverRaw(_ bytes: [UInt8]) {
        inbound?.yield(bytes)
    }

    /// 서버가 죽었다.
    func terminate() {
        inbound?.finish()
    }

    func setWriteFailure(_ error: (any Error)?) {
        writeFailure = error
    }
}

// MARK: - 테스트용 JSON 도우미

/// 어설션에서 JSON 을 사전으로 본다. `Codable` 로 풀면 "서버가 보낸 필드가 실제로
/// 그 이름인가" 를 검증할 수 없다 — 디코더가 조용히 흡수하기 때문이다.
enum TestJSON {
    static func object(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    static func method(_ data: Data) -> String? {
        object(data)["method"] as? String
    }

    static func id(_ data: Data) -> Int? {
        object(data)["id"] as? Int
    }

    static func params(_ data: Data) -> [String: Any] {
        object(data)["params"] as? [String: Any] ?? [:]
    }

    static func encode(_ value: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: value)) ?? Data()
    }

    /// `{"jsonrpc":"2.0","id":<id>,"result":<result>}`
    static func response(id: Int, result: Any) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "result": result])
    }

    static func errorResponse(id: Int, code: Int, message: String) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    static func notification(method: String, params: Any) -> Data {
        encode(["jsonrpc": "2.0", "method": method, "params": params])
    }

    static func serverRequest(id: Int, method: String, params: Any = [String: Any]()) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
    }
}

/// 세션이 보낸 메시지 중 조건을 만족하는 **첫 번째**가 나타날 때까지 기다린다.
///
/// 폴링이다. `AsyncStream` 이터레이터를 테스트끼리 돌려쓰면 누가 무엇을 소비했는지가
/// 흐려지는데, `sent` 는 append-only 배열이라 몇 번을 읽어도 같은 것을 본다.
///
/// 시간 상한은 **관대하게**, 반환값에 대한 단언은 **엄격하게** — 이 저장소의 규칙이다.
/// 상한이 있는 이유는 판정을 시간으로 하기 위해서가 아니라, 실패한 테스트가 영원히
/// 멈추지 않게 하기 위해서다.
func waitForSentMessage(
    on transport: FakeLSPTransport,
    within limit: Duration = .seconds(5),
    matching predicate: @Sendable @escaping (Data) -> Bool
) async -> Data? {
    let deadline = ContinuousClock.now + limit
    while ContinuousClock.now < deadline {
        if let match = await transport.sent.first(where: predicate) { return match }
        try? await Task.sleep(for: .milliseconds(2))
    }
    return await transport.sent.first(where: predicate)
}

/// 특정 메서드의 메시지를 기다린다.
func waitForSentMethod(
    _ method: String,
    on transport: FakeLSPTransport,
    within limit: Duration = .seconds(5)
) async -> Data? {
    await waitForSentMessage(on: transport, within: limit) { TestJSON.method($0) == method }
}
