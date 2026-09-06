internal import GRDB
internal import LearnCore

/// `submission` + `diagnostic`.
struct GRDBSubmissionStore: SubmissionStore {
    let writer: any DatabaseWriter

    @discardableResult
    func record(_ submission: SubmissionRecord) async throws -> SubmissionID {
        // 절단은 **쓰기 시점에 딱 한 번**. 여기서 하지 않으면 러너·UI·스토어 셋이 각자 자르게 된다.
        let normalized = submission.normalizedForStorage()

        return try await writer.writeMapped { db in
            var row = SubmissionRow(normalized)
            row.id = nil
            try row.insert(db)
            let submissionID = db.lastInsertedRowID

            // ordinal 이 배열 순서를 보존한다. 컴파일러가 낸 순서 자체에 정보가 있다
            // (첫 에러가 보통 원인, 뒤따르는 것들은 그 여파).
            for (ordinal, diagnostic) in normalized.diagnostics.enumerated() {
                try DiagnosticRow(diagnostic, submissionID: submissionID, ordinal: ordinal)
                    .insert(db)
            }

            // 보존 정책도 같은 트랜잭션 안에서. 별도 트랜잭션으로 미루면 정리 전에 앱이 죽었을 때
            // 상한이 영원히 안 지켜진다.
            try Self.pruneFailedSubmissions(db, like: normalized)

            return SubmissionID(submissionID)
        }
    }

    /// 실패 제출만 `(pack_id, lesson_id, block_index)` 당 최근 N 건으로 자른다.
    ///
    /// 통과 제출을 남기는 이유: 개수가 적고("맞으면 다음 블록으로 간다") 정답 히스토리로서 값이 있다.
    /// 실패는 같은 블록에서 수십 번 나올 수 있고 오래된 실패는 사용자에게도 의미가 없다.
    /// `diagnostic` 은 ON DELETE CASCADE 로 따라 지워진다.
    private static func pruneFailedSubmissions(
        _ db: Database,
        like submission: SubmissionRecord
    ) throws {
        guard !submission.passed else { return }
        try db.execute(sql: """
            DELETE FROM submission
            WHERE id IN (
                SELECT id FROM submission
                WHERE pack_id = ? AND lesson_id = ? AND block_index = ? AND passed = 0
                ORDER BY id DESC
                LIMIT -1 OFFSET ?
            )
            """, arguments: [
                submission.packID.rawValue,
                submission.lessonID.rawValue,
                submission.blockIndex,
                PersistenceLimits.failedSubmissionRetention,
            ])
    }

    func submission(id: SubmissionID) async throws -> SubmissionRecord? {
        try await writer.readMapped { db in
            guard let row = try SubmissionRow.fetchOne(
                db,
                sql: "SELECT * FROM submission WHERE id = ?",
                arguments: [id.rawValue]
            ) else { return nil }
            return try row.toRecord(diagnostics: Self.diagnostics(db, submissionID: id.rawValue))
        }
    }

    private static func diagnostics(_ db: Database, submissionID: Int64) throws -> [Diagnostic] {
        try DiagnosticRow
            .fetchAll(db, sql: """
                SELECT * FROM diagnostic WHERE submission_id = ? ORDER BY ordinal
                """, arguments: [submissionID])
            .map { try $0.toDiagnostic() }
    }

    func recent(
        packID: PackID,
        lessonID: LessonID,
        blockIndex: Int,
        limit: Int
    ) async throws -> [SubmissionRecord] {
        try await writer.readMapped { db in
            let rows = try SubmissionRow.fetchAll(db, sql: """
                SELECT * FROM submission
                WHERE pack_id = ? AND lesson_id = ? AND block_index = ?
                ORDER BY id DESC
                LIMIT ?
                """, arguments: [
                    packID.rawValue, lessonID.rawValue, blockIndex, max(0, limit),
                ])
            return try rows.map { row in
                let diagnostics = try row.id.map { try Self.diagnostics(db, submissionID: $0) } ?? []
                return try row.toRecord(diagnostics: diagnostics)
            }
        }
    }

    func attemptCount(packID: PackID, lessonID: LessonID, blockIndex: Int) async throws -> Int {
        try await writer.readMapped { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM submission
                WHERE pack_id = ? AND lesson_id = ? AND block_index = ?
                """, arguments: [packID.rawValue, lessonID.rawValue, blockIndex]) ?? 0
        }
    }
}
