public import Foundation
public import LearnCore

/// 진단 한 묶음과 **그것이 계산된 문서 스냅샷**.
///
/// 둘을 함께 내보내는 이유: 인라인 진단 행은 "그 줄의 소스 텍스트" 를 같이 그린다.
/// 진단만 주면 화면이 최신 버퍼에서 줄을 뽑고, 그 사이 학습자가 줄을 하나 더 넣었으면
/// 엉뚱한 줄이 붙는다. 어느 스냅샷의 진단인지는 진단을 만든 쪽만 안다.
public struct SwiftDiagnosticsUpdate: Hashable, Sendable {
    public var diagnostics: [Diagnostic]
    public var documentVersion: Int
    public var documentText: String

    public init(diagnostics: [Diagnostic], documentVersion: Int, documentText: String) {
        self.diagnostics = diagnostics
        self.documentVersion = documentVersion
        self.documentText = documentText
    }
}

public enum SwiftLanguageServiceError: Error, Hashable, Sendable, CustomStringConvertible {
    case noDocumentOpen
    case notRunning

    public var description: String {
        switch self {
        case .noDocumentOpen: "열린 문서가 없다 — openDocument 를 먼저 불러야 한다."
        case .notRunning: "Swift 언어 서비스가 실행 중이 아니다."
        }
    }
}

/// Swift 트랙 전용 언어 서비스. **문서 하나**를 맡는다.
///
/// ## 문서가 하나인 이유
///
/// 이 저장소는 "예열해서 재사용하려고 공유한 자원에 동시 접근" 을 세 번 밟았다.
/// 언어 서버는 정확히 그 모양의 자원이다 — 띄우는 데 시간이 들고, 인덱스가 따뜻해질수록
/// 빨라지고, 그래서 공유하고 싶어진다.
///
/// 여기서는 공유 범위를 **문서 하나**로 잘랐다. 에디터 화면은 한 번에 과제 하나를 열고,
/// 문서가 하나면 "누가 어느 버전을 보고 있는가" 라는 질문 자체가 생기지 않는다.
/// 두 화면이 동시에 Swift 를 편집하게 되는 날에는 이 타입을 **인스턴스마다 서버 하나**로
/// 늘려야지, 이 인스턴스를 공유해서는 안 된다.
///
/// ## 서버가 없는 머신
///
/// `start()` 가 던진다. 그것으로 끝이다 — 호출하는 쪽은 완성과 실시간 진단을 포기하고
/// 나머지 기능(편집·실행·swiftc 진단)을 그대로 쓴다. 실패를 삼켜서 "완성이 안 뜨는데
/// 이유를 모르는" 상태를 만들지 않는다.
public actor SwiftLanguageService {
    /// 서버가 완성을 트리거하겠다고 광고한 문자. `initialize` 응답에서 온다.
    /// sourcekit-lsp 는 `["." , "("]` 를 준다 — 실측으로 확인했다.
    public private(set) var triggerCharacters: Set<String> = []
    public private(set) var initializeResult: InitializeResult?

    private let session: LSPSession
    private let workspaceRoot: URL
    private let ownsWorkspaceDirectory: Bool

    private var documentURI: String?
    private var documentPath: String?
    private var documentText: String = ""
    private var documentVersion = 0
    /// 상위 계층이 **동기 구간에서** 매긴 편집 순번 중 지금까지 반영한 최대값.
    ///
    /// 이 액터에 들어오는 순서는 보장되지 않는다 — 호출자가 여럿이거나(키 입력마다
    /// 새 태스크) 액터 홉이 겹치면 새 편집이 낡은 편집보다 먼저 도착할 수 있다.
    /// 도착 순서를 고칠 방법은 없으므로 **낡은 것을 버린다.**
    private var lastEditSequence = 0
    private var isRunning = false

    private var diagnosticsSink: AsyncStream<SwiftDiagnosticsUpdate>.Continuation
    /// 서버가 보낸 진단. 소비자는 화면 하나다.
    public nonisolated let diagnostics: AsyncStream<SwiftDiagnosticsUpdate>

    private var notificationTask: Task<Void, Never>?

    /// 임시 워크스페이스 경로. "학습자 코드가 디스크에 남지 않는다" 를 테스트가
    /// 확인하는 통로다 — 그 단언이 없으면 설계 결정이 조용히 뒤집힌다.
    var workspaceRootForTesting: URL { workspaceRoot }

    /// 서버가 들고 있다고 우리가 믿는 본문. 늦게 도착한 낡은 편집이 최신을 덮어쓰지
    /// 않았는지 테스트가 확인하는 통로다.
    var documentTextForTesting: String { documentText }

    public init(session: LSPSession, workspaceRoot: URL, ownsWorkspaceDirectory: Bool = false) {
        self.session = session
        self.workspaceRoot = workspaceRoot
        self.ownsWorkspaceDirectory = ownsWorkspaceDirectory
        let pair = AsyncStream<SwiftDiagnosticsUpdate>.makeStream(bufferingPolicy: .bufferingNewest(8))
        self.diagnostics = pair.stream
        self.diagnosticsSink = pair.continuation
    }

    /// 진짜 `sourcekit-lsp` 를 띄우는 서비스. 서버가 없으면 던진다.
    ///
    /// 워크스페이스는 빈 임시 디렉터리다. **학습자 코드를 디스크에 쓰지 않는다** —
    /// `didOpen` 이 본문을 통째로 실어 나르고, 존재하지 않는 파일 URI 로도 진단과
    /// 완성이 정상 동작하는 것을 실측으로 확인했다(sourcekit-lsp, Xcode 26.6).
    public static func makeDefault() async throws -> SwiftLanguageService {
        let transport = try await SubprocessLSPTransport.locating()
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("learnkit-lsp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return SwiftLanguageService(
            session: LSPSession(transport: transport),
            workspaceRoot: root,
            ownsWorkspaceDirectory: true
        )
    }

    // MARK: - 수명

    /// 서버를 띄우고 `initialize` 왕복을 마친다.
    ///
    /// `{#sourcekit-lsp-swift}` 의 완료 기준이 "initialize 응답 수신" 이라, 이 함수가
    /// 값을 돌려주는 것이 곧 그 기준을 만족한 증거다.
    @discardableResult
    public func start() async throws -> InitializeResult {
        try await session.start()

        let params = InitializeParams(
            processId: ProcessInfo.processInfo.processIdentifier,
            rootUri: LSPDiagnosticMapping.uri(forPath: workspaceRoot.path),
            workspaceFolders: [
                WorkspaceFolder(
                    uri: LSPDiagnosticMapping.uri(forPath: workspaceRoot.path),
                    name: workspaceRoot.lastPathComponent
                )
            ]
        )
        let result = try await session.request(
            method: LSPMethod.initialize,
            params: params,
            returning: InitializeResult.self
        )
        initializeResult = result
        triggerCharacters = Set(result.capabilities.completionProvider?.triggerCharacters ?? [])

        // `initialized` 를 보내기 전까지 서버는 요청을 받지 않아도 되는 상태다.
        session.notify(method: LSPMethod.initialized, params: EmptyParams())
        isRunning = true

        startNotificationPump()
        return result
    }

    public func shutdown() async {
        isRunning = false
        notificationTask?.cancel()
        notificationTask = nil
        await session.shutdown()
        diagnosticsSink.finish()
        if ownsWorkspaceDirectory {
            try? FileManager.default.removeItem(at: workspaceRoot)
        }
    }

    // MARK: - 문서

    /// 문서를 연다. 이미 열려 있으면 먼저 닫는다 — 서버가 같은 URI 를 두 번 열면
    /// 두 번째 `didOpen` 을 무시하거나 오류를 낸다.
    public func openDocument(fileName: String, text: String, editSequence: Int = 1) async {
        guard isRunning else { return }
        if documentURI != nil { closeDocument() }

        // 여기부터 `notify` 까지 **중단점이 없다.** `notify` 는 nonisolated 동기
        // 함수이므로 상태 변경과 큐 삽입이 한 덩어리다.
        let path = workspaceRoot.appendingPathComponent(fileName).path
        let uri = LSPDiagnosticMapping.uri(forPath: path)
        documentPath = path
        documentURI = uri
        documentText = text
        documentVersion = 1
        lastEditSequence = editSequence

        session.notify(
            method: LSPMethod.didOpen,
            params: DidOpenTextDocumentParams(
                textDocument: TextDocumentItem(
                    uri: uri, languageId: "swift", version: documentVersion, text: text
                )
            )
        )
    }

    /// 본문을 통째로 갈아 끼운다. 버전은 여기서만 오른다.
    ///
    /// 순서 보장이 두 겹이다.
    ///
    /// 1. **이 함수 안에는 중단점이 없다.** `session.notify` 가 nonisolated 동기
    ///    함수라 `documentVersion += 1` 과 큐 삽입 사이에 다른 호출이 끼어들 수 없다.
    /// 2. **도착 순서가 뒤집혀도 낡은 것이 이기지 못한다.** `editSequence` 는 호출자가
    ///    동기 구간에서 매긴 전순서이고, 그보다 작은 편집은 버린다.
    ///
    /// 둘 다 필요하다. 1번만 있으면 액터 진입 순서가 뒤집힐 때 옛 본문이 최신을
    /// 덮어쓰고, 2번만 있으면 같은 순번 구간 안에서 바이트가 섞인다.
    ///
    /// - Parameter editSequence: 호출자가 **동기 구간에서** 1부터 단조 증가시켜 매긴 값.
    public func updateDocument(text: String, editSequence: Int) {
        guard isRunning, let uri = documentURI else { return }
        // **낡은 편집은 버린다.** 순번은 상위 계층이 동기 구간에서 매기므로 전순서가
        // 있고, 여기 도착하는 순서만 뒤집힐 수 있다. 이 가드가 없으면 늦게 도착한
        // 옛 본문이 최신 본문을 덮어쓰고, 그 상태는 스스로 낫지 않는다 —
        // 아래 `text != documentText` 때문에 다시 보내지도 않는다.
        guard editSequence > lastEditSequence else { return }
        lastEditSequence = editSequence
        guard text != documentText else { return }
        documentText = text
        documentVersion += 1
        session.notify(
            method: LSPMethod.didChange,
            params: DidChangeTextDocumentParams(
                textDocument: VersionedTextDocumentIdentifier(uri: uri, version: documentVersion),
                text: text
            )
        )
    }

    public func closeDocument() {
        guard let uri = documentURI else { return }
        session.notify(
            method: LSPMethod.didClose,
            params: DidCloseTextDocumentParams(textDocument: TextDocumentIdentifier(uri: uri))
        )
        documentURI = nil
        documentPath = nil
        documentText = ""
        documentVersion = 0
    }

    // MARK: - 완성

    /// 문서 전체의 UTF-16 오프셋 자리에서 완성 후보를 받는다.
    ///
    /// 호출한 태스크가 취소되면 서버에 `$/cancelRequest` 가 나가고 `CancellationError`
    /// 로 던진다. 편집기가 다음 글자에 새 요청을 걸 때 앞의 요청이 서버에서 실제로
    /// 죽어야 한다 — 안 그러면 200개짜리 응답이 늦게 도착해 이미 지나간 자리의 목록을
    /// 띄운다.
    public func completions(
        utf16Offset: Int,
        triggerCharacter: String?,
        limit: Int = 100
    ) async throws -> [CompletionCandidate] {
        guard isRunning, let uri = documentURI else {
            throw SwiftLanguageServiceError.noDocumentOpen
        }
        let position = LSPPositionConversion.position(utf16Offset: utf16Offset, in: documentText)
        let response = try await session.request(
            method: LSPMethod.completion,
            params: CompletionParams(uri: uri, position: position, triggerCharacter: triggerCharacter),
            returning: LSPCompletionResponse.self
        )
        return LSPCompletionMapping.candidates(from: response, limit: limit)
    }

    // MARK: - 진단

    private func startNotificationPump() {
        notificationTask = Task { [weak self, session] in
            for await notification in session.notifications {
                guard !Task.isCancelled else { return }
                await self?.handle(notification)
            }
        }
    }

    private func handle(_ notification: LSPNotification) {
        guard notification.method == LSPMethod.publishDiagnostics else { return }
        guard let params = try? JSONRPCDecoder.params(
            PublishDiagnosticsParams.self, from: notification.payload
        ) else { return }
        // 다른 파일의 진단이 올 수 있다(서버가 의존 파일까지 검사한다). 우리 문서만 본다.
        guard let documentURI, params.uri == documentURI else { return }

        let mapped = LSPDiagnosticMapping.map(
            params,
            documentText: documentText,
            workspaceRoot: workspaceRoot.path
        )
        diagnosticsSink.yield(
            SwiftDiagnosticsUpdate(
                diagnostics: mapped,
                // 서버는 대개 version 을 실어 주지 않는다(sourcekit-lsp 가 그렇다).
                // 그 경우 우리가 마지막으로 보낸 버전이 최선의 근사다.
                documentVersion: params.version ?? documentVersion,
                documentText: documentText
            )
        )
    }
}

/// `initialized` 처럼 빈 객체를 요구하는 알림용. `params` 를 아예 빼면 거절하는
/// 서버가 있다.
struct EmptyParams: Encodable, Sendable {}
