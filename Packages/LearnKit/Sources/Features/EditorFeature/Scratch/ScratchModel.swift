public import DesignSystem
internal import LanguageKit
public import LearnCore
public import Observation
internal import RunnerKit

public import Foundation

/// 연습장 화면의 상태.
///
/// `EditorModel` 과 나란히 두되 **채점을 아예 갖지 않는다.** 그것이 이 화면의 요점이다 —
/// 레슨의 과제는 숨은 테스트가 정답을 정하지만 여기서는 정답이 없다. 그래서 `submit`
/// 도 `GradeState` 도 `tests` 탭도 없다.
///
/// SQL 만 예외적으로 결과를 표로 그린다. 시드 데이터베이스는 SQL 트랙의 것을 그대로
/// 쓴다 — 학습자가 레슨에서 익힌 스키마를 연습장에서 다시 배우게 하지 않는다.
@Observable
@MainActor
public final class ScratchModel {

    public enum RunState: Hashable, Sendable {
        case idle
        case preparing
        case running
        case finished(succeeded: Bool, exitCode: Int32?, durationMilliseconds: Int)
        case failed(String)

        public var isBusy: Bool {
            switch self {
            case .preparing, .running: true
            default: false
            }
        }
    }

    public private(set) var language: ScratchLanguage
    public private(set) var files: [ScratchFile] = []
    public private(set) var selectedFileName: String = ""
    public private(set) var transcript: ConsoleTranscript = .empty
    public private(set) var diagnostics: [Diagnostic] = []
    public private(set) var resultSet: ResultSet?
    public private(set) var runState: RunState = .idle
    /// 저장이 실패했을 때만 채워진다. 화면이 조용히 잃는 일이 없게 한다.
    public private(set) var saveFailure: String?

    private let store: ScratchStore
    /// `nil` 이면 실행 시점에 앱 기본 러너로 떨어진다. **생성자에서 채우지 않는다** —
    /// 기본 러너는 `@MainActor` 격리라 nonisolated 팩토리에서 만들 수 없다.
    private let runFactory: EditorRunFactory?
    private let seedDatabaseProvider: (@Sendable () -> URL?)?
    var languageSupport: SwiftLanguageSupport?

    /// - Parameters:
    ///   - runFactory: `nil` 이면 앱 기본 러너를 쓴다. **기본 인자로 클로저 리터럴을 두지
    ///     않는다** — `EditorModel` 주석의 Swift 6.3 함정과 같은 자리다(`freed pointer was
    ///     not the last allocation`).
    ///   - seedDatabaseProvider: SQL 연습장이 쓸 시드 DB. 없으면 SQL 은 `WITH` 절로만 논다.
    public init(
        language: ScratchLanguage = .python,
        store: ScratchStore? = nil,
        runFactory: EditorRunFactory? = nil,
        seedDatabaseProvider: (@Sendable () -> URL?)? = nil
    ) {
        self.language = language
        self.store = store ?? ScratchStore(root: ScratchStore.defaultRoot())
        self.runFactory = runFactory
        self.seedDatabaseProvider = seedDatabaseProvider
        reloadFiles()
    }

    // MARK: - 파일

    public var selectedFile: ScratchFile? {
        files.first { $0.name == selectedFileName }
    }

    /// 편집 중인 본문. 편집기가 여기에 직접 쓴다.
    public var code: String {
        get { selectedFile?.contents ?? "" }
        set {
            guard let index = files.firstIndex(where: { $0.name == selectedFileName }) else { return }
            guard files[index].contents != newValue else { return }
            files[index].contents = newValue
            persist(files[index])
        }
    }

    public func select(_ name: String) {
        guard files.contains(where: { $0.name == name }) else { return }
        selectedFileName = name
    }

    public func switchLanguage(to language: ScratchLanguage) {
        guard language != self.language else { return }
        self.language = language
        // 실행 결과는 언어에 딸린 것이다. 남겨 두면 이전 언어의 출력이 새 언어의 것으로 읽힌다.
        transcript = .empty
        diagnostics = []
        resultSet = nil
        runState = .idle
        reloadFiles()
    }

    /// 새 파일. 이름이 규칙에 맞지 않거나 이미 있으면 만들지 않고 이유를 돌려준다.
    @discardableResult
    public func addFile(named rawName: String) -> String? {
        guard language.allowsMultipleFiles else {
            return "\(language.displayName) 연습장은 파일 하나만 씁니다."
        }
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard ScratchStore.isValidFileName(name, language: language) else {
            let allowed = ScratchStore.allowedExtensions(for: language)
                .map { ".\($0)" }.joined(separator: " · ")
            return "이름이 올바르지 않습니다. 확장자는 \(allowed) 중 하나여야 합니다."
        }
        guard !files.contains(where: { $0.name == name }) else {
            return "같은 이름의 파일이 이미 있습니다."
        }
        let file = ScratchFile(name: name, contents: language.newFileContents(named: name))
        files.append(file)
        sortFiles()
        persist(file)
        selectedFileName = name
        return nil
    }

    /// 파일을 지운다. **진입점은 지울 수 없다** — 지우면 실행할 것이 없어진다.
    @discardableResult
    public func deleteFile(named name: String) -> String? {
        guard name != language.entryFileName else {
            return "\(name) 은 실행의 진입점이라 지울 수 없습니다."
        }
        files.removeAll { $0.name == name }
        do {
            try store.delete(name, language: language)
        } catch {
            saveFailure = "파일을 지우지 못했습니다: \(error.localizedDescription)"
        }
        if selectedFileName == name {
            selectedFileName = language.entryFileName
        }
        return nil
    }

    /// 진입점을 시작 코드로 되돌린다. 학습자가 막혔을 때의 탈출구다.
    public func resetEntryFile() {
        guard let index = files.firstIndex(where: { $0.name == language.entryFileName }) else { return }
        files[index].contents = language.starterContents
        persist(files[index])
    }

    private func reloadFiles() {
        files = store.load(language)
        if !files.contains(where: { $0.name == selectedFileName }) {
            selectedFileName = language.entryFileName
        }
        saveFailure = nil
    }

    private func sortFiles() {
        let entry = language.entryFileName
        files.sort { lhs, rhs in
            if lhs.name == entry { return true }
            if rhs.name == entry { return false }
            return lhs.name < rhs.name
        }
    }

    private func persist(_ file: ScratchFile) {
        do {
            try store.write(file, language: language)
            saveFailure = nil
        } catch {
            saveFailure = "저장하지 못했습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - 실행

    public var canRun: Bool { !runState.isBusy }

    /// SQL 은 결과를 표로, 나머지는 콘솔로 그린다.
    public var presenter: GradeResult.Presenter { language == .sql ? .table : .console }

    public func run() async {
        guard canRun else { return }
        transcript = ConsoleTranscript(isRunning: true)
        diagnostics = []
        resultSet = nil
        runState = .preparing

        var resources: [String: URL] = [:]
        if language == .sql, let seed = seedDatabaseProvider?() {
            resources[RunRequest.Resource.database] = seed
        }
        let request = RunRequest(
            files: runnableFiles(),
            entryPoint: language.entryFileName,
            resources: resources
        )

        var sawTermination = false
        do {
            for try await event in stream(for: language.languageID, request: request) {
                if case .finished = event { sawTermination = true }
                apply(event)
            }
            if !sawTermination {
                // 종료 이벤트 없이 스트림이 닫혔다. running 에 남겨 두면 버튼이 영영 잠긴다.
                transcript.isRunning = false
                runState = .finished(succeeded: false, exitCode: nil, durationMilliseconds: 0)
            }
        } catch {
            let reason = ScratchModel.describe(error)
            transcript.isRunning = false
            transcript.appendNote(reason)
            runState = .failed(reason)
        }
    }

    /// 실행기에 넘길 파일들.
    ///
    /// SQL 은 질의 하나만 간다 — 실행기가 파일 하나를 받고, 파일이 여럿이면 나머지가
    /// 조용히 무시돼 "왜 안 반영되지" 가 된다. 나머지 언어는 전부 넘기고 진입점만 못박는다.
    func runnableFiles() -> [SourceFile] {
        if !language.allowsMultipleFiles {
            let entry = files.first { $0.name == language.entryFileName } ?? files.first
            guard let entry else { return [] }
            return [SourceFile(path: language.entryFileName, contents: entry.contents)]
        }
        return files.map { SourceFile(path: $0.name, contents: $0.contents) }
    }

    private func apply(_ event: RunEvent) {
        switch event {
        case .phase(let phase):
            runState = phase == .compiling ? .preparing : .running
        case .standardOutput(let data):
            transcript.append(String(decoding: data, as: UTF8.self), stream: .output)
        case .standardError(let data):
            transcript.append(String(decoding: data, as: UTF8.self), stream: .error)
        case .diagnostic(let diagnostic):
            diagnostics.append(diagnostic)
        case .resultSet(let set):
            resultSet = set
        case .finished(let termination):
            transcript.isRunning = false
            transcript.exitCode = termination.exitCode
            transcript.durationMilliseconds = termination.durationMilliseconds
            runState = .finished(
                succeeded: termination.succeeded,
                exitCode: termination.exitCode,
                durationMilliseconds: termination.durationMilliseconds)
        default:
            break
        }
    }

    // MARK: - 언어 서버 (`{#sourcekit-lsp-swift}`)

    /// Swift 연습장이면 언어 서버를 띄운다. 실패해도 던지지 않는다 — 완성과 실시간
    /// 진단만 없고 편집·실행·`swiftc` 진단은 그대로다.
    func startLanguageSupport(
        serviceFactory: SwiftLanguageSupport.ServiceFactory? = nil
    ) async {
        guard language == .swift, languageSupport == nil else { return }
        let support = SwiftLanguageSupport(
            fileName: language.entryFileName, serviceFactory: serviceFactory)
        languageSupport = support
        await support.start(text: code)
    }

    func stopLanguageSupport() async {
        let support = languageSupport
        languageSupport = nil
        await support?.stop()
    }

    // MARK: - 기본 러너

    /// 앱이 팩토리를 주지 않았을 때. `EditorModel.stream(for:request:)` 과 같은 모양이다 —
    /// 폴백을 **호출 시점**에 두는 이유는 기본 러너가 `@MainActor` 격리라서다.
    private func stream(for language: LanguageID, request: RunRequest)
        -> AsyncThrowingStream<RunEvent, any Error>
    {
        if let runFactory { return runFactory(language, request) }
        do {
            return try EditorModel.defaultRunner(for: language).run(request)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }

    nonisolated static func describe(_ error: any Error) -> String {
        guard let failure = error as? RunFailure else { return "\(error)" }
        switch failure {
        case .toolchainMissing(let hint): return "툴체인 없음: \(hint)"
        case .wallClockExceeded(let seconds): return "\(seconds)초 안에 끝나지 않았습니다"
        case .cpuExceeded(let seconds): return "CPU \(seconds)초를 다 썼습니다"
        case .memoryExceeded(let megabytes): return "메모리 \(megabytes)MB 를 넘겼습니다"
        case .fileSizeExceeded(let bytes): return "파일 크기 \(bytes)바이트를 넘겼습니다"
        case .cancelled: return "취소됐습니다"
        case .backend(let message): return "실행기 오류: \(message)"
        }
    }
}
