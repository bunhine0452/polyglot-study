/// 인메모리 페이크 — `submission` + `diagnostic`.
public actor InMemorySubmissionStore: SubmissionStore {
    private var records: [SubmissionID: SubmissionRecord] = [:]
    private var nextID: Int64 = 1

    public init() {}

    @discardableResult
    public func record(_ submission: SubmissionRecord) async throws -> SubmissionID {
        guard LessonBlockSequence.contains(submission.blockIndex) else {
            throw StoreError.constraint(message: "chk_submission_block_index")
        }
        guard submission.durationMilliseconds >= 0 else {
            throw StoreError.constraint(message: "chk_submission_duration")
        }

        var stored = submission.normalizedForStorage()
        let id = SubmissionID(nextID)
        nextID += 1
        stored.id = id
        records[id] = stored
        applyRetention(for: stored)
        return id
    }

    /// 실패 제출만 레슨·블록당 최근 N 건으로 자른다. GRDB 구현은 같은 일을 같은 트랜잭션 안에서 한다.
    private func applyRetention(for submission: SubmissionRecord) {
        guard !submission.passed else { return }
        let siblings = records.values
            .filter {
                !$0.passed
                    && $0.packID == submission.packID
                    && $0.lessonID == submission.lessonID
                    && $0.blockIndex == submission.blockIndex
            }
            .sorted { ($0.id?.rawValue ?? 0) > ($1.id?.rawValue ?? 0) }

        for victim in siblings.dropFirst(PersistenceLimits.failedSubmissionRetention) {
            if let id = victim.id { records[id] = nil }
        }
    }

    public func submission(id: SubmissionID) async throws -> SubmissionRecord? { records[id] }

    public func recent(
        packID: PackID,
        lessonID: LessonID,
        blockIndex: Int,
        limit: Int
    ) async throws -> [SubmissionRecord] {
        records.values
            .filter { $0.packID == packID && $0.lessonID == lessonID && $0.blockIndex == blockIndex }
            .sorted { ($0.id?.rawValue ?? 0) > ($1.id?.rawValue ?? 0) }
            .prefix(max(0, limit))
            .map { $0 }
    }

    public func attemptCount(
        packID: PackID,
        lessonID: LessonID,
        blockIndex: Int
    ) async throws -> Int {
        records.values.count {
            $0.packID == packID && $0.lessonID == lessonID && $0.blockIndex == blockIndex
        }
    }
}

/// 인메모리 페이크 — `mistake_note`.
///
/// 검색은 FTS5 가 아니라 단순 부분문자열 매치다. trigram 이 부분어를 잡는다는 성질만 흉내내며
/// bm25 순위는 재현하지 않는다 — 순위까지 검증하려면 GRDB 구현을 써야 한다.
public actor InMemoryMistakeNoteStore: MistakeNoteStore {
    private var notes: [MistakeNoteID: MistakeNote] = [:]
    private var nextID: Int64 = 1
    private var countObservers = ContinuationRegistry<Int>()

    public init() {}

    @discardableResult
    public func save(_ note: MistakeNote) async throws -> MistakeNoteID {
        var stored = note
        let id = note.id ?? MistakeNoteID(nextID)
        if note.id == nil { nextID += 1 }
        stored.id = id
        notes[id] = stored
        countObservers.broadcast(notes.count)
        return id
    }

    public func update(_ note: MistakeNote) async throws {
        guard let id = note.id, notes[id] != nil else {
            throw StoreError.notFound(
                entity: "mistake_note",
                id: note.id.map { String($0.rawValue) } ?? "nil"
            )
        }
        notes[id] = note
        countObservers.broadcast(notes.count)
    }

    public func delete(id: MistakeNoteID) async throws {
        notes[id] = nil
        countObservers.broadcast(notes.count)
    }

    public func note(id: MistakeNoteID) async throws -> MistakeNote? { notes[id] }

    public func count() async throws -> Int { notes.count }

    public func search(_ query: String, limit: Int) async throws -> [MistakeNoteSearchHit] {
        guard query.count >= MistakeNoteSearch.minimumQueryLength else { return [] }
        let needle = query.lowercased()
        return notes.values
            .filter { $0.title.lowercased().contains(needle) || $0.body.lowercased().contains(needle) }
            .sorted { ($0.id?.rawValue ?? 0) < ($1.id?.rawValue ?? 0) }
            .prefix(max(0, limit))
            .map { note in
                MistakeNoteSearchHit(
                    noteID: note.id ?? MistakeNoteID(0),
                    title: note.title,
                    snippet: note.body,
                    rank: 0
                )
            }
    }

    nonisolated public func observeCount() -> AsyncThrowingStream<Int, any Error> {
        AsyncThrowingStream { continuation in
            Task { await self.registerCountObserver(continuation) }
        }
    }

    private func registerCountObserver(
        _ continuation: AsyncThrowingStream<Int, any Error>.Continuation
    ) {
        countObservers.add(continuation, current: notes.count)
    }
}

/// 인메모리 페이크 — `lesson_progress`.
public actor InMemoryLessonProgressStore: LessonProgressStore {
    private struct Key: Hashable { let pack: PackID; let lesson: LessonID }

    private var rows: [Key: LessonProgress] = [:]
    private var observers: [Key: ContinuationRegistry<LessonProgress?>] = [:]

    public init() {}

    public func progress(packID: PackID, lessonID: LessonID) async throws -> LessonProgress? {
        rows[Key(pack: packID, lesson: lessonID)]
    }

    public func upsert(_ progress: LessonProgress) async throws {
        guard LessonBlockSequence.contains(progress.currentBlockIndex) else {
            throw StoreError.constraint(message: "chk_lesson_progress_current_block")
        }
        let key = Key(pack: progress.packID, lesson: progress.lessonID)
        rows[key] = progress
        observers[key]?.broadcast(progress)
    }

    public func progressList(packID: PackID) async throws -> [LessonProgress] {
        rows.values
            .filter { $0.packID == packID }
            .sorted { $0.lessonID.rawValue < $1.lessonID.rawValue }
    }

    @discardableResult
    public func completeBlock(
        packID: PackID,
        lessonID: LessonID,
        languageID: LanguageID,
        blockIndex: Int,
        at timestamp: EpochMilliseconds
    ) async throws -> LessonProgress {
        guard LessonBlockSequence.contains(blockIndex) else {
            throw StoreError.constraint(message: "chk_lesson_progress_block_index")
        }
        let key = Key(pack: packID, lesson: lessonID)
        let existing = rows[key]
            ?? LessonProgress(packID: packID, lessonID: lessonID, languageID: languageID)
        let updated = existing.completing(block: blockIndex, at: timestamp)
        rows[key] = updated
        observers[key]?.broadcast(updated)
        return updated
    }

    nonisolated public func observeProgress(
        packID: PackID,
        lessonID: LessonID
    ) -> AsyncThrowingStream<LessonProgress?, any Error> {
        AsyncThrowingStream { continuation in
            Task { await self.registerObserver(continuation, packID, lessonID) }
        }
    }

    private func registerObserver(
        _ continuation: AsyncThrowingStream<LessonProgress?, any Error>.Continuation,
        _ packID: PackID,
        _ lessonID: LessonID
    ) {
        let key = Key(pack: packID, lesson: lessonID)
        var registry = observers[key] ?? ContinuationRegistry<LessonProgress?>()
        registry.add(continuation, current: rows[key])
        observers[key] = registry
    }
}

/// 페이크 5종을 한 번에 배선한 컨테이너. 스케줄링·UI 테스트의 조립 지점이다.
public struct InMemoryStores: Sendable {
    public let reviewLog: InMemoryReviewLogStore
    public let cardState: InMemoryCardStateStore
    public let submissions: InMemorySubmissionStore
    public let mistakeNotes: InMemoryMistakeNoteStore
    public let lessonProgress: InMemoryLessonProgressStore

    public init() {
        let log = InMemoryReviewLogStore()
        self.reviewLog = log
        self.cardState = InMemoryCardStateStore(reviewLog: log)
        self.submissions = InMemorySubmissionStore()
        self.mistakeNotes = InMemoryMistakeNoteStore()
        self.lessonProgress = InMemoryLessonProgressStore()
    }
}
