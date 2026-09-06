/// 영속화 계층이 도메인으로 올려보내는 실패.
///
/// GRDB 의 `DatabaseError` 는 여기서 끝난다 — 코어와 UI 는 SQLite 결과코드를 몰라도 된다.
/// 다만 `underlying` 에 원문을 실어 디버깅 경로는 남긴다.
public enum StoreError: Error, Sendable {
    /// `review_log` 를 UPDATE·DELETE 하려 했다. 트리거가 ABORT 시킨 것을 옮긴 것.
    case appendOnlyViolation(table: String, operation: String)
    /// 참조하는 행이 없다 (외래키 위반 포함).
    case notFound(entity: String, id: String)
    /// 스키마 제약 위반 — CHECK·UNIQUE·NOT NULL.
    case constraint(message: String)
    /// 그 밖의 저장소 실패.
    case storage(message: String)
}

// MARK: - 애그리게이트 5종
//
// 테이블 단위가 아니라 **애그리게이트 단위**로 자른다. `scheduler_parameters` 가 별도 스토어가 아니라
// `ReviewLogStore` 안에 있는 이유가 이것 — 로그 한 행의 의미는 그 행이 참조하는 파라미터 세트가
// 같은 트랜잭션 경계 안에 있어야 성립한다. `diagnostic` 이 `SubmissionStore` 안에 있는 것도 같은 이유다.

/// append-only 진실의 원천 + 그 로그를 해석하는 데 필요한 파라미터 세트.
public protocol ReviewLogStore: Sendable {
    /// 로그 한 건을 덧붙이고 DB 가 발급한 id 를 돌려준다.
    @discardableResult
    func append(_ entry: ReviewLogEntry) async throws -> ReviewLogID

    /// 여러 건을 한 트랜잭션으로. 외부 이력 가져오기(`source == .imported`)용.
    @discardableResult
    func append(contentsOf entries: [ReviewLogEntry]) async throws -> [ReviewLogID]

    /// 카드 하나의 이력을 `(reviewed_at, id)` 오름차순으로. 리플레이 입력.
    func entries(forCard cardID: CardID) async throws -> [ReviewLogEntry]

    /// 전체 이력을 id 오름차순으로 스트리밍한다. `after` 이후부터 최대 `limit` 건.
    /// 22만 행을 한 번에 메모리에 올리지 않기 위한 페이지 경계다.
    func entries(after id: ReviewLogID?, limit: Int) async throws -> [ReviewLogEntry]

    /// 카드의 마지막 로그 id — `card_state` stale 판정의 워터마크.
    func lastEntryID(forCard cardID: CardID) async throws -> ReviewLogID?

    /// 전체 행 수. 재구축 관용구가 "로그는 하나도 안 건드렸다" 를 단언하는 데 쓴다.
    func count() async throws -> Int

    /// 기간 통계. `(reviewed_at)` 인덱스를 타야 한다.
    func count(from: EpochMilliseconds, to: EpochMilliseconds) async throws -> Int

    func activeParameterSet() async throws -> SchedulerParameterSet
    func parameterSet(id: ParameterSetID) async throws -> SchedulerParameterSet?

    /// 세트를 넣거나 갱신한다. `activate` 가 true 면 **원자적으로** 기존 활성 세트를 내리고 이걸 올린다.
    func save(parameterSet: SchedulerParameterSet, activate: Bool) async throws

    /// 총 리뷰 수의 변화를 관찰한다.
    func observeCount() -> AsyncThrowingStream<Int, any Error>
}

/// 파생 캐시. 통째로 버리고 다시 만들 수 있어야 한다.
public protocol CardStateStore: Sendable {
    func snapshot(forCard cardID: CardID) async throws -> CardStateSnapshot?
    func upsert(_ snapshot: CardStateSnapshot) async throws
    func count() async throws -> Int

    /// **재구축 관용구.** DELETE 전량 → 삽입 전량을 한 트랜잭션으로 한다.
    /// 도중 실패하면 기존 캐시가 그대로 남는다 (부분 재구축 상태가 관측되지 않는다).
    func replaceAll(with snapshots: [CardStateSnapshot]) async throws

    /// 캐시를 통째로 버린다. `review_log` 는 건드리지 않는다.
    func deleteAll() async throws

    /// 트랙별 due 큐. 항상 `language_id` 로 먼저 좁히고 `(language_id, due_at)` 인덱스를 탄다.
    func dueCards(
        languageID: LanguageID,
        dueAtOrBefore: EpochMilliseconds,
        limit: Int
    ) async throws -> [CardStateSnapshot]

    /// stale 판정 헬퍼 — 재구축 자체는 `LearnScheduling` 이 한다. 여기는 "무엇이 뒤처졌나" 까지.
    func staleCards(limit: Int) async throws -> [CardStaleness]
    func staleCount() async throws -> Int

    func observeDueCount(
        languageID: LanguageID,
        dueAtOrBefore: EpochMilliseconds
    ) -> AsyncThrowingStream<Int, any Error>
}

/// 제출 이력 + 정규화된 진단.
public protocol SubmissionStore: Sendable {
    /// `submission` 1행 + `diagnostic` N행을 **한 트랜잭션으로** 쓰고, 보존 정책을 같은 트랜잭션에서 적용한다.
    /// `stdout`/`stderr` 는 여기서 잘린다.
    @discardableResult
    func record(_ submission: SubmissionRecord) async throws -> SubmissionID

    func submission(id: SubmissionID) async throws -> SubmissionRecord?

    func recent(
        packID: PackID,
        lessonID: LessonID,
        blockIndex: Int,
        limit: Int
    ) async throws -> [SubmissionRecord]

    /// 시도 횟수. `lesson_progress` 에 컬럼을 두는 대신 여기서 센다.
    func attemptCount(packID: PackID, lessonID: LessonID, blockIndex: Int) async throws -> Int
}

/// 오답 노트 본문 + FTS5 검색.
public protocol MistakeNoteStore: Sendable {
    @discardableResult
    func save(_ note: MistakeNote) async throws -> MistakeNoteID
    func update(_ note: MistakeNote) async throws
    func delete(id: MistakeNoteID) async throws
    func note(id: MistakeNoteID) async throws -> MistakeNote?
    func count() async throws -> Int

    /// bm25 오름차순(= 관련도 내림차순) 정렬 + snippet 하이라이트.
    /// `MistakeNoteSearch.minimumQueryLength` 미만 질의는 빈 배열이다.
    func search(_ query: String, limit: Int) async throws -> [MistakeNoteSearchHit]

    func observeCount() -> AsyncThrowingStream<Int, any Error>
}

/// 6블록 시퀀스 진도.
public protocol LessonProgressStore: Sendable {
    func progress(packID: PackID, lessonID: LessonID) async throws -> LessonProgress?
    func upsert(_ progress: LessonProgress) async throws
    func progressList(packID: PackID) async throws -> [LessonProgress]

    /// 블록 하나 완료. `LessonProgress.completing(block:at:)` 의 전이 규칙을 그대로 적용하고
    /// 갱신된 값을 돌려준다. 행이 없으면 만든다.
    @discardableResult
    func completeBlock(
        packID: PackID,
        lessonID: LessonID,
        languageID: LanguageID,
        blockIndex: Int,
        at timestamp: EpochMilliseconds
    ) async throws -> LessonProgress

    func observeProgress(
        packID: PackID,
        lessonID: LessonID
    ) -> AsyncThrowingStream<LessonProgress?, any Error>
}
