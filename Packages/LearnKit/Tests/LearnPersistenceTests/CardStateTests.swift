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
            dueAt: Fixture.days(30),
            lastReviewedAt: Fixture.epoch,
            phase: .relearning,
            reps: 11,
            lapses: 3,
            elapsedDays: 27,
            scheduledDays: 30,
            learningStepIndex: 2,
            derivedFromLogID: logID,
            parameterSetID: .fsrs6Default,
            rebuiltAt: Fixture.days(1)
        )
        try await harness.database.cardStateStore.upsert(original)

        #expect(try await harness.database.cardStateStore.snapshot(forCard: CardID("py-007")) == original)
    }

    /// 두 세션이 각자 정의한 카드 상태를 하나로 합치면서 드러났던 구멍. **이제 메워졌다.**
    ///
    /// 마이그레이션 006 이전에는 `card_state` 에 `elapsed_days`·`learning_step_index` 컬럼이 없어
    /// 캐시를 거쳐 돌아온 상태로 다음 리뷰를 스케줄하면 학습 스텝이 처음으로 되감겼다.
    /// 이 테스트는 그때 유실을 못박던 테스트를 **의미만 뒤집은 것**이다 — 같은 시나리오,
    /// 반대 기대. 컬럼을 다시 잃으면 여기가 먼저 빨개진다.
    @Test("학습 단계 카드의 두 필드가 왕복에서 보존된다 — 006 이 메운 구멍", arguments: DatabaseFlavor.allCases)
    func learningStepSurvivesRoundTrip(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        var snapshot = Fixture.cardState(card: "py-learning")
        snapshot.scheduling.phase = .learning
        snapshot.scheduling.elapsedDays = 7
        snapshot.scheduling.learningStepIndex = 1

        try await harness.database.cardStateStore.upsert(snapshot)
        let fetched = try await harness.database.cardStateStore.snapshot(forCard: CardID("py-learning"))

        #expect(fetched?.scheduling.elapsedDays == 7, "elapsed_days 가 되감겼다")
        #expect(fetched?.scheduling.learningStepIndex == 1, "학습 스텝이 되감겼다")
        // 부분 보존이 아니라 **전부** 보존이다.
        #expect(fetched?.scheduling == snapshot.scheduling)
        #expect(fetched == snapshot)
    }

    /// 되감김이 다음 스케줄에 미치던 영향까지 확인한다.
    ///
    /// 유실 시절에는 스텝 3 짜리 카드를 저장했다 읽으면 0 이 나왔고, 그 상태를 그대로
    /// `apply` 에 넣으면 학습이 처음부터 다시 시작됐다. 값 하나가 아니라 **스텝 진행 전체**가
    /// 보존되는지를 여러 값으로 훑는다.
    @Test("학습 스텝 인덱스가 값과 무관하게 보존된다", arguments: [0, 1, 2, 7])
    func everyLearningStepRoundTrips(step: Int) async throws {
        let harness = try TestDatabase(.inMemory)
        var snapshot = Fixture.cardState(card: "py-step-\(step)")
        snapshot.scheduling.phase = .relearning
        snapshot.scheduling.learningStepIndex = step
        snapshot.scheduling.elapsedDays = step * 2

        try await harness.database.cardStateStore.upsert(snapshot)
        let fetched = try await harness.database.cardStateStore.snapshot(forCard: snapshot.cardID)
        #expect(fetched?.learningStepIndex == step)
        #expect(fetched?.elapsedDays == step * 2)
    }

    /// 006 의 본체는 컬럼 두 개가 아니라 **기존 행을 어떻게 다루는가** 다.
    ///
    /// 005 까지만 적용한 DB 에 006 이전 모양의 행을 넣고 006 을 태운다. 두 컬럼은 0 으로 채워지되,
    /// 그 0 이 틀렸을 수 있는 행(= 이력이 있는 행)은 워터마크가 지워져 `card_state_stale` 에
    /// 걸린다. 이력이 없는 카드는 0 이 실제로 정답이라 건드리지 않는다.
    @Test("006 은 두 컬럼을 0 으로 채우고, 이력이 있는 기존 행만 stale 로 표시한다")
    func migration006MarksLegacyRowsStale() throws {
        let database = try LearnDatabase.inMemory(upTo: "005-lesson-progress")
        #expect(try database.appliedMigrations() == Array(SchemaMigrations.identifiers.dropLast()))

        try database.executeRaw("""
            INSERT INTO review_log
                (card_id, reviewed_at, rating, state_before, elapsed_days, scheduled_days,
                 review_duration_ms, scheduler_id, parameter_set_id, source)
            VALUES ('py-old', 1000, 3, 'learning', 1, 1, 100, 'fsrs6', 'fsrs6-default', 'scheduled')
            """)
        // 006 이전 스키마에는 elapsed_days·learning_step_index 컬럼이 아예 없다.
        try database.executeRaw("""
            INSERT INTO card_state
                (card_id, language_id, stability, difficulty, due_at, state,
                 reps, lapses, scheduled_days, derived_from_log_id, parameter_set_id, rebuilt_at)
            VALUES
                ('py-old', 'python', 1.0, 5.0, 2000, 'learning', 1, 0, 0, 1, 'fsrs6-default', 1),
                ('py-fresh', 'python', 0.0, 5.0, 2000, 'new', 0, 0, 0, NULL, 'fsrs6-default', 1)
            """)

        try database.applyRemainingMigrations()
        #expect(try database.appliedMigrations() == SchemaMigrations.identifiers)

        #expect(try database.scalarInt("SELECT elapsed_days FROM card_state WHERE card_id = 'py-old'") == 0)
        #expect(try database.scalarInt("SELECT learning_step_index FROM card_state WHERE card_id = 'py-old'") == 0)
        #expect(try database.scalarInt("SELECT log_drift FROM card_state_stale WHERE card_id = 'py-old'") == 1)
        #expect(try database.scalarInt("SELECT parameter_drift FROM card_state_stale WHERE card_id = 'py-old'") == 0)

        // 리플레이할 이력이 없는 카드는 0 이 정답이므로 stale 이 아니다.
        #expect(try database.scalarInt("""
            SELECT log_drift + parameter_drift FROM card_state_stale WHERE card_id = 'py-fresh'
            """) == 0)

        // 캐시는 비우지 않는다 — 재구축이 끝날 때까지 큐가 텅 비면 안 된다.
        #expect(try database.scalarInt("SELECT COUNT(*) FROM card_state") == 2)
    }

    /// 006 의 CHECK 는 002 의 나머지 제약과 같은 규칙을 따른다 — 카운터는 음수가 될 수 없다.
    @Test("음수 learning_step_index 는 CHECK 가 거부한다")
    func learningStepIndexRangeIsEnforced() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO card_state
                    (card_id, language_id, stability, difficulty, due_at, state,
                     reps, lapses, elapsed_days, scheduled_days, learning_step_index,
                     parameter_set_id, rebuilt_at)
                VALUES ('c', 'python', 1.0, 5.0, 1, 'learning', 0, 0, 0, 0, -1, 'fsrs6-default', 1)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }

    @Test("리뷰가 없는 신규 카드는 derived_from_log_id 가 nil 이다", arguments: DatabaseFlavor.allCases)
    func newCardsHaveNilWatermark(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        var snapshot = Fixture.cardState(card: "py-new")
        snapshot.phase = .new
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
            dueAtOrBefore: Fixture.days(4),
            limit: 10
        )
        #expect(due.map(\.cardID.rawValue) == ["py-early", "py-mid"])

        let sqlDue = try await cards.dueCards(
            languageID: .sql,
            dueAtOrBefore: Fixture.days(4),
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
