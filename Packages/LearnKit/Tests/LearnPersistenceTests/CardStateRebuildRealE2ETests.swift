import Foundation
import Testing
import LearnCore
@testable import LearnPersistence
import LearnScheduling

/// 진짜 드라이버 + 진짜 FSRS + 진짜 SQLite 를 한 번 함께 태운다. `{#card-state-rebuild}`
///
/// 나머지 커버리지는 셋으로 갈려 있다 — 드라이버 계약은 `LearnSchedulingTests` 가 인메모리
/// 페이크로, FSRS 수치는 골든 회귀가, 컬럼 왕복은 `CardStateRebuildE2ETests` 가 손으로 검산
/// 가능한 스텁 스케줄러로 본다. 각 조각은 통과하는데 이었을 때만 깨지는 결함을 이미 두 번
/// 겪었으므로(리플레이 워터마크가 `.cram` 에서 수렴하지 않던 것, 그리고 아래) 조합 자체를
/// 보는 테스트를 하나 둔다.
///
/// ## 이 스위트가 실제로 잡아낸 것
///
/// 마이그레이션 007 이 고친 결함이 여기서 처음 드러났다. 씨앗 행을 만드는
/// `scheduler.initialState(...)` 는 난이도 0(= "첫 복습 전이라 아직 없음")을 들고 나오는데,
/// 002 의 `chk_card_state_difficulty` 는 1.0...10.0 만 받았다. 그래서 **한 번도 복습하지
/// 않은 카드는 캐시에 저장하는 것 자체가 불가능**했다. 갈라진 세 테스트 경로가 전부 이
/// 자리를 비껴간 이유가 곧 이 스위트가 있어야 하는 이유다 — 페이크에는 CHECK 이 없고,
/// 손으로 만든 픽스처는 유효한 난이도를 넣고, 재구축 드라이버는 복습이 1회 이상인 카드만
/// 쓴다. 셋 다 초록인 채로 신규 카드는 저장되지 않았다.
@Suite("재구축 — 실 드라이버·실 FSRS·실 SQLite")
struct CardStateRebuildRealE2ETests {

    /// 2026-01-01T00:00:00Z.
    private static let epoch = EpochMillis(1_767_225_600_000)
    private static func day(_ count: Int) -> EpochMillis { epoch.adding(days: count) }

    /// DB 의 활성 파라미터 세트를 **스케줄러가 실제로 쓰는 세트**로 바꾼다.
    ///
    /// 마이그레이션 001 이 시드하는 `fsrs6-default` 는 자리를 채우는 값이고, 실제 FSRS
    /// 스케줄러의 id 는 파라미터 내용에서 유도한 해시다. 둘이 다르면 (1) `review_log` 의
    /// 외래키가 곧바로 깨지고 (2) 통과하더라도 재구축이 만든 행이 만들어지자마자
    /// `parameter_drift` 로 stale 이 된다. 실 조합 테스트는 그 배선까지 포함이다.
    private func activate(
        _ scheduler: FSRSReviewScheduler,
        in database: LearnDatabase
    ) async throws {
        try await database.reviewLogStore.save(
            parameterSet: SchedulerParameterSet(
                id: scheduler.parameterSetID,
                schedulerID: scheduler.schedulerID,
                // nil = "스케줄러 내장 기본 가중치". 상수의 주인은 LearnScheduling 이다.
                weights: nil,
                desiredRetention: scheduler.parameters.requestRetention,
                createdAt: Self.epoch,
                isActive: true
            ),
            activate: true
        )
    }

    private func entry(
        card: String,
        day: Int,
        rating: ReviewRating,
        stateBefore: CardPhase = .review,
        source: ReviewLogSource = .review,
        scheduler: FSRSReviewScheduler
    ) -> ReviewLogEntry {
        ReviewLogEntry(
            cardID: CardID(card),
            reviewedAt: Self.day(day),
            rating: rating,
            stateBefore: stateBefore,
            elapsedDays: 0,
            scheduledDays: 0,
            reviewDurationMS: 1_200,
            schedulerID: scheduler.schedulerID,
            parameterSetID: scheduler.parameterSetID,
            source: source
        )
    }

    /// 아직 복습하지 않은 카드의 씨앗 행. **007 이전에는 이 한 줄이 CHECK 로 실패했다.**
    private func seed(
        _ cardID: String,
        language: LanguageID,
        scheduler: FSRSReviewScheduler,
        in cards: any CardStateStore
    ) async throws {
        let scheduling = scheduler.initialState(for: CardID(cardID), createdAt: Self.epoch)
        #expect(scheduling.difficulty == 0, "FSRS 신규 카드의 난이도 센티널이 0 이 아니다")
        try await cards.upsert(
            CardStateSnapshot(scheduling: scheduling, languageID: language, rebuiltAt: Self.epoch)
        )
    }

    @Test(
        "실 FSRS 로 재구축한 card_state 가 같은 로그의 직접 replay 와 일치한다",
        arguments: DatabaseFlavor.allCases
    )
    func realRebuildMatchesDirectReplay(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let database = harness.database
        let log = database.reviewLogStore
        let cards = database.cardStateStore

        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(Self.day(10)))
        try await activate(scheduler, in: database)

        // 마지막이 .cram 인 카드를 일부러 섞는다 — 워터마크가 수렴하지 않던 그 경로다.
        let entries = [
            entry(card: "swift-optional-1", day: 0, rating: .good, stateBefore: .new, scheduler: scheduler),
            entry(card: "swift-optional-1", day: 3, rating: .again, scheduler: scheduler),
            entry(card: "swift-optional-1", day: 4, rating: .good, scheduler: scheduler),
            entry(card: "swift-optional-1", day: 9, rating: .easy, source: .cram, scheduler: scheduler),
            entry(card: "sql-join-2", day: 0, rating: .hard, stateBefore: .new, scheduler: scheduler),
            entry(card: "sql-join-2", day: 2, rating: .good, scheduler: scheduler),
        ]
        for entry in entries { _ = try await log.append(entry) }

        // stale 판정은 card_state 행이 있어야 성립한다 (카드의 트랙은 로그가 아니라 캐시가 안다).
        // 갓 만든 씨앗 행은 derivedFromLogID 가 없어 곧바로 log_drift 로 잡힌다.
        try await seed("swift-optional-1", language: .swift, scheduler: scheduler, in: cards)
        try await seed("sql-join-2", language: .sql, scheduler: scheduler, in: cards)

        // 씨앗이 **실제 SQLite 에서 되읽힌다**. 007 이전에는 여기 도달하지 못했다.
        #expect(try await cards.snapshot(forCard: CardID("swift-optional-1"))?.difficulty == 0)
        #expect(try await cards.snapshot(forCard: CardID("swift-optional-1"))?.phase == .new)

        let rebuilder = CardStateRebuilder(scheduler: scheduler, cardStates: cards, reviewLog: log)
        #expect(try await rebuilder.staleCount() == 2)

        let report = try await rebuilder.rebuildStaleCards(in: [.swift, .sql], at: Self.day(10))
        #expect(report.rebuiltCardCount == 2, "두 카드가 재구축돼야 한다 — \(report)")
        #expect(report.skippedEntryCount == 1, ".cram 한 건은 스케줄에 반영되지 않는다 — \(report)")
        #expect(report.reviewLogCount == entries.count, "재구축이 진실의 원천을 건드렸다 — \(report)")

        // 같은 로그를 드라이버 밖에서 직접 replay 한 결과와 대조한다.
        for cardID in [CardID("swift-optional-1"), CardID("sql-join-2")] {
            let cardLog = entries.filter { $0.cardID == cardID }.replayOrdered()
            let expected = try scheduler.replay(cardLog)
            let stored = try await cards.snapshot(forCard: cardID)
            let actual = try #require(stored, "\(cardID.rawValue) 행이 없다")

            #expect(actual.scheduling.stability == expected.stability)
            #expect(actual.scheduling.difficulty == expected.difficulty)
            #expect(actual.scheduling.dueAt == expected.dueAt)
            #expect(actual.scheduling.phase == expected.phase)
            #expect(actual.scheduling.reps == expected.reps)
            #expect(actual.scheduling.lapses == expected.lapses)
            // 006 이 추가한 두 컬럼 — 이 둘이 드라이버·DB 경계에서 유실되던 자리다.
            #expect(actual.scheduling.elapsedDays == expected.elapsedDays)
            #expect(actual.scheduling.learningStepIndex == expected.learningStepIndex)
            // 007 이 넓힌 컬럼 — 복습을 거친 카드의 난이도는 여전히 1...10 안이다.
            #expect(actual.difficulty >= 1.0 && actual.difficulty <= 10.0, "\(actual.difficulty)")
        }
    }

    @Test("재구축은 수렴한다 — 두 번째 호출은 할 일이 없다", arguments: DatabaseFlavor.allCases)
    func rebuildConverges(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let database = harness.database
        let log = database.reviewLogStore
        let cards = database.cardStateStore

        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(Self.day(6)))
        try await activate(scheduler, in: database)

        for entry in [
            entry(card: "go-chan-1", day: 0, rating: .good, stateBefore: .new, scheduler: scheduler),
            // .cram 으로 끝나는 카드. 워터마크를 적용된 마지막 행으로 두면 log_drift 가
            // 영영 걷히지 않아 여기서 무한히 stale 이 된다.
            entry(card: "go-chan-1", day: 5, rating: .easy, source: .cram, scheduler: scheduler),
        ] { _ = try await log.append(entry) }

        let go = LanguageID("go")
        try await seed("go-chan-1", language: go, scheduler: scheduler, in: cards)

        let rebuilder = CardStateRebuilder(scheduler: scheduler, cardStates: cards, reviewLog: log)
        let first = try await rebuilder.rebuildStaleCards(in: [go], at: Self.day(6))
        #expect(first.rebuiltCardCount == 1)

        #expect(try await rebuilder.staleCount() == 0, "재구축 직후에도 stale 이 남으면 수렴하지 않는 것이다")

        let second = try await rebuilder.rebuildStaleCards(in: [go], at: Self.day(6))
        #expect(second.rebuiltCardCount == 0, "두 번째 호출은 할 일이 없어야 한다 — \(second)")
    }

    /// 이력이 하나도 없는 카드도 캐시에 남아 있어야 한다.
    ///
    /// 씨앗 행을 저장할 수 없던 시절에는 "신규 카드는 큐에 뜰 때까지 캐시에 없다" 가 사실상의
    /// 동작이었고, 그러면 due 큐의 `introducing` CTE(= `DueQueueBucket.new`)가 영원히 비어
    /// 신규 카드가 학습에 진입할
    /// 길이 없다. 재구축이 그 행을 지우지 않는다는 것까지 못박는다.
    @Test("이력 없는 신규 카드는 재구축을 거쳐도 캐시에 남는다", arguments: DatabaseFlavor.allCases)
    func newCardSurvivesRebuild(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let database = harness.database
        let log = database.reviewLogStore
        let cards = database.cardStateStore

        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(Self.day(1)))
        try await activate(scheduler, in: database)

        // 복습이 있는 카드 하나 + 한 번도 안 본 카드 하나.
        _ = try await log.append(
            entry(card: "py-seen", day: 0, rating: .good, stateBefore: .new, scheduler: scheduler)
        )
        try await seed("py-seen", language: .python, scheduler: scheduler, in: cards)
        try await seed("py-untouched", language: .python, scheduler: scheduler, in: cards)

        let rebuilder = CardStateRebuilder(scheduler: scheduler, cardStates: cards, reviewLog: log)
        let report = try await rebuilder.rebuildStaleCards(in: [.python], at: Self.day(1))

        // 이력 없는 카드는 log_drift 도 parameter_drift 도 없어 stale 이 아니다 — 그대로 보존된다.
        #expect(report.staleCardCount == 1, "\(report)")
        #expect(report.preservedCardCount == 1, "\(report)")
        #expect(try await cards.count() == 2)

        let untouched = try #require(try await cards.snapshot(forCard: CardID("py-untouched")))
        #expect(untouched.difficulty == 0)
        #expect(untouched.phase == .new)
        #expect(untouched.reps == 0)
    }
}
