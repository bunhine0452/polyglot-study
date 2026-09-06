import Foundation
import Testing

@testable import LSPKit

@Suite("JSON-RPC — 분류")
struct JSONRPCClassificationTests {
    @Test("id 만 있고 result 가 있으면 응답이다")
    func responseIsClassifiedByID() throws {
        let payload = Data(#"{"jsonrpc":"2.0","id":1,"result":{"ok":true}}"#.utf8)
        guard case .response(let id, let body) = try JSONRPCDecoder.classify(payload) else {
            Issue.record("응답으로 분류되지 않았다"); return
        }
        #expect(id == .number(1))
        #expect(body == payload)
    }

    @Test("result 가 null 이어도 성공 응답이다 — shutdown 이 그렇게 답한다")
    func nullResultIsStillAResponse() throws {
        let payload = Data(#"{"jsonrpc":"2.0","id":9,"result":null}"#.utf8)
        guard case .response(let id, _) = try JSONRPCDecoder.classify(payload) else {
            Issue.record("응답으로 분류되지 않았다"); return
        }
        #expect(id == .number(9))
    }

    @Test("error 가 있으면 실패 응답이다")
    func errorIsClassifiedAsFailure() throws {
        let payload = Data(
            #"{"jsonrpc":"2.0","id":3,"error":{"code":-32800,"message":"request cancelled by client"}}"#.utf8
        )
        guard case .failure(let id, let error) = try JSONRPCDecoder.classify(payload) else {
            Issue.record("실패로 분류되지 않았다"); return
        }
        #expect(id == .number(3))
        #expect(error.code == JSONRPCError.requestCancelled)
        #expect(error.isCancellation)
    }

    @Test("contentModified 도 취소로 친다")
    func contentModifiedIsCancellation() {
        #expect(JSONRPCError(code: JSONRPCError.contentModified, message: "").isCancellation)
        #expect(!JSONRPCError(code: -32601, message: "").isCancellation)
    }

    @Test("id 없이 method 만 있으면 알림이다")
    func notificationIsClassifiedByMissingID() throws {
        let payload = Data(
            #"{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"file:///a"}}"#.utf8
        )
        guard case .notification(let method, _) = try JSONRPCDecoder.classify(payload) else {
            Issue.record("알림으로 분류되지 않았다"); return
        }
        #expect(method == LSPMethod.publishDiagnostics)
    }

    @Test("id 와 method 가 둘 다 있으면 서버발 요청이다")
    func serverRequestHasBothIDAndMethod() throws {
        let payload = Data(
            #"{"jsonrpc":"2.0","id":"reg-1","method":"client/registerCapability","params":{}}"#.utf8
        )
        guard case .serverRequest(let id, let method, _) = try JSONRPCDecoder.classify(payload) else {
            Issue.record("서버발 요청으로 분류되지 않았다"); return
        }
        // **문자열 id 다.** 우리가 만드는 것은 정수뿐이지만 받는 쪽은 둘 다 받아야 한다.
        #expect(id == .string("reg-1"))
        #expect(method == LSPMethod.registerCapability)
    }

    @Test("id 도 method 도 없으면 던진다")
    func unclassifiableThrows() {
        #expect(throws: JSONRPCDecodingError.self) {
            try JSONRPCDecoder.classify(Data(#"{"jsonrpc":"2.0"}"#.utf8))
        }
    }

    @Test("JSON 이 아니면 던진다 — 서버가 stdout 에 로그를 뱉는 경우")
    func nonJSONThrows() {
        #expect(throws: JSONRPCDecodingError.self) {
            try JSONRPCDecoder.classify(Data("Fatal error: unexpectedly found nil".utf8))
        }
    }
}

@Suite("JSON-RPC — 인코딩과 결과 추출")
struct JSONRPCEncodingTests {
    struct Params: Encodable, Sendable {
        var name: String
        var count: Int
    }

    @Test("요청에는 jsonrpc·id·method·params 가 전부 들어간다")
    func requestCarriesEveryField() throws {
        let data = try JSONRPCEncoder.request(id: .number(4), method: "a/b", params: Params(name: "x", count: 2))
        let object = TestJSON.object(data)
        #expect(object["jsonrpc"] as? String == "2.0")
        #expect(object["id"] as? Int == 4)
        #expect(object["method"] as? String == "a/b")
        #expect((object["params"] as? [String: Any])?["name"] as? String == "x")
    }

    @Test("알림에는 id 가 없다 — 있으면 서버가 응답을 기다린다")
    func notificationHasNoID() throws {
        let data = try JSONRPCEncoder.notification(method: "n", params: Params(name: "x", count: 1))
        #expect(TestJSON.object(data)["id"] == nil)
        #expect(TestJSON.object(data)["method"] as? String == "n")
    }

    @Test("null 응답은 result 키를 실제로 담는다 — 키가 빠지면 응답이 아니다")
    func nullResponseKeepsTheResultKey() throws {
        let data = try JSONRPCEncoder.nullResponse(id: .number(7))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"result\":null"))
        // 왕복으로도 확인한다.
        guard case .response = try JSONRPCDecoder.classify(data) else {
            Issue.record("응답으로 되돌아오지 않았다"); return
        }
    }

    @Test("오류 응답은 실패로 되돌아온다")
    func errorResponseRoundTrips() throws {
        let data = try JSONRPCEncoder.errorResponse(
            id: .number(5), error: JSONRPCError(code: -32601, message: "없다")
        )
        guard case .failure(_, let error) = try JSONRPCDecoder.classify(data) else {
            Issue.record("실패로 되돌아오지 않았다"); return
        }
        #expect(error.code == -32601)
        #expect(error.message == "없다")
    }

    @Test("result 를 타입으로 꺼낸다")
    func resultIsExtractedByType() throws {
        let payload = Data(
            #"{"jsonrpc":"2.0","id":1,"result":{"capabilities":{"completionProvider":{"triggerCharacters":[".","("]}}}}"#.utf8
        )
        let result = try JSONRPCDecoder.result(InitializeResult.self, from: payload)
        #expect(result.capabilities.completionProvider?.triggerCharacters == [".", "("])
    }

    @Test("params 를 타입으로 꺼낸다")
    func paramsAreExtractedByType() throws {
        let payload = Data(
            #"{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"file:///a.swift","diagnostics":[]}}"#.utf8
        )
        let params = try JSONRPCDecoder.params(PublishDiagnosticsParams.self, from: payload)
        #expect(params.uri == "file:///a.swift")
        #expect(params.diagnostics.isEmpty)
    }

    @Test("id 는 정수와 문자열 양쪽으로 왕복한다")
    func idRoundTripsBothShapes() throws {
        for id in [JSONRPCID.number(12), JSONRPCID.string("abc")] {
            let data = try JSONRPCEncoder.request(id: id, method: "m")
            guard case .serverRequest(let decoded, _, _) = try JSONRPCDecoder.classify(data) else {
                Issue.record("분류 실패"); return
            }
            #expect(decoded == id)
        }
    }
}
