public import DesignSystem
public import LanguageKit
public import LearnCore
public import Observation
public import RunnerKit
internal import Foundation

/// 실행 스트림 팩토리. `LessonModel.runFactory` 와 같은 계약이다.
///
/// **Swift 6.3 함정** — async `@Sendable` 클로저를 `@MainActor` 격리 `public init` 의
/// 기본 인자로 두고 다른 모듈에서 그 파라미터를 생략해 호출하면 `freed pointer was
/// not the last allocation` 으로 죽는다(온보딩 세션이 실측, 100% 재현). 그래서
/// `EditorModel.init` 은 이 타입도 ``EditorGraderFactory`` 도 **`nil` 기본값 + 내부
/// 폴백**으로 받는다 — 절대 클로저 리터럴을 기본 인자로 두지 않는다.
public typealias EditorRunFactory =
    @Sendable (LanguageID, RunRequest) -> AsyncThrowingStream<RunEvent, any Error>

/// 채점 한 번의 결과. `GradeResult` 가 화면 공통 계약이고, SQL 세 필드는 결과 표
/// 프리젠터(`{#screen-sql-result}`)가 diff 를 그리는 데만 쓰는 부가 정보다.
///
/// `nonisolated` — 이 값은 `EditorGraderFactory`(`@Sendable`) 안에서 만들어진다.
/// 모듈 기본 격리가 `MainActor` 라 이 표시가 없으면 초기화조차 격리 경계를 넘지
/// 못한다(`LessonContent` 가 같은 이유로 `nonisolated` 다).
public nonisolated struct EditorGradeOutcome: Sendable {
    public var result: GradeResult
    public var sqlComparison: SQLComparison?
    public var sqlExpected: ResultSet?
    public var sqlActual: ResultSet?

    public init(
        result: GradeResult,
        sqlComparison: SQLComparison? = nil,
        sqlExpected: ResultSet? = nil,
        sqlActual: ResultSet? = nil
    ) {
        self.result = result
        self.sqlComparison = sqlComparison
        self.sqlExpected = sqlExpected
        self.sqlActual = sqlActual
    }
}

public typealias EditorGraderFactory = @Sendable (EditorTask, String) async throws -> EditorGradeOutcome

/// 에디터 화면의 상태 모델.
///
/// 목 데이터가 없다 — 기본 팩토리는 실제 백엔드(`SwiftLanguageModule`·`InProcessRunner`·
/// `SwiftTestingGrader`·`SQLResultSetGrader`)를 태운다. 테스트는 `runFactory`·
/// `graderFactory` 를 주입해 프로세스·SQLite 없이 상태 전이만 검증한다 —
/// `LessonFeatureTests` 의 `FakeRunner` 와 같은 이유다: 실제 백엔드의 계약은
/// `RunnerKitTests` 가 이미 검증했고, 여기서 다시 태우면 화면 테스트가 툴체인
/// 유무에 매달린다.
///
/// 모듈 기본 격리가 `MainActor` 다(`Package.swift` 의 `uiSettings`) — 클래스에
/// `@MainActor` 를 다시 적지 않는다.
@Observable
public final class EditorModel {
    /// 결과 패널의 두 탭. SQL 화면(`table` 프리젠터)에는 탭이 없다 — 표 자체가 결과다.
    public enum Tab: String, Sendable, CaseIterable, Hashable {
        case output
        case tests
    }

    public enum RunState: Hashable, Sendable {
        case idle
        case preparing
        case compiling
        case running
        case finished(succeeded: Bool, exitCode: Int32?, durationMilliseconds: Int)
        case failed(String)

        public var isBusy: Bool {
            switch self {
            case .preparing, .compiling, .running: true
            case .idle, .finished, .failed: false
            }
        }
    }

    /// 제출(숨은 테스트 채점 / SQL 결과셋 비교) 상태. `run()` 의 `RunState` 와 분리한
    /// 이유는 콘솔 화면에서 이 둘이 **서로 다른 동작**이기 때문이다 — 실행은 코드를
    /// 그냥 돌려 보는 것이고, 제출은 숨은 테스트로 채점하는 것이다.
    public enum GradeState: Hashable, Sendable {
        case notSubmitted
        case grading
        case graded(GradeResult)
        case failed(String)

        public var isBusy: Bool { self == .grading }

        public var result: GradeResult? {
            if case .graded(let result) = self { return result }
            return nil
        }
    }

    public let task: EditorTask
    public var code: String
    public var activeTab: Tab = .output

    public private(set) var transcript: ConsoleTranscript = .empty
    public private(set) var diagnostics: [Diagnostic] = []
    public private(set) var resultSet: ResultSet?
    public private(set) var runState: RunState = .idle
    public private(set) var gradeState: GradeState = .notSubmitted

    /// SQL 결과 화면 전용 파생값. 채점기가 준 그대로 보관하고, 표에 필요한 행 목록은
    /// ``sqlDiffTables`` 가 매번 순수 계산한다.
    public private(set) var sqlComparison: SQLComparison?
    public private(set) var sqlExpected: ResultSet?
    public private(set) var sqlActual: ResultSet?

    /// 마지막으로 돈 소스 스냅샷. 인라인 진단(`{#inline-diagnostic-row}`)은 이 스냅샷
    /// 기준이다 — 그 뒤 편집이 더해져도 진단이 가리켰던 줄은 바뀌지 않는다.
    private var lastRunSource: String = ""

    private let runFactory: EditorRunFactory?
    private let graderFactory: EditorGraderFactory?

    /// Swift 언어 서버 지원. **Swift 트랙에서만 만들어진다** — 다른 언어 트랙에
    /// LSP 를 붙이는 것은 이 작업의 범위 밖이다.
    ///
    /// `nil` 인 경우가 둘이다: Swift 가 아닌 과제이거나, 아직 `startLanguageSupport()`
    /// 를 부르지 않았거나. 어느 쪽이든 화면은 그대로 동작한다.
    private(set) var languageSupport: SwiftLanguageSupport?

    public init(
        task: EditorTask,
        runFactory: EditorRunFactory? = nil,
        graderFactory: EditorGraderFactory? = nil
    ) {
        self.task = task
        self.code = task.starterSource
        self.runFactory = runFactory
        self.graderFactory = graderFactory
    }

    // MARK: - 파생

    public var presenter: GradeResult.Presenter { EditorModel.presenter(for: task.language) }

    public var canRun: Bool { !runState.isBusy && !gradeState.isBusy }
    public var canSubmit: Bool { !runState.isBusy && !gradeState.isBusy }

    /// `{#inline-diagnostic-row}` 가 그릴 재료. `InlineDiagnosticRow` 는 화면 내부
    /// 프리젠테이션 타입이라 internal 이다 — 뷰(같은 모듈)와 `@testable` 테스트만 본다.
    ///
    /// `{#lsp-diagnostics}`: 언어 서버 진단과 `swiftc` 진단이 **같은 컴포넌트**로
    /// 그려지고 출처는 라벨로만 구분된다. 언어 서버 쪽이 앞이다 — 지금 편집 중인
    /// 코드를 보고 있어 스냅샷이 더 신선하다.
    var diagnosticRows: [InlineDiagnosticRow] {
        var groups: [DiagnosticSourceGroup] = []
        if let languageSupport, !languageSupport.diagnostics.isEmpty {
            groups.append(
                DiagnosticSourceGroup(
                    toolName: EditorModel.languageServerName,
                    code: languageSupport.diagnosticsSnapshot,
                    diagnostics: languageSupport.diagnostics
                )
            )
        }
        if !diagnostics.isEmpty {
            groups.append(
                DiagnosticSourceGroup(
                    toolName: EditorModel.toolName(for: task.language),
                    code: lastRunSource,
                    diagnostics: diagnostics
                )
            )
        }
        return EditorDiagnosticPresentation.rows(groups: groups)
    }

    /// SQL 결과 화면(`{#screen-sql-result}`)이 그릴 두 표. 아직 채점 전이면 nil.
    var sqlDiffTables: SQLDiffTables? {
        guard let sqlComparison, let sqlExpected else { return nil }
        let actualForDisplay = sqlComparison.projectedActual ?? sqlActual ?? ResultSet(columns: [])
        return SQLDiffPresentation.build(
            expected: sqlExpected, actual: actualForDisplay, diff: sqlComparison.diff
        )
    }

    // MARK: - 동작

    /// SQL(`table` 프리젠터)은 실행 자체가 결과셋 비교다 — 원문 출력과 채점된 표가
    /// 따로 있지 않다. 그 밖의 언어는 그냥 돌려 보는 것과 숨은 테스트로 채점하는 것이
    /// 서로 다른 동작이다.
    public func run() async {
        guard canRun else { return }
        if presenter.route == .table {
            await grade()
        } else {
            await performRun()
        }
    }

    public func submit() async {
        guard canSubmit else { return }
        await grade()
    }

    // MARK: - 언어 서버 (`{#sourcekit-lsp-swift}`)

    /// Swift 과제라면 언어 서버를 띄운다. 화면이 나타날 때 한 번 부른다.
    ///
    /// **실패해도 던지지 않는다.** 서버가 없는 머신에서는 완성과 실시간 진단만 없고
    /// 편집·실행·채점·`swiftc` 진단은 전부 그대로다. 이유는 `languageSupport.status`
    /// 에 남는다.
    ///
    /// - Parameter serviceFactory: 테스트가 진짜 서버 대신 끼우는 통로.
    func startLanguageSupport(
        serviceFactory: SwiftLanguageSupport.ServiceFactory? = nil
    ) async {
        guard task.language == .swift, languageSupport == nil else { return }
        let support = SwiftLanguageSupport(
            fileName: task.entryFileName, serviceFactory: serviceFactory
        )
        languageSupport = support
        await support.start(text: code)
    }

    /// 화면이 사라질 때. 서버 프로세스를 거둔다.
    func stopLanguageSupport() async {
        let support = languageSupport
        languageSupport = nil
        await support?.stop()
    }

    /// 편집기 본문이 바뀌었다. 뷰의 `onChange(of: model.code)` 가 부른다.
    ///
    /// 모델이 `code` 의 `didSet` 으로 알아채지 않는 이유: `@Observable` 아래에서
    /// 저장 프로퍼티의 관찰자는 SwiftUI 의 갱신 경로와 얽히기 쉽다. 뷰가 명시적으로
    /// 부르는 편이 언제 나가는지가 눈에 보인다.
    func codeDidChange() async {
        await languageSupport?.documentDidChange(text: code)
    }

    private func performRun() async {
        activeTab = .output
        lastRunSource = code
        transcript = ConsoleTranscript(isRunning: true)
        diagnostics = []
        resultSet = nil
        runState = .preparing

        let request = RunRequest(files: [SourceFile(path: task.entryFileName, contents: code)])
        var sawTermination = false
        do {
            for try await event in stream(for: task.language, request: request) {
                if case .finished = event { sawTermination = true }
                apply(event)
            }
            if !sawTermination {
                // 스트림이 종료 이벤트 없이 닫혔다. 상태를 running 에 남겨 두면 버튼이 영영 잠긴다.
                transcript.isRunning = false
                runState = .finished(succeeded: false, exitCode: nil, durationMilliseconds: 0)
            }
        } catch {
            let reason = EditorModel.describe(error)
            transcript.isRunning = false
            transcript.appendNote(reason)
            runState = .failed(reason)
        }
    }

    private func grade() async {
        if presenter.route != .table { activeTab = .tests }
        gradeState = .grading
        do {
            let outcome = try await gradeOutcome()
            gradeState = .graded(outcome.result)
            if let comparison = outcome.sqlComparison {
                sqlComparison = comparison
                sqlExpected = outcome.sqlExpected
                sqlActual = outcome.sqlActual
                resultSet = outcome.sqlActual
            }
        } catch {
            gradeState = .failed(EditorModel.describe(error))
        }
    }

    private func gradeOutcome() async throws -> EditorGradeOutcome {
        if let graderFactory { return try await graderFactory(task, code) }
        return try await EditorModel.defaultGrade(task: task, code: code)
    }

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

    private func apply(_ event: RunEvent) {
        switch event {
        case .phase(let phase):
            switch phase {
            case .preparing: runState = .preparing
            case .compiling: runState = .compiling
            case .running: runState = .running
            }
        case .standardOutput(let data):
            transcript.append(String(decoding: data, as: UTF8.self), stream: .output)
        case .standardError(let data):
            transcript.append(String(decoding: data, as: UTF8.self), stream: .error)
        case .diagnostic(let diagnostic):
            diagnostics.append(diagnostic)
        case .resultSet(let incoming):
            resultSet = incoming
        case .truncated:
            transcript.markTruncated()
        case .finished(let termination):
            transcript.isRunning = false
            transcript.exitCode = termination.exitCode
            transcript.durationMilliseconds = termination.durationMilliseconds
            runState = .finished(
                succeeded: termination.succeeded,
                exitCode: termination.exitCode,
                durationMilliseconds: termination.durationMilliseconds
            )
        }
    }

    // MARK: - 기본값 — 전부 진짜 백엔드다

    static func presenter(for language: LanguageID) -> GradeResult.Presenter {
        switch language {
        case .python: PythonLanguageModule().presenter
        case .swift: SwiftLanguageModule().presenter
        case .sql: .table
        default: .console
        }
    }

    /// 인라인 진단 행에서 언어 서버 진단에 붙는 라벨. `swiftc` 와 **다른 이름**이어야
    /// `{#lsp-diagnostics}` 의 "출처만 라벨로 구분" 이 성립한다.
    static let languageServerName = "sourcekit-lsp"

    static func toolName(for language: LanguageID) -> String {
        switch language {
        case .swift: "swiftc"
        case .python: "python3"
        case .sql: "sqlite3"
        default: language.rawValue
        }
    }

    static func defaultRunner(for language: LanguageID) throws -> any CodeRunner {
        switch language {
        case .swift: try SwiftLanguageModule().makeRunner()
        case .python: try PythonLanguageModule().makeRunner()
        case .sql: InProcessRunner()
        default: throw RunFailure.backend("실행기가 없는 언어: \(language.rawValue)")
        }
    }

    /// 언어별 진짜 채점기. SQL 은 결과셋 비교, Swift·Python 은 숨은 테스트다.
    static func defaultGrade(task: EditorTask, code: String) async throws -> EditorGradeOutcome {
        switch task.language {
        case .sql:
            let grader = SQLResultSetGrader(
                runner: InProcessRunner(), database: task.database, criteria: task.criteria
            )
            let grading = try await grader.grade(submission: code, reference: task.solutionSource ?? "")
            return EditorGradeOutcome(
                result: grading.result,
                sqlComparison: grading.comparison,
                sqlExpected: grading.expected,
                sqlActual: grading.actual
            )
        case .swift:
            guard let testSource = task.testSource else {
                throw RunFailure.backend("이 과제에는 숨은 테스트가 없습니다")
            }
            let grading = try await SwiftTestingGrader().grade(
                solution: [SourceFile(path: "Solution.swift", contents: code)],
                tests: [SourceFile(path: "SolutionTests.swift", contents: testSource)]
            )
            return EditorGradeOutcome(result: grading.result)
        case .python:
            guard let testSource = task.testSource else {
                throw RunFailure.backend("이 과제에는 숨은 테스트가 없습니다")
            }
            let grading = try await PythonUnittestGrader().grade(
                solution: [SourceFile(path: task.entryFileName, contents: code)],
                tests: testSource
            )
            return EditorGradeOutcome(result: grading.result)
        default:
            throw RunFailure.backend("채점기가 없는 언어: \(task.language.rawValue)")
        }
    }

    static func describe(_ error: any Error) -> String {
        switch error {
        case let failure as RunFailure:
            switch failure {
            case .toolchainMissing(let hint): "툴체인이 없습니다 — \(hint)"
            case .wallClockExceeded(let seconds): "\(seconds)초 안에 끝나지 않았습니다."
            case .cpuExceeded(let seconds): "CPU 시간 \(seconds)초를 넘겼습니다."
            case .memoryExceeded(let megabytes): "메모리 \(megabytes)MB 를 넘겼습니다."
            case .fileSizeExceeded(let bytes): "출력 파일이 \(bytes) 바이트를 넘겼습니다."
            case .cancelled: "실행이 취소되었습니다."
            case .backend(let message): message
            }
        default:
            "\(error)"
        }
    }
}
