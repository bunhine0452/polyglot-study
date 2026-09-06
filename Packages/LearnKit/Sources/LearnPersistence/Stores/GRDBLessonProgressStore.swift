internal import GRDB
internal import LearnCore

/// `lesson_progress`.
///
/// 전이 규칙은 SQL 이 아니라 `LessonProgress.completing(block:at:)` 순수 함수가 갖는다.
/// 인메모리 페이크와 GRDB 구현이 **같은 함수**를 쓰므로 두 구현이 갈라질 수 없고,
/// 전이 자체는 DB 없이 단위 테스트된다. 여기 남는 일은 읽기-수정-쓰기를 한 트랜잭션에 묶는 것뿐이다.
struct GRDBLessonProgressStore: LessonProgressStore {
    let writer: any DatabaseWriter

    func progress(packID: PackID, lessonID: LessonID) async throws -> LessonProgress? {
        try await writer.readMapped { db in
            try Self.fetch(db, packID: packID.rawValue, lessonID: lessonID.rawValue)
        }
    }

    private static func fetch(
        _ db: Database,
        packID: String,
        lessonID: String
    ) throws -> LessonProgress? {
        try LessonProgressRow.fetchOne(
            db,
            sql: "SELECT * FROM lesson_progress WHERE pack_id = ? AND lesson_id = ?",
            arguments: [packID, lessonID]
        )?.toProgress()
    }

    func upsert(_ progress: LessonProgress) async throws {
        try await writer.writeMapped { db in
            try LessonProgressRow(progress).save(db)
        }
    }

    func progressList(packID: PackID) async throws -> [LessonProgress] {
        try await writer.readMapped { db in
            try LessonProgressRow
                .fetchAll(db, sql: """
                    SELECT * FROM lesson_progress WHERE pack_id = ? ORDER BY lesson_id
                    """, arguments: [packID.rawValue])
                .map { try $0.toProgress() }
        }
    }

    @discardableResult
    func completeBlock(
        packID: PackID,
        lessonID: LessonID,
        languageID: LanguageID,
        blockIndex: Int,
        at timestamp: EpochMilliseconds
    ) async throws -> LessonProgress {
        guard LessonBlockSequence.contains(blockIndex) else {
            throw StoreError.constraint(
                message: "block_index \(blockIndex) 가 0..<\(LessonBlockSequence.count) 밖이다"
            )
        }
        return try await writer.writeMapped { db in
            // 읽기와 쓰기가 한 트랜잭션 안에 있어야 두 블록을 동시에 끝냈을 때 하나가 사라지지 않는다.
            let existing = try Self.fetch(db, packID: packID.rawValue, lessonID: lessonID.rawValue)
                ?? LessonProgress(packID: packID, lessonID: lessonID, languageID: languageID)
            let updated = existing.completing(block: blockIndex, at: timestamp)
            try LessonProgressRow(updated).save(db)
            return updated
        }
    }

    func observeProgress(
        packID: PackID,
        lessonID: LessonID
    ) -> AsyncThrowingStream<LessonProgress?, any Error> {
        let pack = packID.rawValue
        let lesson = lessonID.rawValue
        return makeObservationStream(reader: writer) { db in
            try Self.fetch(db, packID: pack, lessonID: lesson)
        }
    }
}
