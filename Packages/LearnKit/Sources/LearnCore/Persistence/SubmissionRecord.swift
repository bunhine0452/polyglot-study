/// 이 제출을 어느 백엔드가 실행했는가.
///
/// `CodeRunner` 구현과 1:1 대응하지만 `LanguageKit` 이 아니라 여기 있다 — `LearnCore` 는
/// `LanguageKit` 을 의존하지 않고(의존 방향이 반대), 저장된 과거 행은 백엔드가 삭제돼도 읽혀야 한다.
public enum RunnerBackend: String, Hashable, Sendable, Codable, CaseIterable {
    case inProcess
    case webView
    case subprocess
    case emulator
    case remote
}

/// 실패한 제출의 분류. 통과한 제출은 nil 이다.
///
/// `RunFailure` 케이스에 채점 단계의 실패 셋(`compileError`·`testFailure`·`wrongResult`)을 더한 것이다.
/// `cpuExceeded` 와 `wallClockExceeded` 를 나눠 두는 게 핵심 — 전자는 "코드가 느리다",
/// 후자는 "코드가 멈췄다" 로 사용자에게 완전히 다른 의미다.
public enum SubmissionFailureKind: String, Hashable, Sendable, Codable, CaseIterable {
    case compileError
    case testFailure
    case wrongResult
    case toolchainMissing
    case wallClockExceeded
    case cpuExceeded
    case memoryExceeded
    case cancelled
    case backend
}

/// `submission` 한 행 + 딸린 `diagnostic` N 행. **한 트랜잭션으로** 기록된다.
///
/// `GradeResult` 하나가 정확히 이 애그리게이트 하나가 된다. 진단을 별도 테이블로 정규화하는 이유는
/// gutter 렌더링이 `WHERE submission_id = ? ORDER BY ordinal` 로 끝나야 하고,
/// JSON blob 으로 넣으면 "최근 실패에서 가장 흔한 에러" 같은 집계가 불가능해지기 때문이다.
public struct SubmissionRecord: Hashable, Sendable {
    /// 저장 전에는 nil.
    public var id: SubmissionID?
    public var packID: PackID
    public var lessonID: LessonID
    /// 6블록 시퀀스 안의 위치. 0..<`LessonBlockSequence.count`.
    public var blockIndex: Int
    public var languageID: LanguageID
    public var submittedAt: EpochMilliseconds
    public var passed: Bool
    public var sourceCode: String
    /// 저장 시 `PersistenceLimits.submissionOutputBytes` 로 잘린다.
    public var stdout: String
    /// 저장 시 `PersistenceLimits.submissionOutputBytes` 로 잘린다.
    public var stderr: String
    public var exitCode: Int32?
    public var durationMilliseconds: Int
    public var presenter: GradeResult.Presenter
    public var runnerBackend: RunnerBackend
    /// `swiftc-6.3.3` 처럼. 같은 코드가 어제는 통과하고 오늘 실패할 때 유일한 단서다.
    public var toolchainVersion: String?
    public var failureKind: SubmissionFailureKind?
    /// 배열 순서가 곧 `diagnostic.ordinal` 이다. 컴파일러가 낸 순서에 의미가 있어 보존한다.
    public var diagnostics: [Diagnostic]

    public init(
        id: SubmissionID? = nil,
        packID: PackID,
        lessonID: LessonID,
        blockIndex: Int,
        languageID: LanguageID,
        submittedAt: EpochMilliseconds,
        passed: Bool,
        sourceCode: String,
        stdout: String = "",
        stderr: String = "",
        exitCode: Int32? = nil,
        durationMilliseconds: Int,
        presenter: GradeResult.Presenter,
        runnerBackend: RunnerBackend,
        toolchainVersion: String? = nil,
        failureKind: SubmissionFailureKind? = nil,
        diagnostics: [Diagnostic] = []
    ) {
        self.id = id
        self.packID = packID
        self.lessonID = lessonID
        self.blockIndex = blockIndex
        self.languageID = languageID
        self.submittedAt = submittedAt
        self.passed = passed
        self.sourceCode = sourceCode
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.durationMilliseconds = durationMilliseconds
        self.presenter = presenter
        self.runnerBackend = runnerBackend
        self.toolchainVersion = toolchainVersion
        self.failureKind = failureKind
        self.diagnostics = diagnostics
    }
}

extension SubmissionRecord {
    /// 채점 결과 하나를 그대로 제출 한 건으로 옮긴다.
    ///
    /// `failureKind` 를 채점 결과에서 **추론하지 않고** 인자로 받는 이유: `GradeResult` 는 실패의
    /// 종류를 모른다. 벽시계 초과와 CPU 초과는 `RunFailure` 로 던져지고 `GradeResult` 까지 오지 않으며,
    /// 여기서 짐작하면 `.testFailure` 로 뭉개진다.
    public init(
        grading result: GradeResult,
        packID: PackID,
        lessonID: LessonID,
        blockIndex: Int,
        languageID: LanguageID,
        submittedAt: EpochMilliseconds,
        sourceCode: String,
        runnerBackend: RunnerBackend,
        toolchainVersion: String? = nil,
        failureKind: SubmissionFailureKind? = nil
    ) {
        self.init(
            packID: packID,
            lessonID: lessonID,
            blockIndex: blockIndex,
            languageID: languageID,
            submittedAt: submittedAt,
            passed: result.passed,
            sourceCode: sourceCode,
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode,
            durationMilliseconds: result.durationMilliseconds,
            presenter: result.presenter,
            runnerBackend: runnerBackend,
            toolchainVersion: toolchainVersion,
            failureKind: result.passed
                ? nil
                : (failureKind ?? (result.hasErrors ? .compileError : .testFailure)),
            diagnostics: result.diagnostics
        )
    }

    /// 쓰기 직전에 적용할 정규화. 스토어 구현이 반드시 통과시킨다.
    public func normalizedForStorage() -> SubmissionRecord {
        var copy = self
        copy.stdout = PersistenceLimits.truncateForStorage(stdout)
        copy.stderr = PersistenceLimits.truncateForStorage(stderr)
        return copy
    }
}
