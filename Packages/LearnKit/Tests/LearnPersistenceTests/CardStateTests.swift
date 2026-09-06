import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

@Suite("card_state — 버리고 다시 만들 수 있는 파생 캐시")
struct CardStateTests {
    /// `{#m002-card-state}` 의 완료 기준.
    @Test("통째 DELETE 후 재구축하면 이전과 동일한 행이 나온다", arguments: DatabaseFlavor.allCases)
    func rebuildReproducesIdenticalRows(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let log = harness.database.reviewLogStore
        let cards = harness.database.cardStateStore

        let logID = try await log.append(Fixture.reviewEntry())
        let snapshots = [
            Fixture.cardState(card: "py-001", derivedFrom: logID),
            Fixture.cardState(card: "sql-001", language: .sql, dueOffsetDays: 3),
            Fixture.cardState(card: "swift-001", language: .swift, dueOffsetDays: 0),
        ]
        try await cards.replaceAll(with: snapshots)

        let before = try await allSnapshots(cards)
        let logCountBefore = try await log.count()

        // 캐시를 통째로 버린다.
        try await cards.deleteAll()
        #expect(try await cards.count() == 0)
        #expect(try await log.count() == logCountBefore, "캐시를 지우면서 로그를 건드렸다")

        // 같은 입력으로 다시 만든다.
        try await cards.replaceAll(with: snapshots)
        let after = try await allSnapshots(cards)

        #expect(after == before)
        #expect(try await log.count() == logCountBefore)
    }

    private func allSnapshots(_ store: any CardStateStore) async throws -> [CardStateSnapshot] {
        var result: [CardStateSnapshot] = []
        for language in [LanguageID.python, .sql, .swift] {
            result += try await store.dueCards(
                languageID: language,
                dueAtOrBefore: .max,
                limit: 1_000
            )
        }
        return result.sorted { $0.cardID.rawValue < $1.cardID.rawValue }
    }

    @Test("모든 컬럼이 라운드트립한다", arguments: DatabaseFlavor.allCases)
    func roundTripsAllColumns(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let logID = try await harness.database.reviewLogStore.append(Fixture.reviewEntry())
        let original = CardStateSnapshot(
            cardID: CardID("py-007"),
            languageID: .python,
            stability: 12.5,
            difficulty: 7.125,
            dueAt: Fixture.epoch + 30 * Fixture.day,
            lastReviewedAt: Fixture.epoch,
            state: .relearning,
            reps: 11,
            lapses: 3,
            scheduledDays: 30,
            derivedFromLogID: logID,
            parameterSetID: .fsrs6Default,
            rebuiltAt: Fixture.epoch + Fixture.day
        )
        try await harness.database.cardStateStore.upsert(original)

        #expect(try await harness.database.cardStateStore.snapshot(forCard: CardID("py-007")) == original)
    }

    @Test("리뷰가 없는 신규 카드는 derived_from_log_id 가 nil 이다", arguments: DatabaseFlavor.allCases)
    func newCardsHaveNilWatermark(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        var snapshot = Fixture.cardState(card: "py-new")
        snapshot.state = .new
        snapshot.stability = 0
        snapshot.reps = 0
        snapshot.lastReviewedAt = nil
        snapshot.derivedFromLogID = nil

        try await harness.database.cardStateStore.upsert(snapshot)
        let fetched = try await harness.database.cardStateStore.snapshot(forCard: CardID("py-new"))
        #expect(fetched?.derivedFromLogID == nil)
        #expect(fetched?.lastReviewedAt == nil)
    }

    // MARK: - {#card-state-index}

    @Test("due 큐가 (language_id, due_at) 인덱스를 타고 SCAN 이 없다", arguments: DatabaseFlavor.allCases)
    func dueQueueUsesIndex(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let plan = try harness.database.queryPlan(for: """
            SELECT * FROM card_state
            WHERE language_id = 'python' AND due_at <= 0
            ORDER BY due_at, card_id
            LIMIT 50
            """)
        #expect(plan.contains { $0.contains("idx_card_state_due") }, "\(plan)")
        #expect(!plan.contains { $0.contains("SCAN") }, "전체 스캔이 있다: \(plan)")
    }

    @Test("due 큐는 언어로 먼저 좁히고 due_at 순으로 낸다", arguments: DatabaseFlavor.allCases)
    func dueQueueIsScopedAndOrdered(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let cards = harness.database.cardStateStore
        try await cards.replaceAll(with: [
            Fixture.cardState(card: "py-late", dueOffsetDays: 5),
            Fixture.cardState(card: "py-early", dueOffsetDays: 1),
            Fixture.cardState(card: "py-mid", dueOffsetDays: 3),
            Fixture.cardState(card: "sql-early", language: .sql, dueOffsetDays: 1),
        ])

        let due = try await cards.dueCards(
            languageID: .python,
            dueAtOrBefore: Fixture.epoch + 4 * Fixture.day,
            limit: 10
        )
        #expect(due.map(\.cardID.rawValue) == ["py-early", "py-mid"])

        let sqlDue = try await cards.dueCards(
            languageID: .sql,
            dueAtOrBefore: Fixture.epoch + 4 * Fixture.day,
            limit: 10
        )
        #expect(sqlDue.map(\.cardID.rawValue) == ["sql-early"])
    }

    // MARK: - {#card-state-columns} stale 판정

    @Test("새 리뷰가 쌓이면 log_drift 로 stale 이 된다", arguments: DatabaseFlavor.allCases)
    func newReviewMakesCacheStale(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let log = harness.database.reviewLogStore
        let cards = harness.database.cardStateStore

        let firstID = try await log.append(Fixture.reviewEntry())
        try await cards.upsert(Fixture.cardState(derivedFrom: firstID))
        #expect(try await cards.staleCount() == 0)

        try await log.append(Fixture.reviewEntry(at: 1))
        let stale = try await cards.staleCards(limit: 10)
        #expect(stale.count == 1)
        #expect(stale.first?.logDrift == true)
        #expect(stale.first?.parameterDrift == false)
        #expect(stale.first?.isStale == true)
    }

    @Test("파라미터 세트가 바뀌면 parameter_drift 로 stale 이 된다", arguments: DatabaseFlavor.allCases)
    func parameterChangeMakesCacheStale(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let log = harness.database.reviewLogStore
        let cards = harness.database.cardStateStore

        let logID = try await log.append(Fixture.reviewEntry())
        try await cards.upsert(Fixture.cardState(derivedFrom: logID))
        #expect(try await cards.staleCount() == 0)

        try await log.save(
            parameterSet: SchedulerParameterSet(
                id: ParameterSetID("optimized"),
                weights: [0.4],
                desiredRetention: 0.9,
                createdAt: Fixture.epoch,
                isActive: false
            ),
            activate: true
        )

        let stale = try await cards.staleCards(limit: 10)
        #expect(stale.count == 1)
        #expect(stale.first?.parameterDrift == true)
        #expect(stale.first?.logDrift == false)
    }

    @Test("리뷰가 없는 신규 카드는 stale 이 아니다", arguments: DatabaseFlavor.allCases)
    func newCardIsNotStale(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        var snapshot = Fixture.cardState(card: "py-new")
        snapshot.derivedFromLogID = nil
        try await harness.database.cardStateStore.upsert(snapshot)
        #expect(try await harness.database.cardStateStore.staleCount() == 0)
    }

    // MARK: - 제약

    @Test("난이도 범위를 벗어난 값은 CHECK 가 거부한다")
    func difficultyRangeIsEnforced() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO card_state
                    (card_id, language_id, stability, difficulty, due_at, state,
                     reps, lapses, scheduled_days, parameter_set_id, rebuilt_at)
                VALUES ('c', 'python', 1.0, 42.0, 1, 'review', 0, 0, 0, 'fsrs6-default', 1)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }

    @Test("존재하지 않는 review_log 를 워터마크로 가리킬 수 없다")
    func watermarkForeignKeyIsEnforced() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO card_state
                    (card_id, language_id, stability, difficulty, due_at, state,
                     reps, lapses, scheduled_days, derived_from_log_id,
                     parameter_set_id, rebuilt_at)
                VALUES ('c', 'python', 1.0, 5.0, 1, 'review', 0, 0, 0, 9999, 'fsrs6-default', 1)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintForeignKey)
    }
}
