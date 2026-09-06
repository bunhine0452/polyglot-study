internal import GRDB
internal import LearnCore

// MARK: - submission

struct SubmissionRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "submission"

    var id: Int64?
    var packID: String
    var lessonID: String
    var blockIndex: Int
    var languageID: String
    var submittedAt: Int64
    var passed: Bool
    var sourceCode: String
    var stdout: String
    var stderr: String
    var exitCode: Int32?
    var durationMS: Int
    var presenter: String
    var runnerBackend: String
    var toolchainVersion: String?
    var failureKind: String?

    init(row: Row) {
        id = row["id"]
        packID = row["pack_id"]
        lessonID = row["lesson_id"]
        blockIndex = row["block_index"]
        languageID = row["language_id"]
        submittedAt = row["submitted_at"]
        passed = row["passed"]
        sourceCode = row["source_code"]
        stdout = row["stdout"]
        stderr = row["stderr"]
        exitCode = row["exit_code"]
        durationMS = row["duration_ms"]
        presenter = row["presenter"]
        runnerBackend = row["runner_backend"]
        toolchainVersion = row["toolchain_version"]
        failureKind = row["failure_kind"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["pack_id"] = packID
        container["lesson_id"] = lessonID
        container["block_index"] = blockIndex
        container["language_id"] = languageID
        container["submitted_at"] = submittedAt
        container["passed"] = passed
        container["source_code"] = sourceCode
        container["stdout"] = stdout
        container["stderr"] = stderr
        container["exit_code"] = exitCode.map { Int64($0) }
        container["duration_ms"] = durationMS
        container["presenter"] = presenter
        container["runner_backend"] = runnerBackend
        container["toolchain_version"] = toolchainVersion
        container["failure_kind"] = failureKind
    }

    /// - Important: `stdout` / `stderr` 절단은 여기서 하지 않는다. 스토어가
    ///   `normalizedForStorage()` 를 거친 값을 넘긴다 — 절단 지점이 둘이면 어느 쪽이 돌았는지 모른다.
    init(_ record: SubmissionRecord) {
        id = record.id?.rawValue
        packID = record.packID.rawValue
        lessonID = record.lessonID.rawValue
        blockIndex = record.blockIndex
        languageID = record.languageID.rawValue
        submittedAt = record.submittedAt.sqlValue
        passed = record.passed
        sourceCode = record.sourceCode
        stdout = record.stdout
        stderr = record.stderr
        exitCode = record.exitCode
        durationMS = record.durationMilliseconds
        presenter = record.presenter.rawValue
        runnerBackend = record.runnerBackend.rawValue
        toolchainVersion = record.toolchainVersion
        failureKind = record.failureKind?.rawValue
    }

    func toRecord(diagnostics: [Diagnostic]) throws -> SubmissionRecord {
        guard let presenter = GradeResult.Presenter(rawValue: presenter) else {
            throw StoreError.storage(message: "submission.presenter: \(presenter)")
        }
        guard let backend = RunnerBackend(rawValue: runnerBackend) else {
            throw StoreError.storage(message: "submission.runner_backend: \(runnerBackend)")
        }
        var kind: SubmissionFailureKind?
        if let failureKind {
            guard let parsed = SubmissionFailureKind(rawValue: failureKind) else {
                throw StoreError.storage(message: "submission.failure_kind: \(failureKind)")
            }
            kind = parsed
        }
        return SubmissionRecord(
            id: id.map { SubmissionID($0) },
            packID: PackID(packID),
            lessonID: LessonID(lessonID),
            blockIndex: blockIndex,
            languageID: LanguageID(languageID),
            submittedAt: EpochMillis(sqlValue: submittedAt),
            passed: passed,
            sourceCode: sourceCode,
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
            durationMilliseconds: durationMS,
            presenter: presenter,
            runnerBackend: backend,
            toolchainVersion: toolchainVersion,
            failureKind: kind,
            diagnostics: diagnostics
        )
    }
}

// MARK: - diagnostic

struct DiagnosticRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "diagnostic"

    var id: Int64?
    var submissionID: Int64
    var ordinal: Int
    var file: String?
    var line: Int?
    var column: Int?
    var severity: String
    var message: String
    var ruleID: String?

    init(row: Row) {
        id = row["id"]
        submissionID = row["submission_id"]
        ordinal = row["ordinal"]
        file = row["file"]
        line = row["line"]
        column = row["column"]
        severity = row["severity"]
        message = row["message"]
        ruleID = row["rule_id"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["submission_id"] = submissionID
        container["ordinal"] = ordinal
        container["file"] = file
        container["line"] = line
        container["column"] = column
        container["severity"] = severity
        container["message"] = message
        container["rule_id"] = ruleID
    }

    init(_ diagnostic: Diagnostic, submissionID: Int64, ordinal: Int) {
        self.id = nil
        self.submissionID = submissionID
        self.ordinal = ordinal
        self.file = diagnostic.file
        self.line = diagnostic.line
        self.column = diagnostic.column
        self.severity = diagnostic.severity.rawValue
        self.message = diagnostic.message
        self.ruleID = diagnostic.ruleID
    }

    func toDiagnostic() throws -> Diagnostic {
        guard let severity = Diagnostic.Severity(rawValue: severity) else {
            throw StoreError.storage(message: "diagnostic.severity: \(severity)")
        }
        return Diagnostic(
            file: file,
            line: line,
            column: column,
            severity: severity,
            message: message,
            ruleID: ruleID
        )
    }
}

// MARK: - mistake_note

struct MistakeNoteRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "mistake_note"

    var id: Int64?
    var cardID: String?
    var languageID: String
    var packID: String?
    var lessonID: String?
    var title: String
    var body: String
    var createdAt: Int64
    var updatedAt: Int64

    init(row: Row) {
        id = row["id"]
        cardID = row["card_id"]
        languageID = row["language_id"]
        packID = row["pack_id"]
        lessonID = row["lesson_id"]
        title = row["title"]
        body = row["body"]
        createdAt = row["created_at"]
        updatedAt = row["updated_at"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["card_id"] = cardID
        container["language_id"] = languageID
        container["pack_id"] = packID
        container["lesson_id"] = lessonID
        container["title"] = title
        container["body"] = body
        container["created_at"] = createdAt
        container["updated_at"] = updatedAt
    }

    init(_ note: MistakeNote) {
        id = note.id?.rawValue
        cardID = note.cardID?.rawValue
        languageID = note.languageID.rawValue
        packID = note.packID?.rawValue
        lessonID = note.lessonID?.rawValue
        title = note.title
        body = note.body
        createdAt = note.createdAt.sqlValue
        updatedAt = note.updatedAt.sqlValue
    }

    func toNote() -> MistakeNote {
        MistakeNote(
            id: id.map { MistakeNoteID($0) },
            cardID: cardID.map { CardID($0) },
            languageID: LanguageID(languageID),
            packID: packID.map { PackID($0) },
            lessonID: lessonID.map { LessonID($0) },
            title: title,
            body: body,
            createdAt: EpochMillis(sqlValue: createdAt),
            updatedAt: EpochMillis(sqlValue: updatedAt)
        )
    }
}

// MARK: - lesson_progress

struct LessonProgressRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "lesson_progress"

    var packID: String
    var lessonID: String
    var languageID: String
    var status: String
    /// JSON 정수 배열.
    var completedBlocks: String
    var currentBlockIndex: Int
    var startedAt: Int64?
    var lastActivityAt: Int64?
    var completedAt: Int64?

    init(row: Row) {
        packID = row["pack_id"]
        lessonID = row["lesson_id"]
        languageID = row["language_id"]
        status = row["status"]
        completedBlocks = row["completed_blocks"]
        currentBlockIndex = row["current_block_index"]
        startedAt = row["started_at"]
        lastActivityAt = row["last_activity_at"]
        completedAt = row["completed_at"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["pack_id"] = packID
        container["lesson_id"] = lessonID
        container["language_id"] = languageID
        container["status"] = status
        container["completed_blocks"] = completedBlocks
        container["current_block_index"] = currentBlockIndex
        container["started_at"] = startedAt
        container["last_activity_at"] = lastActivityAt
        container["completed_at"] = completedAt
    }

    init(_ progress: LessonProgress) throws {
        packID = progress.packID.rawValue
        lessonID = progress.lessonID.rawValue
        languageID = progress.languageID.rawValue
        status = progress.status.rawValue
        completedBlocks = try JSONArray.encode(progress.completedBlocks)
        currentBlockIndex = progress.currentBlockIndex
        startedAt = progress.startedAt?.sqlValue
        lastActivityAt = progress.lastActivityAt?.sqlValue
        completedAt = progress.completedAt?.sqlValue
    }

    func toProgress() throws -> LessonProgress {
        guard let status = LessonStatus(rawValue: status) else {
            throw StoreError.storage(message: "lesson_progress.status: \(status)")
        }
        return LessonProgress(
            packID: PackID(packID),
            lessonID: LessonID(lessonID),
            languageID: LanguageID(languageID),
            status: status,
            completedBlocks: try JSONArray.decodeInts(completedBlocks),
            currentBlockIndex: currentBlockIndex,
            startedAt: startedAt.map(EpochMillis.init(sqlValue:)),
            lastActivityAt: lastActivityAt.map(EpochMillis.init(sqlValue:)),
            completedAt: completedAt.map(EpochMillis.init(sqlValue:))
        )
    }
}
