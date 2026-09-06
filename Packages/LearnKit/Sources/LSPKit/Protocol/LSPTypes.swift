internal import Foundation

// LSP 스펙 전체를 옮겨 적지 않는다. 이 앱이 실제로 주고받는 것만 있다:
// initialize / initialized / didOpen / didChange / didClose / completion /
// publishDiagnostics / $/cancelRequest / shutdown / exit.

/// **0-기반**이고 `character` 는 그 줄의 **UTF-16 코드 단위 오프셋**이다.
/// 화면에 찍는 1-기반 칼럼과 다르다 — 변환은 `LSPDiagnosticMapping` 이 한다.
public struct LSPPosition: Hashable, Sendable, Codable {
    public var line: Int
    public var character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

public struct LSPRange: Hashable, Sendable, Codable {
    public var start: LSPPosition
    public var end: LSPPosition

    public init(start: LSPPosition, end: LSPPosition) {
        self.start = start
        self.end = end
    }
}

/// 진단·완성 항목의 `code`. 정수일 수도 문자열일 수도 있다(clangd 는 문자열, 다른
/// 서버는 정수를 쓴다). sourcekit-lsp 는 대개 아예 보내지 않는다 — 실측으로 확인했다.
public enum LSPCode: Hashable, Sendable, Codable, CustomStringConvertible {
    case number(Int)
    case string(String)

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }

    public var description: String {
        switch self {
        case .number(let value): "\(value)"
        case .string(let value): value
        }
    }
}

public struct LSPDiagnostic: Hashable, Sendable, Codable {
    /// 1 = error, 2 = warning, 3 = information, 4 = hint. 없을 수도 있다.
    public var severity: Int?
    public var range: LSPRange
    public var message: String
    /// 진단을 낸 하위 도구. sourcekit-lsp 는 `"SourceKit"` 또는 `"swiftc"` 를 준다.
    public var source: String?
    public var code: LSPCode?

    public init(
        severity: Int? = nil,
        range: LSPRange,
        message: String,
        source: String? = nil,
        code: LSPCode? = nil
    ) {
        self.severity = severity
        self.range = range
        self.message = message
        self.source = source
        self.code = code
    }
}

public struct PublishDiagnosticsParams: Hashable, Sendable, Codable {
    public var uri: String
    public var version: Int?
    public var diagnostics: [LSPDiagnostic]

    public init(uri: String, version: Int? = nil, diagnostics: [LSPDiagnostic]) {
        self.uri = uri
        self.version = version
        self.diagnostics = diagnostics
    }
}

/// 문서화는 평문 문자열이거나 `{kind, value}` 마크업이다. 둘 다 온다.
public enum LSPDocumentation: Hashable, Sendable, Codable {
    case plain(String)
    case markup(kind: String, value: String)

    public var text: String {
        switch self {
        case .plain(let value): value
        case .markup(_, let value): value
        }
    }

    private struct Markup: Codable {
        var kind: String
        var value: String
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .plain(value)
        } else {
            let markup = try container.decode(Markup.self)
            self = .markup(kind: markup.kind, value: markup.value)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .plain(let value): try container.encode(value)
        case .markup(let kind, let value): try container.encode(Markup(kind: kind, value: value))
        }
    }
}

/// `textEdit` 은 `TextEdit`(range) 이거나 `InsertReplaceEdit`(insert/replace) 다.
/// 우리가 필요한 것은 `newText` 하나뿐이라 모양은 무시하고 그것만 꺼낸다.
public struct LSPTextEdit: Hashable, Sendable, Codable {
    public var newText: String
    public var range: LSPRange?

    private enum CodingKeys: String, CodingKey {
        case newText, range, insert
    }

    public init(newText: String, range: LSPRange? = nil) {
        self.newText = newText
        self.range = range
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        newText = try container.decode(String.self, forKey: .newText)
        range = try container.decodeIfPresent(LSPRange.self, forKey: .range)
            ?? container.decodeIfPresent(LSPRange.self, forKey: .insert)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(newText, forKey: .newText)
        try container.encodeIfPresent(range, forKey: .range)
    }
}

public struct LSPCompletionItem: Hashable, Sendable, Codable {
    public var label: String
    /// LSP `CompletionItemKind`, 1...25.
    public var kind: Int?
    public var detail: String?
    public var documentation: LSPDocumentation?
    public var sortText: String?
    public var filterText: String?
    public var insertText: String?
    /// 1 = plain text, 2 = snippet. 스니펫은 `$0` 같은 자리표시자를 담는다.
    public var insertTextFormat: Int?
    public var textEdit: LSPTextEdit?
    public var deprecated: Bool?

    public init(
        label: String,
        kind: Int? = nil,
        detail: String? = nil,
        documentation: LSPDocumentation? = nil,
        sortText: String? = nil,
        filterText: String? = nil,
        insertText: String? = nil,
        insertTextFormat: Int? = nil,
        textEdit: LSPTextEdit? = nil,
        deprecated: Bool? = nil
    ) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.sortText = sortText
        self.filterText = filterText
        self.insertText = insertText
        self.insertTextFormat = insertTextFormat
        self.textEdit = textEdit
        self.deprecated = deprecated
    }
}

/// `textDocument/completion` 의 결과는 `CompletionItem[]` 이거나 `CompletionList` 다.
/// sourcekit-lsp 는 후자를 준다(`isIncomplete: true` + 200개, 실측).
public struct LSPCompletionResponse: Hashable, Sendable, Decodable {
    public var isIncomplete: Bool
    public var items: [LSPCompletionItem]

    public init(isIncomplete: Bool, items: [LSPCompletionItem]) {
        self.isIncomplete = isIncomplete
        self.items = items
    }

    private struct List: Decodable {
        var isIncomplete: Bool?
        var items: [LSPCompletionItem]
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let items = try? container.decode([LSPCompletionItem].self) {
            self.init(isIncomplete: false, items: items)
            return
        }
        if container.decodeNil() {
            self.init(isIncomplete: false, items: [])
            return
        }
        let list = try container.decode(List.self)
        self.init(isIncomplete: list.isIncomplete ?? false, items: list.items)
    }
}

// MARK: - 우리가 보내는 것

public struct InitializeParams: Encodable, Sendable {
    public var processId: Int32?
    public var rootUri: String?
    public var capabilities: ClientCapabilities
    public var workspaceFolders: [WorkspaceFolder]?

    public init(
        processId: Int32?,
        rootUri: String?,
        capabilities: ClientCapabilities = ClientCapabilities(),
        workspaceFolders: [WorkspaceFolder]? = nil
    ) {
        self.processId = processId
        self.rootUri = rootUri
        self.capabilities = capabilities
        self.workspaceFolders = workspaceFolders
    }
}

public struct WorkspaceFolder: Encodable, Sendable {
    public var uri: String
    public var name: String

    public init(uri: String, name: String) {
        self.uri = uri
        self.name = name
    }
}

/// 광고하는 능력은 **최소**다. 이 앱은 완성과 진단만 쓴다.
///
/// 능력을 넓게 광고하면 서버가 `client/registerCapability`·`window/workDoneProgress/create`
/// 같은 **서버발 요청**을 보내기 시작하고, 답하지 않으면 서버가 기다린다.
/// 안 쓰는 것을 광고하지 않는 것이 첫 번째 방어다.
public struct ClientCapabilities: Encodable, Sendable {
    public struct TextDocument: Encodable, Sendable {
        public struct PublishDiagnostics: Encodable, Sendable {
            public var relatedInformation = false
        }

        public struct Completion: Encodable, Sendable {
            public struct Item: Encodable, Sendable {
                /// **false 다.** 스니펫을 받으면 `$0`·`${1:name}` 같은 자리표시자가
                /// 그대로 버퍼에 박힌다 — 이 앱의 에디터는 스니펫을 해석하지 않는다.
                public var snippetSupport = false
                public var deprecatedSupport = true
                public var documentationFormat = ["plaintext", "markdown"]
            }

            public var completionItem = Item()
        }

        public var publishDiagnostics = PublishDiagnostics()
        public var completion = Completion()
    }

    public var textDocument = TextDocument()

    public init() {}
}

/// `initialize` 응답에서 우리가 실제로 읽는 부분. `{#sourcekit-lsp-swift}` 의 완료
/// 기준이 "initialize 응답 수신" 이라 이 타입이 그 증거의 형태다.
public struct InitializeResult: Hashable, Sendable, Decodable {
    public struct ServerCapabilities: Hashable, Sendable, Decodable {
        public struct CompletionProvider: Hashable, Sendable, Decodable {
            public var triggerCharacters: [String]?
            public var resolveProvider: Bool?
        }

        public var completionProvider: CompletionProvider?
        public var hoverProvider: Bool?
    }

    public struct ServerInfo: Hashable, Sendable, Decodable {
        public var name: String
        public var version: String?
    }

    public var capabilities: ServerCapabilities
    public var serverInfo: ServerInfo?

    public init(capabilities: ServerCapabilities, serverInfo: ServerInfo? = nil) {
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

public struct TextDocumentIdentifier: Encodable, Sendable {
    public var uri: String

    public init(uri: String) {
        self.uri = uri
    }
}

public struct VersionedTextDocumentIdentifier: Encodable, Sendable {
    public var uri: String
    public var version: Int

    public init(uri: String, version: Int) {
        self.uri = uri
        self.version = version
    }
}

public struct TextDocumentItem: Encodable, Sendable {
    public var uri: String
    public var languageId: String
    public var version: Int
    public var text: String

    public init(uri: String, languageId: String, version: Int, text: String) {
        self.uri = uri
        self.languageId = languageId
        self.version = version
        self.text = text
    }
}

public struct DidOpenTextDocumentParams: Encodable, Sendable {
    public var textDocument: TextDocumentItem

    public init(textDocument: TextDocumentItem) {
        self.textDocument = textDocument
    }
}

/// **전체 치환**만 쓴다(`textDocumentSync.change == 1` 도 서버가 받아 준다).
/// 증분 동기화는 편집기의 편집 이벤트를 LSP 범위로 옮기는 매핑이 필요한데, 레슨 코드는
/// 수십 줄이라 전체를 다시 보내는 비용이 그 매핑의 버그 위험보다 싸다.
public struct DidChangeTextDocumentParams: Encodable, Sendable {
    public struct FullChange: Encodable, Sendable {
        public var text: String
    }

    public var textDocument: VersionedTextDocumentIdentifier
    public var contentChanges: [FullChange]

    public init(textDocument: VersionedTextDocumentIdentifier, text: String) {
        self.textDocument = textDocument
        self.contentChanges = [FullChange(text: text)]
    }
}

public struct DidCloseTextDocumentParams: Encodable, Sendable {
    public var textDocument: TextDocumentIdentifier

    public init(textDocument: TextDocumentIdentifier) {
        self.textDocument = textDocument
    }
}

public struct CompletionParams: Encodable, Sendable {
    public struct Context: Encodable, Sendable {
        /// 1 = 사용자가 직접 호출, 2 = 트리거 문자, 3 = 불완전 목록 재요청.
        public var triggerKind: Int
        public var triggerCharacter: String?
    }

    public var textDocument: TextDocumentIdentifier
    public var position: LSPPosition
    public var context: Context

    public init(uri: String, position: LSPPosition, triggerCharacter: String?) {
        self.textDocument = TextDocumentIdentifier(uri: uri)
        self.position = position
        self.context = Context(
            triggerKind: triggerCharacter == nil ? 1 : 2,
            triggerCharacter: triggerCharacter
        )
    }
}

public struct CancelParams: Encodable, Sendable {
    public var id: JSONRPCID

    public init(id: JSONRPCID) {
        self.id = id
    }
}

/// LSP 메서드 이름. 오타는 컴파일러가 못 잡아 주므로 한 곳에 모은다.
public enum LSPMethod {
    public static let initialize = "initialize"
    public static let initialized = "initialized"
    public static let shutdown = "shutdown"
    public static let exit = "exit"
    public static let cancelRequest = "$/cancelRequest"
    public static let didOpen = "textDocument/didOpen"
    public static let didChange = "textDocument/didChange"
    public static let didClose = "textDocument/didClose"
    public static let completion = "textDocument/completion"
    public static let publishDiagnostics = "textDocument/publishDiagnostics"
    public static let registerCapability = "client/registerCapability"
    public static let unregisterCapability = "client/unregisterCapability"
    public static let workDoneProgressCreate = "window/workDoneProgress/create"
}
