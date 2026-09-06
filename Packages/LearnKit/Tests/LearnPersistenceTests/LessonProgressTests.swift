import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

@Suite("lesson_progress — 6블록 시퀀스")
struct LessonProgressTests {
    /// `{#m005-lesson-progress}` 의 완료 기준.
    @Test("블록 6개를 순차 완료하면 in_progress 에서 completed 로 전이한다",
          arguments: DatabaseFlavor.allCases)
    func sixBlocksTransitionToCompleted(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.lessonProgressStore
        let pack = PackID("pack-python-core")
        let lesson = LessonID("py-lesson-01")

        #expect(try await store.progress(packID: pack, lessonID: lesson) == nil)

        for block in 0..<5 {
            let progress = try await store.completeBlock(
                packID: pack,
                lessonID: lesson,
                languageID: .python,
                blockIndex: block,
                at: Fixture.epoch + Int64(block) * 1_000
            )
            #expect(progress.status == .inProgress, "블록 \(block) 에서 이미 completed 가 됐다")
            #expect(progress.completedAt == nil)
            #expect(progress.completedBlocks == Array(0...block))
            #expect(progress.currentBlockIndex == min(5, block + 1))
        }

        let final = try await store.completeBlock(
            packID: pack,
            lessonID: lesson,
            languageID: .python,
            blockIndex: 5,
            at: Fixture.epoch + 5_000
        )
        #expect(final.status == .completed)
        #expect(final.completedAt == Fixture.epoch + 5_000)
        #expect(final.startedAt == Fixture.epoch)
        #expect(final.lastActivityAt == Fixture.epoch + 5_000)
        #expect(final.isFullyCompleted)

        // 저장된 값도 같아야 한다.
        #expect(try await store.progress(packID: pack, lessonID: lesson) == final)
    }

    @Test("순서를 건너뛰어도 6개가 다 차야 completed 다", arguments: DatabaseFlavor.allCases)
    func outOfOrderStillNeedsAllSix(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.lessonProgressStore
        let pack = PackID("p")
        let lesson = LessonID("l")

        for block in [5, 0, 3, 1, 4] {
            let progress = try await store.completeBlock(
                packID: pack, lessonID: lesson, languageID: .swift,
                blockIndex: block, at: Fixture.epoch
            )
            #expect(progress.status == .inProgress)
        }
        let final = try await store.completeBlock(
            packID: pack, lessonID: lesson, languageID: .swift,
            blockIndex: 2, at: Fixture.epoch
        )
        #expect(final.status == .completed)
        #expect(final.completedBlocks == [0, 1, 2, 3, 4, 5])
    }

    @Test("같은 블록을 여러 번 완료해도 중복되지 않는다", arguments: DatabaseFlavor.allCases)
    func repeatedCompletionIsIdempotent(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.lessonProgressStore
        for _ in 0..<4 {
            try await store.completeBlock(
                packID: PackID("p"), lessonID: LessonID("l"), languageID: .python,
                blockIndex: 2, at: Fixture.epoch
            )
        }
        let progress = try #require(await store.progress(packID: PackID("p"), lessonID: LessonID("l")))
        #expect(progress.completedBlocks == [2])
        #expect(progress.status == .inProgress)
    }

    @Test("전이 규칙은 DB 없이도 성립하는 순수 함수다")
    func transitionIsPure() {
        var progress = LessonProgress(
            packID: PackID("p"), lessonID: LessonID("l"), languageID: .sql
        )
        #expect(progress.status == .notStarted)
        #expect(progress.startedAt == nil)

        progress = progress.completing(block: 0, at: 100)
        #expect(progress.status == .inProgress)
        #expect(progress.startedAt == 100)

        for block in 1...5 { progress = progress.completing(block: block, at: 200) }
        #expect(progress.status == .completed)
        #expect(progress.completedAt == 200)
        #expect(progress.startedAt == 100, "startedAt 이 덮어써졌다")

        // 범위 밖 인덱스는 조용히 무시한다 — CHECK 가 어차피 거부한다.
        let unchanged = progress.completing(block: 6, at: 300)
        #expect(unchanged == progress)

        // skipped 는 건드리지 않는다.
        var skipped = LessonProgress(
            packID: PackID("p"), lessonID: LessonID("l2"), languageID: .sql, status: .skipped
        )
        skipped = skipped.completing(block: 0, at: 100)
        #expect(skipped.status == .skipped)
        #expect(skipped.completedBlocks.isEmpty)
    }

    // MARK: - {#lesson-progress-columns}

    @Test("completed_blocks 는 유효한 JSON 배열로 저장된다", arguments: DatabaseFlavor.allCases)
    func completedBlocksAreValidJSON(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await harness.database.lessonProgressStore.completeBlock(
            packID: PackID("p"), lessonID: LessonID("l"), languageID: .python,
            blockIndex: 1, at: Fixture.epoch
        )
        try await harness.database.lessonProgressStore.completeBlock(
            packID: PackID("p"), lessonID: LessonID("l"), languageID: .python,
            blockIndex: 4, at: Fixture.epoch
        )
        #expect(try harness.database.scalarInt(
            "SELECT json_valid(completed_blocks) FROM lesson_progress"
        ) == 1)
        #expect(try harness.database.scalarInt(
            "SELECT json_array_length(completed_blocks) FROM lesson_progress"
        ) == 2)
    }

    @Test("JSON 이 아닌 completed_blocks 는 CHECK 가 거부한다")
    func invalidJSONIsRejected() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO lesson_progress
                    (pack_id, lesson_id, language_id, status, completed_blocks, current_block_index)
                VALUES ('p', 'l', 'python', 'inProgress', 'nope', 0)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }

    @Test("status CHECK 4종 밖의 값과 범위 밖 블록 인덱스는 거부된다")
    func statusAndBlockIndexDomainsAreEnforced() throws {
        let harness = try TestDatabase(.inMemory)
        let badStatus = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO lesson_progress
                    (pack_id, lesson_id, language_id, status, completed_blocks, current_block_index)
                VALUES ('p', 'l', 'python', 'paused', '[]', 0)
                """)
        }
        #expect(badStatus?.extendedResultCode == SQLiteResultCode.constraintCheck)

        let badBlock = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO lesson_progress
                    (pack_id, lesson_id, language_id, status, completed_blocks, current_block_index)
                VALUES ('p', 'l2', 'python', 'inProgress', '[]', 6)
                """)
        }
        #expect(badBlock?.extendedResultCode == SQLiteResultCode.constraintCheck)

        // 스키마 도메인이 LearnCore 열거형과 일치하는지.
        let schema = try harness.database.schemaDump()
        for status in LessonStatus.allCases {
            #expect(schema.contains("'\(status.rawValue)'"))
        }
        #expect(LessonStatus.allCases.count == 4)
        #expect(LessonBlockSequence.count == 6)
    }

    @Test("completed 인데 completed_at 이 없으면 거부된다")
    func completedRequiresTimestamp() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO lesson_progress
                    (pack_id, lesson_id, language_id, status, completed_blocks, current_block_index)
                VALUES ('p', 'l', 'python', 'completed', '[0,1,2,3,4,5]', 5)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }

    @Test("PK 는 (pack_id, lesson_id) — 같은 LessonID 가 다른 팩에 공존한다",
          arguments: DatabaseFlavor.allCases)
    func primaryKeyIsPackAndLesson(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.lessonProgressStore
        try await store.completeBlock(
            packID: PackID("pack-a"), lessonID: LessonID("shared"), languageID: .python,
            blockIndex: 0, at: Fixture.epoch
        )
        try await store.completeBlock(
            packID: PackID("pack-b"), lessonID: LessonID("shared"), languageID: .python,
            blockIndex: 3, at: Fixture.epoch
        )
        #expect(try await store.progress(packID: PackID("pack-a"), lessonID: LessonID("shared"))?
            .completedBlocks == [0])
        #expect(try await store.progress(packID: PackID("pack-b"), lessonID: LessonID("shared"))?
            .completedBlocks == [3])
        #expect(try await store.progressList(packID: PackID("pack-a")).count == 1)
    }

    @Test("모든 컬럼이 라운드트립한다", arguments: DatabaseFlavor.allCases)
    func roundTripsAllColumns(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let original = LessonProgress(
            packID: PackID("pack-sql"),
            lessonID: LessonID("sql-lesson-09"),
            languageID: .sql,
            status: .skipped,
            completedBlocks: [0, 2],
            currentBlockIndex: 3,
            startedAt: Fixture.epoch,
            lastActivityAt: Fixture.epoch + 500,
            completedAt: nil
        )
        try await harness.database.lessonProgressStore.upsert(original)
        #expect(try await harness.database.lessonProgressStore
            .progress(packID: original.packID, lessonID: original.lessonID) == original)
    }
}
