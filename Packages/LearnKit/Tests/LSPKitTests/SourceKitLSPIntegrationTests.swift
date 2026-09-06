import Foundation
import LearnCore
import Testing

@testable import LSPKit

/// `service.diagnostics` 를 **한 번만** 순회해 모아 두는 수집기.
///
/// `AsyncStream` 은 이터레이터 하나만 지원한다. 테스트마다 `for await` 를 새로 열면
/// 두 이터레이터가 같은 스트림을 나눠 먹고, 어떤 갱신은 아무도 못 보는 곳으로 사라진다.
/// 그래서 순회는 여기 한 곳뿐이고 테스트는 모인 배열을 본다.
actor DiagnosticsCollector {
    private var received: [SwiftDiagnosticsUpdate] = []
    private var pump: Task<Void, Never>?

    func start(_ service: SwiftLanguageService) {
        pump = Task { [weak self] in
            for await update in service.diagnostics {
                await self?.append(update)
            }
        }
    }

    func stop() {
        pump?.cancel()
        pump = nil
    }

    private func append(_ update: SwiftDiagnosticsUpdate) {
        received.append(update)
    }

    var all: [SwiftDiagnosticsUpdate] { received }

    /// 조건을 만족하는 갱신이 올 때까지 기다린다.
    ///
    /// 상한은 **관대하게** — 판정을 시간으로 하려는 것이 아니라 실패한 테스트가
    /// 영원히 멈추지 않게 하려는 것이다. 첫 진단은 서버가 모듈을 여느라 1초 남짓 걸린다.
    func wait(
        within limit: Duration = .seconds(90),
        where predicate: @Sendable (SwiftDiagnosticsUpdate) -> Bool = { _ in true }
    ) async -> SwiftDiagnosticsUpdate? {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if let match = received.first(where: predicate) { return match }
            // 이 `await` 동안 액터가 풀려 `append` 가 들어온다.
            try? await Task.sleep(for: .milliseconds(20))
        }
        return received.first(where: predicate)
    }
}

/// 진짜 `sourcekit-lsp` 를 띄우는 테스트.
///
/// **서버가 없는 머신에서는 통째로 건너뛴다.** 이 저장소의 다른 실측 스위트와 같은
/// 판단이다 — 툴체인 유무로 스위트가 빨개지면 "실패" 라는 신호가 무의미해진다.
/// 서버 없이도 검증돼야 하는 것(프레이밍·JSON-RPC·매핑·취소)은 전부 다른 파일에 있고,
/// 그쪽이 이 기능의 계약을 실제로 고정한다.
///
/// `.serialized` 인 이유: 테스트마다 sourcekit-lsp 프로세스가 하나씩 뜬다. 병렬로
/// 띄우면 여럿이 동시에 SDK 를 읽고 모듈 캐시를 다툰다 — 이 저장소가 Swift 채점에서
/// 이미 겪은 모습이다.
@Suite("sourcekit-lsp 실측", .serialized)
struct SourceKitLSPIntegrationTests {
    /// `.enabled(if:)` 는 동기 판정을 요구한다. `SourceKitLSPLocator` 는 async 라
    /// 여기서만 같은 것을 동기로 한 번 본다.
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

    static let source = "import Foundation\n\nlet greeting = \"hello\"\nprint(greeting)\n"
    static let dotted = "import Foundation\n\nlet greeting = \"hello\"\nprint(greeting.)\n"

    /// 텍스트 안에서 어떤 조각의 **끝** 오프셋. 완성 요청 자리를 짚는 데 쓴다.
    static func offset(after fragment: String, in text: String) throws -> Int {
        let range = try #require(text.range(of: fragment))
        return text.distance(from: text.startIndex, to: range.upperBound)
    }

    /// 서버 하나를 띄우고 문서를 연 뒤 블록을 돌린다. 어떤 경로로 끝나도 거둔다.
    static func withService(
        text: String = Self.source,
        _ body: (SwiftLanguageService, DiagnosticsCollector, InitializeResult) async throws -> Void
    ) async throws {
        let service = try await SwiftLanguageService.makeDefault()
        let collector = DiagnosticsCollector()
        do {
            let result = try await service.start()
            await collector.start(service)
            await service.openDocument(fileName: "Solution.swift", text: text)
            try await body(service, collector, result)
        } catch {
            await collector.stop()
            await service.shutdown()
            throw error
        }
        await collector.stop()
        await service.shutdown()
    }

    // MARK: - {#sourcekit-lsp-swift}

    /// `{#sourcekit-lsp-swift}` 의 완료 기준: **initialize 응답 수신**.
    @Test("initialize 응답을 실제로 받는다", .enabled(if: Self.available))
    func receivesInitializeResponse() async throws {
        try await Self.withService { service, _, result in
            // 능력이 돌아왔다는 것이 곧 응답을 받았다는 뜻이다.
            let provider = try #require(result.capabilities.completionProvider)
            // 실측: sourcekit-lsp 는 `.` 과 `(` 를 트리거 문자로 광고한다.
            #expect(provider.triggerCharacters?.contains(".") == true)
            #expect(await service.triggerCharacters.contains("."))
            #expect(await service.initializeResult != nil)
        }
    }

    @Test("서버 조회는 던지지 않고 판정한다", .enabled(if: Self.available))
    func locatorReportsAvailability() async throws {
        #expect(await SourceKitLSPLocator.isAvailable())
        let installation = try await SourceKitLSPLocator.locate()
        #expect(installation.executablePath.hasSuffix("sourcekit-lsp"))
        #expect(FileManager.default.isExecutableFile(atPath: installation.executablePath))
        // SDKROOT 이 비면 표준 라이브러리를 못 찾는다 — 이 저장소가 이미 밟은 함정.
        #expect(installation.sdkRoot?.isEmpty == false)
        #expect(installation.developerDirectory?.isEmpty == false)
    }

    // MARK: - {#lsp-diagnostics}

    @Test("잘못된 코드에 진단이 온다", .enabled(if: Self.available))
    func publishesDiagnosticsForBrokenCode() async throws {
        let broken = "import Foundation\n\nlet count: Int = \"정수가 아니다\"\nprint(count)\n"
        try await Self.withService(text: broken) { _, collector, _ in
            let update = try #require(
                await collector.wait { !$0.diagnostics.isEmpty }, "진단이 오지 않았다"
            )
            let error = try #require(update.diagnostics.first { $0.severity == .error })
            // 3행의 대입이 문제다. 좌표계가 어긋나면 여기가 2 나 4 로 나온다.
            #expect(error.line == 3)
            #expect(error.file == "Solution.swift")
            #expect(!error.message.isEmpty)
            // 스냅샷이 함께 온다 — 인라인 진단 행이 그 줄의 소스를 그릴 수 있어야 한다.
            #expect(update.documentText == broken)
        }
    }

    @Test("고치면 진단이 비워진다", .enabled(if: Self.available))
    func fixingTheCodeClearsDiagnostics() async throws {
        let broken = "import Foundation\n\nlet count: Int = \"틀렸다\"\nprint(count)\n"
        try await Self.withService(text: broken) { service, collector, _ in
            _ = try #require(await collector.wait { !$0.diagnostics.isEmpty })
            await service.updateDocument(text: "import Foundation\n\nlet count: Int = 1\nprint(count)\n", editSequence: 2)
            let cleared = await collector.wait { $0.diagnostics.isEmpty }
            #expect(cleared != nil, "코드를 고쳤는데 진단이 비워지지 않았다")
        }
    }

    // MARK: - {#lsp-completion}

    @Test("점 뒤에서 완성 후보가 온다", .enabled(if: Self.available))
    func completionAfterDotReturnsCandidates() async throws {
        try await Self.withService(text: Self.dotted) { service, collector, _ in
            // 서버가 문서를 한 번 훑을 때까지 기다린다. 이게 없으면 첫 완성이 빌드
            // 세팅 해석과 겹친다(실측: 겹치면 270ms, 안 겹치면 88ms).
            _ = await collector.wait()

            let offset = try Self.offset(after: "print(greeting.", in: Self.dotted)
            let candidates = try await service.completions(
                utf16Offset: offset, triggerCharacter: ".", limit: 50
            )
            #expect(!candidates.isEmpty, "점 뒤에 후보가 하나도 없다")
            #expect(candidates.count <= 50, "상한이 지켜지지 않았다")
            // String 의 멤버가 보인다 = 아무 목록이나 온 것이 아니다.
            #expect(candidates.contains { $0.label.hasPrefix("count") })
            #expect(candidates.allSatisfy { !$0.insertText.isEmpty })
        }
    }

    /// `{#lsp-completion}` 완료 기준의 앞 절반: **점 입력 후 200ms 안에 후보**.
    ///
    /// 벽시계 단언은 관대하게 잡는 것이 이 저장소의 규칙이지만 이 항목은 시간 자체가
    /// 기준이라 재지 않을 수 없다. 대신 **예열된 뒤**를 재고 중앙값으로 본다 —
    /// 실측은 첫 요청 88ms, 이후 27~30ms 다. 판정선 200ms 는 중앙값의 여섯 배가 넘어
    /// 부하가 걸린 머신에서도 흔들리지 않는다.
    @Test("예열된 완성 요청의 중앙값이 200ms 안이다", .enabled(if: Self.available))
    func warmCompletionRespondsWithinBudget() async throws {
        try await Self.withService(text: Self.dotted) { service, collector, _ in
            _ = await collector.wait()
            let offset = try Self.offset(after: "print(greeting.", in: Self.dotted)
            _ = try await service.completions(utf16Offset: offset, triggerCharacter: ".")

            var durations: [Duration] = []
            for _ in 0..<5 {
                let clock = ContinuousClock()
                let started = clock.now
                let candidates = try await service.completions(
                    utf16Offset: offset, triggerCharacter: "."
                )
                durations.append(started.duration(to: clock.now))
                #expect(!candidates.isEmpty)
            }

            let median = durations.sorted()[durations.count / 2]
            #expect(median < .milliseconds(200), "예열된 완성 중앙값이 200ms 를 넘었다: \(durations)")
        }
    }

    /// 완료 기준의 뒤 절반을 **진짜 서버 위에서** 확인한다. 구조 단언(취소 프레임이
    /// 나갔는가·콜백이 안 불렸는가)은 `LSPSessionTests` 가 가짜 통로로 이미 증명했다.
    /// 여기서 보는 것은 "진짜 서버도 이 절차를 받아들이고 세션이 그 뒤에도 멀쩡한가" 다.
    @Test("취소한 완성은 값을 주지 않고 세션은 살아남는다", .enabled(if: Self.available))
    func cancelledCompletionAgainstRealServer() async throws {
        try await Self.withService(text: Self.dotted) { service, collector, _ in
            _ = await collector.wait()
            let offset = try Self.offset(after: "print(greeting.", in: Self.dotted)

            let task = Task {
                try await service.completions(utf16Offset: offset, triggerCharacter: ".")
            }
            task.cancel()
            await #expect(throws: (any Error).self) { try await task.value }

            // 취소가 세션을 망가뜨리지 않았다 — 다음 요청이 정상으로 돌아온다.
            let candidates = try await service.completions(utf16Offset: offset, triggerCharacter: ".")
            #expect(!candidates.isEmpty)
        }
    }

    // MARK: - 문서 수명

    @Test("didChange 뒤의 완성은 새 본문을 본다", .enabled(if: Self.available))
    func completionFollowsDocumentUpdates() async throws {
        try await Self.withService { service, collector, _ in
            _ = await collector.wait()

            let updated = """
                import Foundation

                struct Counter {
                    var total = 0
                    func bumped() -> Int { total + 1 }
                }
                let counter = Counter()
                print(counter.)

                """
            await service.updateDocument(text: updated, editSequence: 2)
            _ = await collector.wait { $0.documentText == updated }

            let offset = try Self.offset(after: "print(counter.", in: updated)
            let candidates = try await service.completions(utf16Offset: offset, triggerCharacter: ".")
            // 새 본문에만 있는 멤버다. 서버가 낡은 본문을 보고 있으면 절대 안 나온다.
            #expect(
                candidates.contains { $0.label.hasPrefix("bumped") },
                "갱신된 본문의 멤버가 후보에 없다: \(candidates.prefix(10).map(\.label))"
            )
        }
    }

    @Test("서버를 거두면 임시 워크스페이스도 사라진다", .enabled(if: Self.available))
    func shutdownRemovesTheScratchWorkspace() async throws {
        let service = try await SwiftLanguageService.makeDefault()
        try await service.start()
        await service.openDocument(fileName: "Solution.swift", text: Self.source)
        let root = await service.workspaceRootForTesting
        #expect(FileManager.default.fileExists(atPath: root.path))
        await service.shutdown()
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    /// 학습자 코드를 디스크에 쓰지 않는다는 설계 결정의 회귀 방어.
    /// 실측으로 확인한 것: **존재하지 않는 파일 URI 로도** 진단과 완성이 정상이다.
    @Test("학습자 코드는 디스크에 남지 않는다", .enabled(if: Self.available))
    func learnerCodeNeverTouchesDisk() async throws {
        let service = try await SwiftLanguageService.makeDefault()
        let collector = DiagnosticsCollector()
        try await service.start()
        await collector.start(service)
        await service.openDocument(fileName: "Solution.swift", text: Self.source)
        let root = await service.workspaceRootForTesting
        _ = await collector.wait()

        let contents = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(contents.isEmpty, "워크스페이스에 파일이 생겼다: \(contents)")
        await collector.stop()
        await service.shutdown()
    }
}
