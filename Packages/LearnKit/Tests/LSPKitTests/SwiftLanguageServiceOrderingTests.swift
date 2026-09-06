import Foundation
import Testing

@testable import LSPKit

/// 문서 동기화의 순서 계약. **프로세스가 없다.**
///
/// 이 스위트가 존재하는 이유: 리뷰에서 실제로 깨져 있던 자리다. `documentVersion += 1`
/// 다음 줄이 `await session.notify(...)` 였고, `notify` 가 액터 격리 메서드라 그 사이에
/// 액터 홉이라는 중단점이 있었다. 키 입력마다 새 태스크가 뜨는 화면 배선과 만나면
/// 버전 3 이 버전 2 보다 먼저 나갈 수 있었고, **그 상태는 스스로 낫지 않는다** —
/// 서비스가 최신 본문을 이미 보냈다고 믿어 다시 보내지 않기 때문이다.
@Suite("Swift 언어 서비스 — 문서 동기화 순서")
struct SwiftLanguageServiceOrderingTests {
    static func makeService() -> (SwiftLanguageService, FakeLSPTransport) {
        let transport = FakeLSPTransport(autoAnswerInitialize: true)
        let service = SwiftLanguageService(
            session: LSPSession(transport: transport),
            workspaceRoot: URL(fileURLWithPath: "/tmp/learnkit-ordering-test")
        )
        return (service, transport)
    }

    static func didChanges(_ transport: FakeLSPTransport) async -> [(version: Int, text: String)] {
        await transport.sent
            .filter { TestJSON.method($0) == LSPMethod.didChange }
            .compactMap { message in
                let params = TestJSON.params(message)
                guard let document = params["textDocument"] as? [String: Any],
                      let version = document["version"] as? Int,
                      let changes = params["contentChanges"] as? [[String: Any]],
                      let text = changes.first?["text"] as? String
                else { return nil }
                return (version, text)
            }
    }

    @Test("didOpen 뒤 didChange 가 오고 버전이 단조 증가한다")
    func versionsAreMonotonic() async throws {
        let (service, transport) = Self.makeService()
        try await service.start()
        await service.openDocument(fileName: "Solution.swift", text: "v1")

        for index in 2...6 {
            await service.updateDocument(text: "v\(index)", editSequence: index)
        }
        _ = await waitForSentMessage(on: transport) {
            (TestJSON.params($0)["contentChanges"] as? [[String: Any]])?.first?["text"] as? String == "v6"
        }

        let methods = await transport.sent.compactMap(TestJSON.method)
        #expect(methods.first == LSPMethod.initialize)
        // didOpen 이 didChange 보다 먼저다 — 뒤집히면 서버가 문서를 모른다.
        let openIndex = try #require(methods.firstIndex(of: LSPMethod.didOpen))
        let firstChange = try #require(methods.firstIndex(of: LSPMethod.didChange))
        #expect(openIndex < firstChange)

        let changes = await Self.didChanges(transport)
        #expect(changes.map(\.version) == [2, 3, 4, 5, 6])
        #expect(changes.map(\.text) == ["v2", "v3", "v4", "v5", "v6"])
        await service.shutdown()
    }

    /// **핵심 회귀 테스트.** 순번이 거꾸로 도착해도 낡은 본문이 최신을 덮어쓰지 않는다.
    @Test("늦게 도착한 낡은 편집은 버려진다 — 최신 본문이 이긴다")
    func staleEditsAreDropped() async throws {
        let (service, transport) = Self.makeService()
        try await service.start()
        await service.openDocument(fileName: "Solution.swift", text: "v1")

        // 화면이 매긴 순번은 5 → 4 순으로 도착했다(액터 홉의 도착 순서는 보장되지 않는다).
        await service.updateDocument(text: "최신", editSequence: 5)
        await service.updateDocument(text: "낡음", editSequence: 4)
        _ = await waitForSentMethod(LSPMethod.didChange, on: transport)

        let changes = await Self.didChanges(transport)
        // 낡은 것은 아예 나가지 않았다.
        #expect(changes.count == 1)
        #expect(changes.first?.text == "최신")
        // 서버가 최신 본문을 들고 있다.
        #expect(await service.documentTextForTesting == "최신")
        await service.shutdown()
    }

    @Test("같은 순번이 두 번 와도 한 번만 나간다")
    func duplicateSequenceIsIgnored() async throws {
        let (service, transport) = Self.makeService()
        try await service.start()
        await service.openDocument(fileName: "Solution.swift", text: "v1")

        await service.updateDocument(text: "a", editSequence: 2)
        await service.updateDocument(text: "b", editSequence: 2)
        _ = await waitForSentMethod(LSPMethod.didChange, on: transport)

        let changes = await Self.didChanges(transport)
        #expect(changes.map(\.text) == ["a"])
        await service.shutdown()
    }

    @Test("본문이 그대로면 아무것도 보내지 않는다")
    func unchangedTextSendsNothing() async throws {
        let (service, transport) = Self.makeService()
        try await service.start()
        await service.openDocument(fileName: "Solution.swift", text: "같은 본문")

        await service.updateDocument(text: "같은 본문", editSequence: 2)
        await service.updateDocument(text: "다른 본문", editSequence: 3)
        _ = await waitForSentMethod(LSPMethod.didChange, on: transport)

        let changes = await Self.didChanges(transport)
        #expect(changes.map(\.text) == ["다른 본문"])
        // 버전은 실제로 보낸 횟수만큼만 오른다.
        #expect(changes.map(\.version) == [2])
        await service.shutdown()
    }

    /// `notify` 가 **동기 함수**라는 것 자체가 계약이다. async 로 되돌리면 호출자에
    /// 중단점이 생기고 위 순서 보장이 무너진다.
    @Test("notify 는 중단점을 만들지 않는다 — 한 동기 구간에서 50개가 순서대로 나간다")
    func notifyIsSynchronous() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        // `await` 없이 부른다. 컴파일되는 것 자체가 이 계약의 증거다.
        for index in 0..<50 {
            session.notify(method: "n\(index)", params: EmptyEncodable())
        }
        _ = await waitForSentMethod("n49", on: transport)
        let methods = await transport.sent.compactMap(TestJSON.method)
        #expect(methods == (0..<50).map { "n\($0)" })
        await session.shutdown()
    }
}

@Suite("LSP 세션 — 시작 전후")
struct LSPSessionLifecycleTests {
    /// 작성자 태스크는 `start()` 에서 만들어진다. 그 전에 큐에 넣으면 아무도 빼 가지
    /// 않으므로, 던지지 않으면 호출자가 **영원히** 매달린다.
    @Test("시작 전 요청은 매달리지 않고 던진다")
    func requestBeforeStartThrows() async throws {
        let session = LSPSession(transport: FakeLSPTransport())
        await #expect(throws: LSPSessionError.self) {
            _ = try await session.request(method: "a", params: EmptyEncodable())
        }
    }

    @Test("시작하지 않은 세션도 종료할 수 있다")
    func shutdownWithoutStartIsSafe() async {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        await session.shutdown()
        #expect(await transport.closeCount == 1)
    }

    @Test("두 번 시작하면 던진다")
    func startingTwiceThrows() async throws {
        let session = LSPSession(transport: FakeLSPTransport())
        try await session.start()
        await #expect(throws: LSPSessionError.self) { try await session.start() }
        await session.shutdown()
    }
}
