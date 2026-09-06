import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// 같은 스위트를 두 주입으로 돌리기 위한 파라미터.
///
/// `{#learn-database}` 의 완료 기준이 정확히 이것 — 파일(`DatabasePool` + WAL)과
/// 인메모리(`DatabaseQueue`)가 `any DatabaseWriter` 하나로 주입되므로 테스트가 갈라지지 않아야 한다.
enum DatabaseFlavor: String, CaseIterable, Sendable, CustomStringConvertible {
    case inMemory
    case file

    var description: String { rawValue }
    var expectedJournalMode: String { self == .file ? "wal" : "memory" }
}

/// 테스트 DB 하나. `deinit` 에서 임시 디렉터리를 지운다.
final class TestDatabase: @unchecked Sendable {
    let database: LearnDatabase
    private let directory: URL?

    init(_ flavor: DatabaseFlavor) throws {
        switch flavor {
        case .inMemory:
            database = try LearnDatabase.inMemory()
            directory = nil
        case .file:
            let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("LearnKitTests-\(UUID().uuidString)", isDirectory: true)
            directory = base
            database = try LearnDatabase.open(at: base.appendingPathComponent("learn.sqlite"))
        }
    }

    deinit {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }
}

// MARK: - 픽스처

enum Fixture {
    /// 2026-01-01T00:00:00Z.
    static let epoch: EpochMilliseconds = 1_767_225_600_000
    static let day: EpochMilliseconds = 86_400_000

    static func reviewEntry(
        card: String = "py-001",
        at offsetDays: Int64 = 0,
        rating: ReviewRating = .good,
        stateBefore: LearningState = .new,
        source: ReviewSource = .scheduled
    ) -> ReviewLogEntry {
        ReviewLogEntry(
            cardID: CardID(card),
            reviewedAt: epoch + offsetDays * day,
            rating: rating,
            stateBefore: stateBefore,
            elapsedDays: Int(offsetDays),
            scheduledDays: 1,
            reviewDurationMilliseconds: 4_200,
            source: source
        )
    }

    static func cardState(
        card: String = "py-001",
        language: LanguageID = .python,
        dueOffsetDays: Int64 = 1,
        derivedFrom: ReviewLogID? = nil,
        parameterSet: ParameterSetID = .fsrs6Default
    ) -> CardStateSnapshot {
        CardStateSnapshot(
            cardID: CardID(card),
            languageID: language,
            stability: 3.5,
            difficulty: 5.25,
            dueAt: epoch + dueOffsetDays * day,
            lastReviewedAt: epoch,
            state: .review,
            reps: 2,
            lapses: 0,
            scheduledDays: Int(dueOffsetDays),
            derivedFromLogID: derivedFrom,
            parameterSetID: parameterSet,
            rebuiltAt: epoch
        )
    }

    static func submission(
        pack: String = "pack-python-core",
        lesson: String = "py-lesson-01",
        block: Int = 3,
        passed: Bool = false,
        stdout: String = "",
        stderr: String = "",
        diagnostics: [Diagnostic] = [],
        failureKind: SubmissionFailureKind? = .testFailure
    ) -> SubmissionRecord {
        SubmissionRecord(
            packID: PackID(pack),
            lessonID: LessonID(lesson),
            blockIndex: block,
            languageID: .python,
            submittedAt: epoch,
            passed: passed,
            sourceCode: "print('hello')",
            stdout: stdout,
            stderr: stderr,
            exitCode: passed ? 0 : 1,
            durationMilliseconds: 120,
            presenter: .console,
            runnerBackend: .subprocess,
            toolchainVersion: "python3-3.13.12",
            failureKind: passed ? nil : failureKind,
            diagnostics: diagnostics
        )
    }

    static func note(
        title: String,
        body: String,
        language: LanguageID = .python
    ) -> MistakeNote {
        MistakeNote(
            languageID: language,
            title: title,
            body: body,
            createdAt: epoch,
            updatedAt: epoch
        )
    }
}

// MARK: - SQLite 결과코드

enum SQLiteResultCode {
    static let constraint: Int32 = 19          // SQLITE_CONSTRAINT
    static let constraintTrigger: Int32 = 1811 // SQLITE_CONSTRAINT_TRIGGER  (19 | 7<<8)
    static let constraintCheck: Int32 = 275    // SQLITE_CONSTRAINT_CHECK    (19 | 1<<8)
    static let constraintUnique: Int32 = 2067  // SQLITE_CONSTRAINT_UNIQUE   (19 | 8<<8)
    static let constraintForeignKey: Int32 = 787 // SQLITE_CONSTRAINT_FOREIGNKEY (19 | 3<<8)
}

/// 소스 트리 루트 — CI grep 성격의 테스트가 파일을 직접 훑는 데 쓴다.
enum SourceTree {
    /// `Tests/LearnPersistenceTests/Support/TestDatabases.swift` 로부터 4단계 위가 `Packages/LearnKit`.
    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Support
            .deletingLastPathComponent()  // LearnPersistenceTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // LearnKit
    }

    static func swiftFiles(under relativePath: String) throws -> [URL] {
        let root = packageRoot.appendingPathComponent(relativePath, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }
}
