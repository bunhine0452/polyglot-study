import Foundation
import LanguageKit
import LearnCore
import LSPKit
import Testing

@testable import EditorFeature

/// 대본대로 답하는 언어 서버. **프로세스가 없다.**
///
/// `LSPKitTests` 의 가짜 통로와 목적이 다르다. 저쪽은 세션의 계약(상관·취소·순서)을
/// 증명하고, 이쪽은 "서버가 진단을 보내면 화면의 인라인 진단 행까지 실제로 도달하는가"
/// 하나만 본다 — 그래서 `initialize` 에만 답하고 나머지는 테스트가 밀어 넣는다.
actor ScriptedLanguageServer: LSPTransport {
    private var inbound: AsyncThrowingStream<[UInt8], any Error>.Continuation?
    private var framer = LSPMessageFramer()
    /// 서버가 광고할 트리거 문자.
    private let triggerCharacters: [String]
    /// 열자마자 죽는다. "떠 있는데 initialize 전에 죽는" 경우를 재현한다.
    private let diesOnOpen: Bool
    /// `close()` 가 몇 번 불렸는가. 잔존 프로세스가 없는지 보는 통로다.
    private(set) var closeCount = 0

    init(triggerCharacters: [String] = [".", "("], diesOnOpen: Bool = false) {
        self.triggerCharacters = triggerCharacters
        self.diesOnOpen = diesOnOpen
    }

    func open() async throws -> AsyncThrowingStream<[UInt8], any Error> {
        let (stream, continuation) = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        inbound = continuation
        if diesOnOpen { continuation.finish() }
        return stream
    }

    func write(_ bytes: [UInt8]) async throws {
        framer.append(bytes)
        for message in try framer.drain() {
            guard let object = try? JSONSerialization.jsonObject(with: message) as? [String: Any],
                  let id = object["id"]
            else { continue }
            switch object["method"] as? String {
            case "initialize":
                send([
                    "jsonrpc": "2.0", "id": id,
                    "result": ["capabilities": ["completionProvider": [
                        "triggerCharacters": triggerCharacters,
                    ]]],
                ])
            case "shutdown":
                send(["jsonrpc": "2.0", "id": id, "result": NSNull()])
            default:
                break
            }
        }
    }

    func close() async {
        closeCount += 1
        inbound?.finish()
    }

    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        inbound?.yield([UInt8](LSPFraming.frame(data)))
    }

    /// 서버가 진단을 보낸 것으로 만든다.
    func publishDiagnostics(uri: String, diagnostics: [[String: Any]]) {
        send([
            "jsonrpc": "2.0", "method": "textDocument/publishDiagnostics",
            "params": ["uri": uri, "diagnostics": diagnostics],
        ])
    }

    static func diagnostic(line: Int, character: Int, severity: Int, message: String) -> [String: Any] {
        [
            "severity": severity,
            "message": message,
            "source": "SourceKit",
            "range": [
                "start": ["line": line, "character": character],
                "end": ["line": line, "character": character + 1],
            ],
        ]
    }
}

/// 이 머신에 `sourcekit-lsp` 가 있는가. `.enabled(if:)` 가 동기 판정을 요구해서
/// `SourceKitLSPLocator`(async) 대신 여기서 한 번만 같은 것을 본다.
/// `nonisolated` — 이 테스트 타깃의 기본 격리는 `MainActor` 다(`Package.swift` 의
/// `uiSettings`). `@Test(.enabled(if:))` 는 격리 밖에서 이 값을 읽으므로 표시가 없으면
/// 컴파일되지 않는다. `LessonFeatureTests.RepoPaths` 가 같은 이유로 `nonisolated` 다.
nonisolated enum RealLanguageServer {
    static let available: Bool = {
        if ProcessInfo.processInfo.environment["LEARNKIT_SKIP_LSP"] != nil { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--find", "sourcekit-lsp"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return false }
        let path = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return FileManager.default.isExecutableFile(atPath: path)
    }()
}

@Suite("`{#lsp-diagnostics}` · 서버 진단이 화면까지 도달한다", .serialized)
struct EditorLanguageSupportTests {
    static let starter = "struct Counter {\n    var count = 0\n    func increment() {\n        count += 1\n    }\n}\n"

    /// 임시 워크스페이스 하나와 그 안의 문서 URI. 서버가 진단을 어느 URI 로 보낼지
    /// 알아야 해서 테스트가 직접 만든다.
    static func makeWorkspace() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("editor-lsp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// 모델의 진단 행이 조건을 만족할 때까지 기다린다. 서버 → 세션 → 지원 객체 →
    /// 모델까지 여러 태스크 경계를 건너므로 즉시 도달하지 않는다.
    ///
    /// 상한은 관대하게 — 판정은 행의 **내용**으로 한다.
    static func waitForRows(
        on model: EditorModel,
        within limit: Duration = .seconds(10),
        where predicate: ([InlineDiagnosticRow]) -> Bool
    ) async -> [InlineDiagnosticRow] {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if predicate(model.diagnosticRows) { return model.diagnosticRows }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return model.diagnosticRows
    }

    @Test("publishDiagnostics 가 인라인 진단 행이 된다 — 라벨이 sourcekit-lsp 다")
    func serverDiagnosticsBecomeInlineRows() async throws {
        let root = try Self.makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ScriptedLanguageServer()
        let service = SwiftLanguageService(session: LSPSession(transport: server), workspaceRoot: root)

        let model = EditorModel(task: SampleTask.swift(starter: Self.starter))
        await model.startLanguageSupport(serviceFactory: { service })
        #expect(model.languageSupport?.status == .ready)
        // 서버가 광고한 트리거 문자가 그대로 올라왔다 — 편집기 설정으로 넘어가는 값이다.
        #expect(model.languageSupport?.triggerCharacters == [".", "("])

        let uri = LSPDiagnosticMapping.uri(forPath: root.appendingPathComponent("main.swift").path)
        await server.publishDiagnostics(uri: uri, diagnostics: [
            ScriptedLanguageServer.diagnostic(
                line: 3, character: 8, severity: 1, message: "'self' 는 불변이라 대입할 수 없습니다."
            )
        ])

        let rows = await Self.waitForRows(on: model) { !$0.isEmpty }
        #expect(rows.count == 1)
        #expect(rows[0].line == 4)
        #expect(rows[0].column == 9)
        #expect(rows[0].codeLine == "        count += 1")
        #expect(rows[0].severity == .error)
        #expect(rows[0].locationLabel == "4행 9열 · sourcekit-lsp · 1개")

        await model.stopLanguageSupport()
    }

    /// 완료 기준 그대로: **같은 컴포넌트, 라벨로만 구분.**
    @Test("서버 진단과 swiftc 진단이 한 목록에 섞이고 라벨로만 구분된다")
    func serverAndCompilerDiagnosticsShareTheList() async throws {
        let root = try Self.makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ScriptedLanguageServer()
        let service = SwiftLanguageService(session: LSPSession(transport: server), workspaceRoot: root)

        // 실행이 2행에 swiftc 진단을 남긴다.
        let compilerDiagnostic = Diagnostic(
            file: "main.swift", line: 2, column: 9, severity: .warning, message: "쓰이지 않는 값"
        )
        let model = EditorModel(
            task: SampleTask.swift(starter: Self.starter),
            runFactory: FakeRunner.factory(yielding: [
                .phase(.compiling),
                .diagnostic(compilerDiagnostic),
                .finished(RunTermination.exitCode(1, durationMilliseconds: 5)),
            ])
        )
        await model.run()
        #expect(model.diagnosticRows.count == 1)
        #expect(model.diagnosticRows[0].locationLabel == "2행 9열 · swiftc · 1개")

        // 그 위에 언어 서버가 4행 진단을 얹는다.
        await model.startLanguageSupport(serviceFactory: { service })
        let uri = LSPDiagnosticMapping.uri(forPath: root.appendingPathComponent("main.swift").path)
        await server.publishDiagnostics(uri: uri, diagnostics: [
            ScriptedLanguageServer.diagnostic(line: 3, character: 8, severity: 1, message: "서버가 본 것")
        ])

        let rows = await Self.waitForRows(on: model) { $0.count == 2 }
        #expect(rows.map(\.line) == [2, 4])
        // 두 행이 같은 타입이다 — 뷰가 하나뿐이라는 뜻이다. 다른 것은 라벨뿐.
        #expect(rows[0].locationLabel == "2행 9열 · swiftc · 1개")
        #expect(rows[1].locationLabel == "4행 9열 · sourcekit-lsp · 1개")

        await model.stopLanguageSupport()
    }

    @Test("서버가 진단을 비우면 행도 사라진다")
    func clearedDiagnosticsRemoveTheRows() async throws {
        let root = try Self.makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ScriptedLanguageServer()
        let service = SwiftLanguageService(session: LSPSession(transport: server), workspaceRoot: root)

        let model = EditorModel(task: SampleTask.swift(starter: Self.starter))
        await model.startLanguageSupport(serviceFactory: { service })
        let uri = LSPDiagnosticMapping.uri(forPath: root.appendingPathComponent("main.swift").path)

        await server.publishDiagnostics(uri: uri, diagnostics: [
            ScriptedLanguageServer.diagnostic(line: 3, character: 8, severity: 1, message: "고쳐라")
        ])
        _ = await Self.waitForRows(on: model) { !$0.isEmpty }

        await server.publishDiagnostics(uri: uri, diagnostics: [])
        let rows = await Self.waitForRows(on: model) { $0.isEmpty }
        #expect(rows.isEmpty)

        await model.stopLanguageSupport()
    }

    @Test("다른 파일의 진단은 이 화면에 오지 않는다")
    func diagnosticsForOtherFilesAreIgnored() async throws {
        let root = try Self.makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ScriptedLanguageServer()
        let service = SwiftLanguageService(session: LSPSession(transport: server), workspaceRoot: root)

        let model = EditorModel(task: SampleTask.swift(starter: Self.starter))
        await model.startLanguageSupport(serviceFactory: { service })

        await server.publishDiagnostics(
            uri: LSPDiagnosticMapping.uri(forPath: root.appendingPathComponent("Other.swift").path),
            diagnostics: [
                ScriptedLanguageServer.diagnostic(line: 0, character: 0, severity: 1, message: "남의 파일")
            ]
        )
        // 잠깐 기다렸는데도 비어 있어야 한다.
        let rows = await Self.waitForRows(on: model, within: .milliseconds(300)) { !$0.isEmpty }
        #expect(rows.isEmpty)

        await model.stopLanguageSupport()
    }

    // MARK: - 범위

    @Test("Swift 가 아닌 트랙에는 언어 서버가 붙지 않는다")
    func nonSwiftTracksGetNoLanguageServer() async {
        let model = EditorModel(task: SampleTask.sql(database: nil, solution: "SELECT 1;"))
        await model.startLanguageSupport(serviceFactory: {
            Issue.record("SQL 과제에서 언어 서버를 띄우려 했다")
            throw CancellationError()
        })
        #expect(model.languageSupport == nil)
    }

    @Test("서버를 못 띄우면 이유를 남기고 화면은 그대로 산다")
    func unavailableServerIsRecordedNotSwallowed() async {
        struct NoServer: Error {}
        let model = EditorModel(task: SampleTask.swift(starter: Self.starter))
        await model.startLanguageSupport(serviceFactory: { throw NoServer() })

        guard case .unavailable(let reason) = model.languageSupport?.status else {
            Issue.record("상태가 unavailable 이 아니다: \(String(describing: model.languageSupport?.status))")
            return
        }
        #expect(!reason.isEmpty)
        // 완성은 없지만 화면은 그대로다.
        #expect(model.languageSupport?.triggerCharacters.isEmpty == true)
        #expect(model.diagnosticRows.isEmpty)
        #expect(model.canRun)
    }

    /// 진짜 `sourcekit-lsp` 로 화면 끝까지 한 번 태운다. 대본 서버는 "우리가 상상한
    /// 서버" 를 재현할 뿐이라, 실제 서버가 보내는 것이 이 배선을 통과하는지는 따로 봐야 한다.
    ///
    /// 서버가 없는 머신에서는 건너뛴다 — 이 스위트의 나머지는 서버 없이도 전부 돈다.
    @Test("진짜 sourcekit-lsp 진단이 인라인 행까지 온다", .enabled(if: RealLanguageServer.available))
    func realServerDiagnosticsReachTheInlineRow() async throws {
        let broken = "import Foundation\n\nlet count: Int = \"정수가 아니다\"\nprint(count)\n"
        let model = EditorModel(task: SampleTask.swift(starter: broken))
        await model.startLanguageSupport()
        guard model.languageSupport?.status == .ready else {
            Issue.record("언어 서버를 띄우지 못했다: \(String(describing: model.languageSupport?.status))")
            return
        }

        // 첫 진단은 서버가 모듈을 여느라 1초 남짓 걸린다(실측). 상한은 관대하게.
        let rows = await Self.waitForRows(on: model, within: .seconds(90)) { !$0.isEmpty }
        #expect(!rows.isEmpty, "진단 행이 오지 않았다")
        let row = try #require(rows.first { $0.line == 3 })
        #expect(row.codeLine == "let count: Int = \"정수가 아니다\"")
        #expect(row.severity == .error)
        // 출처가 라벨로 구분된다 — `swiftc` 가 아니라 `sourcekit-lsp` 다.
        #expect(row.locationLabel.contains("sourcekit-lsp"))
        #expect(!row.locationLabel.contains("swiftc"))

        await model.stopLanguageSupport()
    }

    /// 시작 도중에 실패하면 **이미 뜬 프로세스를 반드시 거둬야 한다.** 핸들을
    /// `start()` 성공 뒤에 붙잡으면 여기서 잔존 프로세스가 생긴다 — 이 저장소가
    /// 러너 회수에서 이미 겪은 모양이다.
    @Test("initialize 전에 서버가 죽으면 그 서버를 거둔다 — 잔존 프로세스 0")
    func halfStartedServerIsReaped() async throws {
        let root = try Self.makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ScriptedLanguageServer(diesOnOpen: true)
        let service = SwiftLanguageService(session: LSPSession(transport: server), workspaceRoot: root)

        let model = EditorModel(task: SampleTask.swift(starter: Self.starter))
        await model.startLanguageSupport(serviceFactory: { service })

        guard case .unavailable = model.languageSupport?.status else {
            Issue.record("죽은 서버인데 상태가 unavailable 이 아니다")
            return
        }
        // 실패 경로가 통로를 실제로 닫았다.
        #expect(await server.closeCount >= 1)
        await model.stopLanguageSupport()
    }

    @Test("두 번 시작해도 서버는 하나다")
    func startingTwiceKeepsOneServer() async throws {
        let root = try Self.makeWorkspace()
        defer { try? FileManager.default.removeItem(at: root) }
        let server = ScriptedLanguageServer()
        let service = SwiftLanguageService(session: LSPSession(transport: server), workspaceRoot: root)

        let model = EditorModel(task: SampleTask.swift(starter: Self.starter))
        await model.startLanguageSupport(serviceFactory: { service })
        let first = model.languageSupport
        await model.startLanguageSupport(serviceFactory: {
            Issue.record("두 번째 서버를 띄우려 했다 — 공유 자원을 하나로 유지해야 한다")
            throw CancellationError()
        })
        #expect(model.languageSupport === first)
        await model.stopLanguageSupport()
        #expect(model.languageSupport == nil)
    }
}
