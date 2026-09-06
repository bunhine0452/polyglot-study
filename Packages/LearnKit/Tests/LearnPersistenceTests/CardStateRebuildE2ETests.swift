import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// 006 이 stale 로 표시한 행이 재구축으로 **실제 컬럼까지** 되살아나는가.
/// `{#card-state-rebuild}` `{#rebuild-transactional}`
///
/// `CardStateTests.migration006MarksLegacyRowsStale` 은 006 이 표시를 남기는 데까지 본다.
/// 여기서는 그 표시를 읽어 재구축을 돌린 뒤 `learning_step_index`·`elapsed_days` 가
/// 리플레이 값과 같아지는지, 그리고 스왑이 도중에 깨지면 기존 캐시가 그대로 남는지를
/// **실제 SQLite 위에서** 확인한다.
///
/// - Note: 드라이버 타입(`LearnScheduling.CardStateRebuilder`) 자체는 여기서 쓸 수 없다 —
///   이 테스트 타깃은 `LearnPersistence` 만 링크하고 `Package.swift` 는 이 작업의 수정
///   대상이 아니다. 그래서 여기서는 드라이버가 저장 계층에 요구하는 **세 단계**
///   (stale 뷰 → 카드별 리플레이 → 한 트랜잭션 스왑)를 같은 순서로 따라간다.
///   드라이버 자체의 계약과 FSRS 리플레이 일치는 `LearnSchedulingTests` 가 본다.
@Suite("006 stale 행 재구축 — 엔드투엔드")
struct CardStateRebuildE2ETests {

    /// 2026-01-01T00:00:00Z.
    private static let epoch = EpochMillis(1_767_225_600_000)

    private static func day(_ count: Int) -> EpochMillis { epoch.adding(days: count) }

    /// 006 **이전** 모양의 `card_state` 행. 두 컬럼이 아예 없는 스키마다.
    private func insertLegacyRow(
        _ database: LearnDatabase,
        card: String,
        language: String,
        logID: Int64
    ) throws {
        try database.executeRaw("""
            INSERT INTO card_state
                (card_id, language_id, stability, difficulty, due_at, last_reviewed_at, state,
                 reps, lapses, scheduled_days, derived_from_log_id, parameter_set_id, rebuilt_at)
            VALUES ('\(card)', '\(language)', 1.0, 5.0, \(Self.day(1).value), \(Self.epoch.value),
                    'review', 1, 0, 1, \(logID), 'fsrs6-default', \(Self.epoch.value))
            """)
    }

    private func entry(
        card: String,
        day: Int,
        rating: ReviewRating,
        stateBefore: CardPhase = .review,
        source: ReviewLogSource = .review
    ) -> ReviewLogEntry {
        ReviewLogEntry(
            cardID: CardID(card),
            reviewedAt: Self.day(day),
            rating: rating,
            stateBefore: stateBefore,
            elapsedDays: 0,
            scheduledDays: 0,
            reviewDurationMS: 1_200,
            source: source
        )
    }

    // MARK: - 엔드투엔드

    @Test("005 DB → 006 → stale 표시 → 재구축 → 두 컬럼이 리플레이 값과 일치한다")
    func staleRowsFromMigration006AreRecovered() async throws {
        let database = try LearnDatabase.inMemory(upTo: "005-lesson-progress")
        #expect(try database.appliedMigrations() == Array(SchemaMigrations.identifiers.dropLast()))

        // ── 005 시절의 데이터 ────────────────────────────────────────────────
        let log = database.reviewLogStore
        var lastLogID: [String: ReviewLogID] = [:]
        // 마지막 리뷰가 again 인 카드는 학습 스텝이 남는다 — 006 이 메운 구멍의 본체다.
        for spec in [
            (card: "py-a", days: [(0, ReviewRating.good), (3, .good), (9, .again)]),
            (card: "py-b", days: [(0, ReviewRating.again), (1, .again)]),
            (card: "sql-a", days: [(0, ReviewRating.good)]),
        ] {
            for (day, rating) in spec.days {
                lastLogID[spec.card] = try await log.append(
                    entry(card: spec.card, day: day, rating: rating)
                )
            }
        }
        // 몰아보기로 끝나는 카드 — 워터마크가 "적용한 로그" 가 아니라 "반영한 로그" 여야
        // 재구축이 수렴한다.
        lastLogID["py-a"] = try await log.append(
            entry(card: "py-a", day: 10, rating: .good, source: .cram)
        )

        try insertLegacyRow(database, card: "py-a", language: "python", logID: lastLogID["py-a"]!.rawValue)
        try insertLegacyRow(database, card: "py-b", language: "python", logID: lastLogID["py-b"]!.rawValue)
        try insertLegacyRow(database, card: "sql-a", language: "sql", logID: lastLogID["sql-a"]!.rawValue)

        // ── 006 ──────────────────────────────────────────────────────────────
        try database.applyRemainingMigrations()
        #expect(try database.appliedMigrations() == SchemaMigrations.identifiers)

        let cards = database.cardStateStore
        #expect(try await cards.staleCount() == 3, "006 이 기존 행을 stale 로 표시하지 않았다")
        #expect(try database.scalarInt("SELECT SUM(elapsed_days) FROM card_state") == 0)
        #expect(try database.scalarInt("SELECT SUM(learning_step_index) FROM card_state") == 0)
        #expect(try database.scalarInt("SELECT COUNT(*) FROM card_state") == 3, "캐시를 비우면 안 된다")

        // ── 재구축 ───────────────────────────────────────────────────────────
        let scheduler = CountingReplayScheduler(clock: FixedSchedulerClock(Self.day(20)))
        let logCountBefore = try await log.count()
        let rebuilt = try await rebuildStaleCards(
            database: database,
            scheduler: scheduler,
            tracks: [.python, .sql],
            at: Self.day(20)
        )
        #expect(rebuilt == 3)

        // ── 두 컬럼이 리플레이 값과 같은가 ────────────────────────────────────
        var sawNonZeroStep = false
        for card in ["py-a", "py-b", "sql-a"] {
            let expected = try scheduler.replay(try await log.entries(forCard: CardID(card)))
            let step = try database.scalarInt(
                "SELECT learning_step_index FROM card_state WHERE card_id = '\(card)'"
            )
            let elapsed = try database.scalarInt(
                "SELECT elapsed_days FROM card_state WHERE card_id = '\(card)'"
            )
            #expect(step == expected.learningStepIndex, "\(card): learning_step_index")
            #expect(elapsed == expected.elapsedDays, "\(card): elapsed_days")
            if expected.learningStepIndex > 0 { sawNonZeroStep = true }

            // 컬럼만이 아니라 스토어를 거쳐 돌아온 값도 같아야 한다.
            let snapshot = try #require(try await cards.snapshot(forCard: CardID(card)))
            #expect(snapshot.learningStepIndex == expected.learningStepIndex)
            #expect(snapshot.elapsedDays == expected.elapsedDays)
            #expect(snapshot.rebuiltAt == Self.day(20))
        }
        #expect(sawNonZeroStep, "전제 붕괴: 학습 스텝이 0 이 아닌 카드가 하나도 없다")

        // ── 수렴하고, 진실의 원천은 그대로 ────────────────────────────────────
        #expect(try await cards.staleCount() == 0, "재구축 후에도 stale 이 남았다")
        #expect(try await log.count() == logCountBefore, "재구축이 review_log 를 건드렸다")
        #expect(try database.scalarInt("SELECT COUNT(*) FROM card_state") == 3)
    }

    // MARK: - 트랜잭션 `{#rebuild-transactional}`

    @Test("스왑이 도중에 실패하면 기존 캐시가 한 행도 바뀌지 않는다", arguments: DatabaseFlavor.allCases)
    func failedSwapLeavesTheOldCacheIntact(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let cards = harness.database.cardStateStore
        let logID = try await harness.database.reviewLogStore.append(Fixture.reviewEntry())

        let original = [
            Fixture.cardState(card: "py-001", elapsedDays: 3, learningStepIndex: 1, derivedFrom: logID),
            Fixture.cardState(card: "py-002", dueOffsetDays: 2, elapsedDays: 5, learningStepIndex: 2),
            Fixture.cardState(card: "sql-001", language: .sql, elapsedDays: 7, learningStepIndex: 3),
        ]
        try await cards.replaceAll(with: original)
        let before = try await allRows(cards)
        #expect(before.count == 3)

        // 세 번째 행이 존재하지 않는 로그를 워터마크로 가리킨다 — 삽입 도중 FK 위반이다.
        var poisoned = original.map { snapshot -> CardStateSnapshot in
            var copy = snapshot
            copy.elapsedDays = 999
            copy.learningStepIndex = 9
            return copy
        }
        poisoned[2].derivedFromLogID = ReviewLogID(9_999)

        await #expect(throws: (any Error).self) {
            try await cards.replaceAll(with: poisoned)
        }

        // DELETE 까지 커밋됐다면 여기가 0 이 된다 — 그게 정확히 막아야 하는 상태다.
        #expect(try await cards.count() == 3, "실패한 스왑이 기존 행 수를 바꿨다")
        #expect(try await allRows(cards) == before, "실패한 스왑이 기존 행의 값을 바꿨다")
        #expect(try harness.database.scalarInt("SELECT SUM(elapsed_days) FROM card_state") == 15)
    }

    @Test("성공한 스왑은 통째 교체다 — 사라진 카드는 남지 않는다", arguments: DatabaseFlavor.allCases)
    func successfulSwapReplacesEverything(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let cards = harness.database.cardStateStore
        try await cards.replaceAll(with: [
            Fixture.cardState(card: "py-001", elapsedDays: 1, learningStepIndex: 1),
            Fixture.cardState(card: "py-002", elapsedDays: 2, learningStepIndex: 2),
        ])
        try await cards.replaceAll(with: [
            Fixture.cardState(card: "py-002", elapsedDays: 20, learningStepIndex: 4)
        ])

        #expect(try await cards.count() == 1)
        #expect(try await cards.snapshot(forCard: CardID("py-001")) == nil)
        let survivor = try #require(try await cards.snapshot(forCard: CardID("py-002")))
        #expect(survivor.elapsedDays == 20)
        #expect(survivor.learningStepIndex == 4)
    }

    // MARK: - 재구축 세 단계

    /// `LearnScheduling.CardStateRebuilder.rebuildStaleCards(in:at:)` 와 같은 순서로 움직인다.
    /// 스위트 주석 참고 — 여기서 그 타입을 직접 쓸 수 없어 저장 계층 쪽 절반만 재현한다.
    private func rebuildStaleCards(
        database: LearnDatabase,
        scheduler: some ReviewScheduler,
        tracks: [LanguageID],
        at now: EpochMillis
    ) async throws -> Int {
        let cards = database.cardStateStore
        let log = database.reviewLogStore

        // 1. 무엇이 뒤처졌나 — `card_state_stale` 뷰가 유일한 근거다.
        let stale = Set(try await cards.staleCards(limit: .max).map(\.cardID))
        guard !stale.isEmpty else { return 0 }

        // 2. 카드별 스트리밍 리플레이. 유지할 행도 손에 들어야 통째 스왑이 가능하다.
        var rows: [CardStateSnapshot] = []
        var rebuilt = 0
        for existing in try await allRows(cards) {
            guard stale.contains(existing.cardID) else {
                rows.append(existing)
                continue
            }
            let entries = try await log.entries(forCard: existing.cardID)
            guard !entries.isEmpty else {
                var row = existing
                row.parameterSetID = scheduler.parameterSetID
                row.derivedFromLogID = nil
                row.rebuiltAt = now
                rows.append(row)
                rebuilt += 1
                continue
            }
            var state = try scheduler.replay(entries)
            // 워터마크는 건너뛴 `.cram` 까지 포함한 진짜 마지막 행이다.
            state.derivedFromLogID = try await log.lastEntryID(forCard: existing.cardID)
            rows.append(
                CardStateSnapshot(scheduling: state, languageID: existing.languageID, rebuiltAt: now)
            )
            rebuilt += 1
        }

        // 3. 한 트랜잭션 스왑.
        try await cards.replaceAll(with: rows)
        return rebuilt
    }

    private func allRows(_ store: any CardStateStore) async throws -> [CardStateSnapshot] {
        var rows: [CardStateSnapshot] = []
        for language in [LanguageID.python, .sql, .swift] {
            rows += try await store.dueCards(languageID: language, dueAtOrBefore: .max, limit: .max)
        }
        return rows.sorted { $0.cardID.rawValue < $1.cardID.rawValue }
    }
}

// MARK: - 스텁 스케줄러

/// 셈으로 리플레이하는 결정적 스케줄러.
///
/// FSRS 구현(`LearnScheduling`)은 이 타깃에서 링크되지 않는다. 여기서 확인하려는 것도
/// "값이 FSRS 와 같은가" 가 아니라 **"리플레이가 낸 값이 컬럼까지 손실 없이 도착하는가"** 라,
/// 리플레이 규칙은 눈으로 검산 가능한 셈이면 충분하다. FSRS 값과의 일치는
/// `LearnSchedulingTests` 의 골든 회귀가 본다.
///
/// `preview`/`apply` 는 이 테스트가 쓰지 않으므로 던진다 — 조용히 0 을 돌려주면 나중에
/// 누가 그 경로를 쓰기 시작했을 때 알아챌 방법이 없다.
private struct CountingReplayScheduler: ReviewScheduler {
    var schedulerID: String { "stub-counting-replay" }
    var parameterSetID: ParameterSetID { .fsrs6Default }
    var dayBoundary: DayBoundary { DayBoundary(rolloverHour: 4, timeZoneIdentifier: "UTC") }
    let clock: any SchedulerClock

    func initialState(for cardID: CardID, createdAt: EpochMillis) -> CardSchedulingState {
        .newCard(cardID, createdAt: createdAt, parameterSetID: parameterSetID)
    }

    func preview(_ card: CardSchedulingState, at now: EpochMillis) throws -> ReviewPreview {
        throw ReviewSchedulingError.engineFailure(cardID: card.cardID, reason: "스텁은 preview 를 내지 않는다")
    }

    func apply(
        _ rating: ReviewRating,
        to card: CardSchedulingState,
        at now: EpochMillis,
        reviewDurationMS: Int?,
        source: ReviewLogSource
    ) throws -> ReviewOutcome {
        throw ReviewSchedulingError.engineFailure(cardID: card.cardID, reason: "스텁은 apply 를 내지 않는다")
    }

    /// again 하나가 학습 스텝 하나, good 하나가 스텝 하나를 되돌린다. 마지막 리뷰가 again 이면
    /// 스텝이 남고, 그게 006 이전에 저장→로드에서 0 으로 되감기던 값이다.
    func replay(_ log: [ReviewLogEntry]) throws -> CardSchedulingState {
        let ordered = log.replayOrdered()
        guard let first = ordered.first else { throw ReviewSchedulingError.emptyLog }
        for entry in ordered where entry.cardID != first.cardID {
            throw ReviewSchedulingError.mixedCards(expected: first.cardID, found: entry.cardID)
        }

        var state = initialState(for: first.cardID, createdAt: first.reviewedAt)
        state.difficulty = 5
        for entry in ordered where entry.affectsSchedule {
            let elapsed = state.lastReviewedAt.map {
                Int(entry.reviewedAt.milliseconds(since: $0) / 86_400_000)
            }
            state.elapsedDays = max(0, elapsed ?? 0)
            state.reps += 1
            if entry.rating == .again {
                state.lapses += 1
                state.learningStepIndex += 1
                state.phase = .relearning
                state.scheduledDays = 0
            } else {
                state.learningStepIndex = max(0, state.learningStepIndex - 1)
                state.phase = state.learningStepIndex > 0 ? .learning : .review
                state.scheduledDays = state.reps
            }
            state.stability = Double(state.reps)
            state.lastReviewedAt = entry.reviewedAt
            state.dueAt = entry.reviewedAt.adding(days: state.scheduledDays)
            state.derivedFromLogID = entry.id
        }
        return state
    }

    func rebuild(_ log: [ReviewLogEntry]) throws -> CardStateRebuild {
        var buckets: [CardID: [ReviewLogEntry]] = [:]
        for entry in log.replayOrdered() { buckets[entry.cardID, default: []].append(entry) }

        var states: [CardSchedulingState] = []
        var applied = 0
        var skipped = 0
        for cardID in buckets.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let entries = buckets[cardID] ?? []
            states.append(try replay(entries))
            applied += entries.count { $0.affectsSchedule }
            skipped += entries.count { !$0.affectsSchedule }
        }
        return CardStateRebuild(
            states: states,
            appliedEntryCount: applied,
            skippedEntryCount: skipped,
            schedulerID: schedulerID,
            parameterSetID: parameterSetID
        )
    }
}
