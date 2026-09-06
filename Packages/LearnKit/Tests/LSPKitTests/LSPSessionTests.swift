import Foundation
import Testing

@testable import LSPKit

@Suite("LSP 세션 — 요청 상관·알림·서버발 요청")
struct LSPSessionCorrelationTests {
    @Test("요청은 프레임으로 나가고 응답은 id 로 되돌아온다")
    func requestAndResponseCorrelate() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.request(
                method: LSPMethod.initialize,
                params: EmptyEncodable(),
                returning: InitializeResult.self
            )
        }

        let sent = await waitForSentMethod(LSPMethod.initialize, on: transport)
        let request = try #require(sent)
        let id = try #require(TestJSON.id(request))
        #expect(TestJSON.object(request)["jsonrpc"] as? String == "2.0")

        await transport.deliver(
            TestJSON.response(id: id, result: [
                "capabilities": ["completionProvider": ["triggerCharacters": [".", "("]]],
                "serverInfo": ["name": "SourceKitLSP"],
            ])
        )

        let result = try await task.value
        #expect(result.capabilities.completionProvider?.triggerCharacters == [".", "("])
        #expect(result.serverInfo?.name == "SourceKitLSP")
        await session.shutdown()
    }

    @Test("요청 id 는 겹치지 않고 응답은 각자 제 짝을 찾는다")
    func concurrentRequestsGetDistinctIDs() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        // 셋을 동시에 띄운다. 세션이 id 할당과 큐 삽입을 한 동기 구간에서 하지 않으면
        // 여기서 같은 번호가 두 번 나가거나 바이트가 섞인다.
        async let first = session.request(method: "a", params: EmptyEncodable())
        async let second = session.request(method: "b", params: EmptyEncodable())
        async let third = session.request(method: "c", params: EmptyEncodable())

        _ = await waitForSentMethod("c", on: transport)
        let requests = await transport.sent
        let ids = requests.compactMap(TestJSON.id)
        #expect(ids.count == 3)
        #expect(Set(ids).count == 3, "id 가 겹쳤다: \(ids)")

        // **거꾸로** 답한다. 도착 순서가 아니라 id 로 짝을 찾는지 보기 위해서다.
        for request in requests.reversed() {
            guard let id = TestJSON.id(request), let method = TestJSON.method(request) else { continue }
            await transport.deliver(TestJSON.response(id: id, result: ["echo": method]))
        }

        let bodies = try await [first, second, third]
        let echoes = bodies.map { (TestJSON.object($0)["result"] as? [String: Any])?["echo"] as? String }
        #expect(echoes == ["a", "b", "c"])
        await session.shutdown()
    }

    @Test("알림은 요청 스트림이 아니라 알림 스트림으로 간다")
    func notificationsGoToTheNotificationStream() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        let collector = Task {
            var seen: [String] = []
            for await notification in session.notifications {
                seen.append(notification.method)
                if seen.count == 2 { break }
            }
            return seen
        }

        await transport.deliver(
            TestJSON.notification(method: LSPMethod.publishDiagnostics, params: [
                "uri": "file:///tmp/a.swift", "diagnostics": [],
            ])
        )
        await transport.deliver(
            TestJSON.notification(method: "window/logMessage", params: ["type": 3, "message": "hi"])
        )

        let seen = await collector.value
        #expect(seen == [LSPMethod.publishDiagnostics, "window/logMessage"])
        await session.shutdown()
    }

    @Test("서버발 요청에는 반드시 답한다 — 모르는 메서드는 MethodNotFound")
    func serverRequestsAlwaysGetAnAnswer() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        await transport.deliver(
            TestJSON.serverRequest(id: 77, method: LSPMethod.registerCapability)
        )
        await transport.deliver(
            TestJSON.serverRequest(id: 78, method: "workspace/applyEdit")
        )

        let known = try #require(
            await waitForSentMessage(on: transport) { TestJSON.id($0) == 77 }
        )
        // 알려진 것은 성공(result: null)으로 답한다.
        #expect(TestJSON.object(known)["error"] == nil)
        #expect(TestJSON.object(known).keys.contains("result"))

        let unknown = try #require(
            await waitForSentMessage(on: transport) { TestJSON.id($0) == 78 }
        )
        let error = try #require(TestJSON.object(unknown)["error"] as? [String: Any])
        #expect(error["code"] as? Int == JSONRPCError.methodNotFound)
        await session.shutdown()
    }

    @Test("서버가 죽으면 대기 중인 요청이 전부 깨어난다 — 영원히 매달리지 않는다")
    func serverDeathWakesEveryPendingRequest() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        let first = Task { try await session.request(method: "a", params: EmptyEncodable()) }
        let second = Task { try await session.request(method: "b", params: EmptyEncodable()) }
        _ = await waitForSentMethod("b", on: transport)

        await transport.terminate()

        await #expect(throws: (any Error).self) { try await first.value }
        await #expect(throws: (any Error).self) { try await second.value }
        await session.shutdown()
    }

    @Test("서버 오류 응답은 오류로 던진다")
    func serverErrorResponsesThrow() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        let task = Task { try await session.request(method: "a", params: EmptyEncodable()) }
        let request = try #require(await waitForSentMethod("a", on: transport))
        let id = try #require(TestJSON.id(request))
        await transport.deliver(TestJSON.errorResponse(id: id, code: -32601, message: "없다"))

        await #expect(throws: JSONRPCError.self) { try await task.value }
        await session.shutdown()
    }
}

@Suite("LSP 세션 — 취소")
struct LSPSessionCancellationTests {
    /// `{#lsp-completion}` 의 완료 기준 절반: "취소 시 요청이 실제로 취소됨".
    ///
    /// **시간이 아니라 구조로 증명한다.**
    ///   1. 요청이 실제로 나갔다.
    ///   2. 취소 뒤 `$/cancelRequest` 가 **같은 id 로** 실제로 나갔다.
    ///   3. 호출자는 값이 아니라 `CancellationError` 를 받는다 — 콜백이 안 불렸다.
    ///   4. 그 뒤 서버가 늦게 응답해도 아무 일도 일어나지 않는다(이중 재개 없음).
    @Test("취소하면 $/cancelRequest 가 같은 id 로 나가고 결과 콜백은 불리지 않는다")
    func cancellationSendsCancelRequestAndNeverDeliversResult() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        let task = Task {
            try await session.request(
                method: LSPMethod.completion,
                params: EmptyEncodable(),
                returning: LSPCompletionResponse.self
            )
        }

        // 1. 요청이 나갔다.
        let request = try #require(await waitForSentMethod(LSPMethod.completion, on: transport))
        let id = try #require(TestJSON.id(request))

        task.cancel()

        // 2. `$/cancelRequest` 가 **같은 id** 로 나갔다.
        let cancel = try #require(await waitForSentMethod(LSPMethod.cancelRequest, on: transport))
        #expect(TestJSON.params(cancel)["id"] as? Int == id)

        // 3. 호출자는 취소를 본다. 값이 아니다.
        await #expect(throws: CancellationError.self) { try await task.value }

        // 4. 늦은 응답이 도착해도 이중 재개가 없다. `pending` 에서 이미 빠졌기 때문에
        //    구조적으로 불가능하고, 세션은 그대로 살아 있어야 한다.
        await transport.deliver(
            TestJSON.response(id: id, result: ["isIncomplete": false, "items": []])
        )

        let followUp = Task { try await session.request(method: "after", params: EmptyEncodable()) }
        let second = try #require(await waitForSentMethod("after", on: transport))
        let secondID = try #require(TestJSON.id(second))
        #expect(secondID != id)
        await transport.deliver(TestJSON.response(id: secondID, result: ["ok": true]))
        _ = try await followUp.value

        await session.shutdown()
    }

    @Test("이미 끝난 요청을 취소해도 $/cancelRequest 는 나가지 않는다")
    func completedRequestsAreNotCancelled() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        let task = Task { try await session.request(method: "a", params: EmptyEncodable()) }
        let request = try #require(await waitForSentMethod("a", on: transport))
        let id = try #require(TestJSON.id(request))
        await transport.deliver(TestJSON.response(id: id, result: ["ok": true]))
        _ = try await task.value

        // 끝난 뒤의 취소는 아무 의미가 없다. 서버가 모르는 id 로 취소가 나가면
        // 서버 로그가 오염되고, 우리 쪽에는 유령 id 가 쌓인다.
        task.cancel()
        try? await Task.sleep(for: .milliseconds(50))
        let cancels = await transport.sent.filter { TestJSON.method($0) == LSPMethod.cancelRequest }
        #expect(cancels.isEmpty)
        await session.shutdown()
    }

    @Test("서버가 -32800 으로 답하면 오류가 아니라 취소로 본다")
    func requestCancelledErrorCodeBecomesCancellation() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        let task = Task { try await session.request(method: "a", params: EmptyEncodable()) }
        let request = try #require(await waitForSentMethod("a", on: transport))
        let id = try #require(TestJSON.id(request))
        // 실측: sourcekit-lsp 가 `$/cancelRequest` 를 받으면 이렇게 답한다.
        await transport.deliver(
            TestJSON.errorResponse(id: id, code: JSONRPCError.requestCancelled,
                                   message: "request cancelled by client")
        )

        await #expect(throws: CancellationError.self) { try await task.value }
        await session.shutdown()
    }

    @Test("등록보다 취소가 먼저 도착해도 세션은 멀쩡하다")
    func cancellationBeforeRegistrationIsSafe() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        // 본문이 돌기 전에 취소한다. 어느 쪽이 액터에 먼저 들어가는지는 보장되지
        // 않으므로 "둘 다 옳다" 를 단언한다 — 시간에 기대는 단언을 만들지 않는다.
        let task = Task { try await session.request(method: "early", params: EmptyEncodable()) }
        task.cancel()
        await #expect(throws: (any Error).self) { try await task.value }

        // 어느 경로였든 세션은 다음 요청을 정상으로 처리해야 한다. 이게 진짜 단언이다.
        let followUp = Task { try await session.request(method: "after", params: EmptyEncodable()) }
        let second = try #require(await waitForSentMethod("after", on: transport))
        let id = try #require(TestJSON.id(second))
        await transport.deliver(TestJSON.response(id: id, result: ["ok": true]))
        _ = try await followUp.value
        await session.shutdown()
    }
}

@Suite("LSP 세션 — 나가는 순서")
struct LSPSessionOrderingTests {
    /// 이 저장소가 세 번 밟은 함정의 이 버전: 액터 메서드 안에서 `await` 하면 재진입이
    /// 허용돼 알림 순서가 뒤집힌다. `didOpen` 뒤에 `didChange` 가 와야 하고 버전은
    /// 단조 증가해야 한다.
    @Test("알림은 부른 순서 그대로 나간다")
    func notificationsKeepCallOrder() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        for index in 0..<50 {
            session.notify(method: "n\(index)", params: EmptyEncodable())
        }
        _ = await waitForSentMethod("n49", on: transport)

        let methods = await transport.sent.compactMap(TestJSON.method)
        #expect(methods == (0..<50).map { "n\($0)" })
        await session.shutdown()
    }

    @Test("요청과 알림이 섞여도 순서가 유지된다")
    func requestsAndNotificationsInterleaveInOrder() async throws {
        let transport = FakeLSPTransport()
        let session = LSPSession(transport: transport)
        try await session.start()

        session.notify(method: "open", params: EmptyEncodable())
        let task = Task { try await session.request(method: "ask", params: EmptyEncodable()) }
        _ = await waitForSentMethod("ask", on: transport)
        session.notify(method: "change", params: EmptyEncodable())
        _ = await waitForSentMethod("change", on: transport)

        let methods = await transport.sent.compactMap(TestJSON.method)
        #expect(methods == ["open", "ask", "change"])

        let request = try #require(await transport.sent.first { TestJSON.method($0) == "ask" })
        await transport.deliver(TestJSON.response(id: TestJSON.id(request) ?? 0, result: ["ok": true]))
        _ = try await task.value
        await session.shutdown()
    }
}

/// `params` 가 필요 없는 요청용.
struct EmptyEncodable: Encodable, Sendable {}
