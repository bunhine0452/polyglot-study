public import ContentKit
public import DesignSystem
public import LanguageKit
public import LearnCore
public import Observation
internal import Foundation
internal import RunnerKit

/// 레슨 화면의 상태 모델.
///
/// 화면의 계약은 하나다 — **펼쳐진 블록은 항상 정확히 하나**다. 6블록이 한 화면에
/// 다 펼쳐지면 스크롤이 화면을 지배하고, 학습자가 "지금 무엇을 하는 중인지"가 사라진다.
/// 그래서 완료 블록은 한 줄로 접히고, 다음 블록은 흐린 한 줄로 예고되고, 그 뒤는
/// 통째로 한 줄에 묶인다.
///
/// 모듈 기본 격리가 `MainActor` 라(`Package.swift` 의 `uiSettings`) 클래스에 `@MainActor`
/// 를 다시 적지 않는다.
@Observable
public final class LessonModel {
    // MARK: - 스텝

    public enum StepState: String, Sendable, Hashable, CaseIterable {
        /// 지나온 블록 — 체크.
        case done
        /// 지금 블록 — 반전.
        case active
        /// 아직 안 온 블록 — 흐림.
        case upcoming
    }

    /// 상단 스텝바 한 칸. 여섯 개가 고정이다.
    public struct Step: Identifiable, Sendable, Hashable {
        public let id: String
        public let index: Int
        public let kind: LessonBlockKind
        /// 블록 이름 — "개념", "실행 예제" …
        public let name: String
        /// 접힌 행에 붙는 한 줄 요약. 산문에서 뽑는다.
        public let summary: String
        public var state: StepState

        /// 스텝바의 두 자리 번호. `01` … `06`.
        public var ordinal: String { index < 9 ? "0\(index + 1)" : "\(index + 1)" }
    }

    /// 본문에 실제로 그려지는 행. **`expanded` 는 언제나 정확히 하나**다.
    public enum BodyRow: Hashable, Sendable, Identifiable {
        /// 완료 — 40px 접힘 행.
        case collapsed(index: Int)
        /// 지금 — 카드.
        case expanded(index: Int)
        /// 바로 다음 — 흐린 한 줄.
        case upcoming(index: Int)
        /// 그 뒤 전부 — 한 줄로 묶는다(`04 – 06`).
        case remaining(first: Int, last: Int)

        public var id: String {
            switch self {
            case .collapsed(let index): "collapsed-\(index)"
            case .expanded(let index): "expanded-\(index)"
            case .upcoming(let index): "upcoming-\(index)"
            case .remaining(let first, let last): "remaining-\(first)-\(last)"
            }
        }

        /// 이 행이 덮는 블록 인덱스.
        public var indices: [Int] {
            switch self {
            case .collapsed(let index), .expanded(let index), .upcoming(let index): [index]
            case .remaining(let first, let last): Array(first...last)
            }
        }
    }

    // MARK: - 실행

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

        /// 실행 버튼 옆에 붙는 한 마디.
        public var label: String {
            switch self {
            case .idle: "실행 전"
            case .preparing: "준비 중"
            case .compiling: "컴파일 중"
            case .running: "실행 중"
            case .finished(_, let exitCode, let duration):
                "\(duration) ms · 종료 \(exitCode.map(String.init) ?? "—")"
            case .failed(let reason): reason
            }
        }
    }

    // MARK: - 상태

    public let content: LessonContent
    public private(set) var activeIndex: Int = 0

    /// 진도를 뺀 스텝 원본. 초기화 때 한 번만 만든다.
    private let baseSteps: [Step]

    public private(set) var transcript: ConsoleTranscript = .empty
    public private(set) var resultSet: ResultSet?
    public private(set) var diagnostics: [Diagnostic] = []
    public private(set) var runState: RunState = .idle

    /// 빈칸 슬롯에 학습자가 적은 값. 키는 1-기반 슬롯 번호.
    public var blankEntries: [Int: String] = [:]
    public private(set) var blankChecked = false

    public private(set) var selectedChoiceID: String?
    public private(set) var quizRevealed = false

    /// 회고 답변. 채점하지 않는다 — 나중에 노트로 저장된다.
    public var reflectionNotes: [String: String] = [:]

    /// `nil` 이면 실제 러너(`PythonLanguageModule`·`SwiftLanguageModule`·`InProcessRunner`)로
    /// 떨어진다.
    ///
    /// **기본 인자 값으로 클로저를 주지 않는다.** async `@Sendable` 클로저를 `@MainActor`
    /// 격리 `public init` 의 기본 인자로 두고 다른 모듈에서 그 파라미터를 생략해 호출하면
    /// `freed pointer was not the last allocation` 으로 프로세스가 죽는다(온보딩 세션이
    /// 실측으로 밟았고 100% 재현). `nil` 기본값 + 내부 폴백 분기가 그 조합을 피한다.
    private let runFactory:
        (@Sendable (LanguageID, RunRequest) -> AsyncThrowingStream<RunEvent, any Error>)?
    private let onOpenEditor: ((TaskBlock) -> Void)?

    public init(
        content: LessonContent,
        runFactory: (
            @Sendable (LanguageID, RunRequest) -> AsyncThrowingStream<RunEvent, any Error>
        )? = nil,
        onOpenEditor: ((TaskBlock) -> Void)? = nil
    ) {
        self.content = content
        self.runFactory = runFactory
        self.onOpenEditor = onOpenEditor
        self.baseSteps = content.blocks.enumerated().map { index, block in
            Step(
                id: block.id,
                index: index,
                kind: block.kind,
                name: LessonModel.name(for: block.kind),
                summary: LessonModel.summary(of: block),
                state: index == 0 ? .active : .upcoming
            )
        }
    }

    /// 팩에서 바로. 화면이 목 데이터를 볼 일이 없게 하는 경로다.
    public convenience init(
        pack: ContentPack,
        lessonID: LessonID,
        runFactory: (
            @Sendable (LanguageID, RunRequest) -> AsyncThrowingStream<RunEvent, any Error>
        )? = nil,
        onOpenEditor: ((TaskBlock) -> Void)? = nil
    ) throws(ContentPackError) {
        self.init(
            content: try LessonContent.load(pack: pack, lessonID: lessonID),
            runFactory: runFactory,
            onOpenEditor: onOpenEditor
        )
    }

    // MARK: - 파생

    public var blocks: [LessonBlock] { content.blocks }
    public var language: LanguageID { content.language }
    public var presenter: GradeResult.Presenter { LessonPresentation.presenter(for: language) }

    /// 헤더의 `Swift · 레슨 07 / 24`.
    public var trackCaption: String {
        "\(content.trackName) · 레슨 \(twoDigits(content.order)) / \(content.totalInTrack)"
    }

    /// 헤더 오른쪽의 `블록 2 / 6`.
    public var blockCaption: String { "블록 \(activeIndex + 1) / \(blocks.count)" }

    /// 스텝은 진도(`state`)만 빼면 레슨이 로드될 때 확정된다.
    ///
    /// 요약을 뽑는 데 마크다운 파싱이 든다. `steps` 를 매번 처음부터 만들면 SwiftUI 가
    /// 본문을 다시 그릴 때마다 6블록의 산문을 다시 파싱한다 — 그래서 한 번만 만들고
    /// 진도만 얹는다.
    public var steps: [Step] {
        baseSteps.enumerated().map { index, base in
            var step = base
            step.state = index < activeIndex ? .done : (index == activeIndex ? .active : .upcoming)
            return step
        }
    }

    public var activeBlock: LessonBlock? {
        blocks.indices.contains(activeIndex) ? blocks[activeIndex] : nil
    }

    /// 본문 행. 완료는 낱개로, 다음 하나는 예고로, 그 뒤는 한 줄로 묶는다.
    public var bodyRows: [BodyRow] {
        guard !blocks.isEmpty else { return [] }
        var rows: [BodyRow] = (0..<activeIndex).map { .collapsed(index: $0) }
        rows.append(.expanded(index: activeIndex))
        let next = activeIndex + 1
        guard next < blocks.count else { return rows }
        rows.append(.upcoming(index: next))
        if next + 1 < blocks.count {
            rows.append(.remaining(first: next + 1, last: blocks.count - 1))
        }
        return rows
    }

    public var canAdvance: Bool { activeIndex + 1 < blocks.count }

    /// 다음 블록 버튼의 제목 — `다음 블록 · 빈칸`.
    public var advanceTitle: String? {
        guard canAdvance else { return nil }
        return "다음 블록 · \(Self.name(for: blocks[activeIndex + 1].kind))"
    }

    // MARK: - 이동

    public func advance() {
        guard canAdvance else { return }
        activeIndex += 1
        resetTransientState()
    }

    /// 접힌 행의 "다시 보기". 앞으로는 못 간다 — 스텝바가 진도를 뜻해야 하기 때문이다.
    ///
    /// 지금 블록을 다시 누르는 것은 **아무 일도 하지 않는다**. 여기서 상태를 비우면
    /// 스텝바를 잘못 눌렀을 때 적어 둔 답이 사라진다.
    public func revisit(_ index: Int) {
        guard blocks.indices.contains(index), index < activeIndex else { return }
        activeIndex = index
        resetTransientState()
    }

    private func resetTransientState() {
        transcript = .empty
        resultSet = nil
        diagnostics = []
        runState = .idle
        blankChecked = false
        quizRevealed = false
        selectedChoiceID = nil
        blankEntries = [:]
    }

    // MARK: - 실행 예제

    /// `@Example` 의 코드를 실제 러너로 태우고 `RunEvent` 를 출력 슬롯에 흘린다.
    public func runExample() async {
        guard let example = content.document.example(for: content.language), !runState.isBusy else { return }
        transcript = ConsoleTranscript(isRunning: true)
        resultSet = nil
        diagnostics = []
        runState = .preparing

        let request = RunRequest(
            files: [
                SourceFile(path: Self.entryFileName(for: example.language), contents: example.code)
            ]
        )
        var sawTermination = false
        do {
            for try await event in stream(for: example.language, request: request) {
                if case .finished = event { sawTermination = true }
                apply(event)
            }
            if !sawTermination {
                // 스트림이 종료 이벤트 없이 닫혔다. 상태를 running 에 남겨 두면 버튼이 영영 잠긴다.
                transcript.isRunning = false
                runState = .finished(succeeded: false, exitCode: nil, durationMilliseconds: 0)
            }
        } catch {
            let reason = Self.describe(error)
            transcript.isRunning = false
            transcript.appendNote(reason)
            runState = .failed(reason)
        }
    }

    /// 실행 결과가 팩의 기대 출력과 같은가. 기대 파일이 없거나 아직 안 돌렸으면 nil.
    public var matchesExpectedOutput: Bool? {
        guard let expected = content.expectedOutput, case .finished = runState else { return nil }
        return normalize(transcript.standardOutputText) == normalize(expected)
    }

    /// 앞뒤 빈 줄과 줄 끝 공백만 지운다. 그 이상 손대면 "같다"가 거짓말이 된다.
    private func normalize(_ text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    private func stream(for language: LanguageID, request: RunRequest)
        -> AsyncThrowingStream<RunEvent, any Error>
    {
        if let runFactory { return runFactory(language, request) }
        do {
            return try Self.defaultRunner(for: language).run(request)
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

    // MARK: - 빈칸

    public func checkBlanks() {
        blankChecked = true
    }

    /// 슬롯별 정오. 아직 채점 전이면 빈 사전이다.
    public var blankResults: [Int: Bool] {
        guard blankChecked, let blank = content.document.blank(for: content.language) else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: blank.slots.map {
                ($0.index, Self.matches($0.answer, blankEntries[$0.index] ?? ""))
            }
        )
    }

    public var blanksAreComplete: Bool {
        guard let blank = content.document.blank(for: content.language) else { return false }
        return blank.slots.allSatisfy { !(blankEntries[$0.index] ?? "").trimmed.isEmpty }
    }

    public var blanksAreCorrect: Bool {
        let results = blankResults
        return !results.isEmpty && results.values.allSatisfy { $0 }
    }

    /// 정답 비교. 앞뒤 공백과 후행 세미콜론만 무시한다 — 그 이상 관대하면 채점이 거짓말이 된다.
    static func matches(_ answer: String, _ typed: String) -> Bool {
        func canonical(_ text: String) -> String {
            var value = text.trimmed
            while value.hasSuffix(";") { value = String(value.dropLast()).trimmed }
            return value
        }
        let expected = canonical(answer)
        let actual = canonical(typed)
        if expected == actual { return true }
        // SQL 키워드처럼 대소문자가 의미 없는 정답이 있다. 알파벳만으로 이뤄진 정답에만 허용한다.
        let alphabetic = expected.allSatisfy { $0.isLetter || $0 == "_" }
        return alphabetic && expected.lowercased() == actual.lowercased()
    }

    // MARK: - 퀴즈

    public func selectChoice(_ id: String) {
        guard !quizRevealed else { return }
        selectedChoiceID = id
    }

    public func revealQuiz() {
        guard selectedChoiceID != nil else { return }
        quizRevealed = true
    }

    public var quizIsCorrect: Bool? {
        guard let quiz = content.document.quiz, let selectedChoiceID else { return nil }
        return selectedChoiceID == quiz.answerID
    }

    // MARK: - 과제

    public func openEditor() {
        guard let task = content.document.task(for: content.language) else { return }
        onOpenEditor?(task)
    }

    public var canOpenEditor: Bool { onOpenEditor != nil && content.document.task(for: content.language) != nil }

    // MARK: - 주 동작

    /// 활성 블록이 제안하는 단 하나의 동작. 카드 하단 왼쪽 버튼이 이것이다.
    ///
    /// 블록마다 다른 버튼을 뷰가 각자 조립하면 "무엇이 주 동작인지"가 화면마다 흔들린다.
    /// 개념·회고에는 주 동작이 없다 — 읽고 넘어가는 블록이다.
    public enum PrimaryAction: String, Hashable, Sendable, CaseIterable {
        case run
        case checkBlanks
        case revealQuiz
        case openEditor

        public var title: String {
            switch self {
            case .run: "실행"
            case .checkBlanks: "채점"
            case .revealQuiz: "확인"
            case .openEditor: "에디터에서 열기"
            }
        }

        public var shortcutHint: String? {
            switch self {
            case .run: "⌘↩"
            case .checkBlanks, .revealQuiz, .openEditor: nil
            }
        }
    }

    public var primaryAction: PrimaryAction? {
        switch activeBlock?.kind {
        case .example?: .run
        case .blank?: .checkBlanks
        case .quiz?: .revealQuiz
        case .task?: canOpenEditor ? .openEditor : nil
        case .concept?, .reflection?, nil: nil
        }
    }

    public var primaryActionIsEnabled: Bool {
        switch primaryAction {
        case .run?: !runState.isBusy
        case .checkBlanks?: blanksAreComplete && !blankChecked
        case .revealQuiz?: selectedChoiceID != nil && !quizRevealed
        case .openEditor?: true
        case nil: false
        }
    }

    public func performPrimaryAction() async {
        switch primaryAction {
        case .run?: await runExample()
        case .checkBlanks?: checkBlanks()
        case .revealQuiz?: revealQuiz()
        case .openEditor?: openEditor()
        case nil: break
        }
    }

    // MARK: - 표기

    public static func name(for kind: LessonBlockKind) -> String {
        switch kind {
        case .concept: "개념"
        case .example: "실행 예제"
        case .blank: "빈칸"
        case .task: "테스트 과제"
        case .quiz: "퀴즈"
        case .reflection: "회고"
        }
    }

    /// 접힌 행에 붙는 한 줄. 전부 **레슨 본문에서** 뽑는다.
    static func summary(of block: LessonBlock) -> String {
        switch block {
        case .concept(let concept): ProseSummary.headline(concept.prose)
        case .example(let example): ProseSummary.headline(example.prose)
        case .blank(let blank): ProseSummary.headline(blank.prose)
        case .task(let task): ProseSummary.headline(task.prose)
        case .quiz(let quiz): ProseSummary.headline(quiz.question)
        case .reflection(let reflection):
            reflection.prompts.first.map { ProseSummary.headline($0.prose) } ?? ""
        }
    }

    /// 실행 워크스페이스에 놓일 파일 이름. 각 어댑터의 기본 진입점과 같아야 한다.
    static func entryFileName(for language: LanguageID) -> String {
        switch language {
        case .python: "main.py"
        case .swift: "main.swift"
        case .sql: "query.sql"
        default: "main.txt"
        }
    }

    static func defaultRunner(for language: LanguageID) throws -> any CodeRunner {
        switch language {
        case .python: try PythonLanguageModule().makeRunner()
        case .swift: try SwiftLanguageModule().makeRunner()
        case .sql: InProcessRunner()
        default: throw RunFailure.backend("실행기가 없는 언어: \(language.rawValue)")
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

    private func twoDigits(_ value: Int) -> String {
        value >= 0 && value < 10 ? "0\(value)" : "\(value)"
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
