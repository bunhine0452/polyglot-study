import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

@Suite("review_log — append-only 진실의 원천")
struct ReviewLogTests {
    // MARK: - {#m001-review-log} append-only 봉인

    @Test("UPDATE 는 SQLITE_CONSTRAINT 로 ABORT 된다", arguments: DatabaseFlavor.allCases)
    func updateIsSealed(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let id = try await harness.database.reviewLogStore.append(Fixture.reviewEntry())

        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("UPDATE review_log SET rating = 1 WHERE id = \(id.rawValue)")
        }
        #expect(failure?.primaryResultCode == SQLiteResultCode.constraint)
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintTrigger)
        #expect(failure?.message.contains("append-only") == true)

        // 도메인 경계로 나갈 때의 모습.
        if case .appendOnlyViolation(let table, let operation)? = failure?.mapped as? StoreError {
            #expect(table == "review_log")
            #expect(operation == "UPDATE")
        } else {
            Issue.record("StoreError.appendOnlyViolation 로 매핑되지 않았다: \(String(describing: failure?.mapped))")
        }

        // 값이 정말 안 바뀌었는지.
        let entries = try await harness.database.reviewLogStore.entries(forCard: CardID("py-001"))
        #expect(entries.first?.rating == .good)
    }

    @Test("DELETE 는 SQLITE_CONSTRAINT 로 ABORT 된다", arguments: DatabaseFlavor.allCases)
    func deleteIsSealed(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await harness.database.reviewLogStore.append(Fixture.reviewEntry())

        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("DELETE FROM review_log")
        }
        #expect(failure?.primaryResultCode == SQLiteResultCode.constraint)
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintTrigger)
        if case .appendOnlyViolation(_, let operation)? = failure?.mapped as? StoreError {
            #expect(operation == "DELETE")
        } else {
            Issue.record("DELETE 가 appendOnlyViolation 으로 매핑되지 않았다")
        }
        #expect(try await harness.database.reviewLogStore.count() == 1)
    }

    // MARK: - {#review-log-columns} CHECK 6종

    @Test(
        "CHECK 6종이 각각 거부한다",
        arguments: [
            ("chk_review_log_card_id", "'', 1767225600000, 3, 'new', 0, 0, 0"),
            ("chk_review_log_reviewed_at", "'c', 0, 3, 'new', 0, 0, 0"),
            ("chk_review_log_rating", "'c', 1767225600000, 5, 'new', 0, 0, 0"),
            ("chk_review_log_state_before", "'c', 1767225600000, 3, 'unknown', 0, 0, 0"),
            ("chk_review_log_intervals", "'c', 1767225600000, 3, 'new', -1, 0, 0"),
            ("chk_review_log_intervals_duration", "'c', 1767225600000, 3, 'new', 0, 0, -5"),
        ]
    )
    func checkConstraintsReject(name: String, values: String) throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO review_log
                    (card_id, reviewed_at, rating, state_before,
                     elapsed_days, scheduled_days, review_duration_ms,
                     scheduler_id, parameter_set_id, source)
                VALUES (\(values), 'fsrs6', 'fsrs6-default', 'scheduled')
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck, "\(name) 이 걸리지 않았다")
    }

    @Test("source 도메인 밖 값은 거부된다")
    func sourceDomainIsEnforced() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO review_log
                    (card_id, reviewed_at, rating, state_before,
                     elapsed_days, scheduled_days, review_duration_ms,
                     scheduler_id, parameter_set_id, source)
                VALUES ('c', 1767225600000, 3, 'new', 0, 0, 0, 'fsrs6', 'fsrs6-default', 'guess')
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }

    /// CHECK 리터럴의 주인은 `LearnPersistence` 의 `DomainColumns.swift` 다 — 도메인 열거형은
    /// 정수(`CardPhase`)이거나 다른 스펠링(`.review` → `'scheduled'`)이라 rawValue 를 그대로
    /// 비교하면 안 된다. 여기서 못박는 것은 **매핑 결과가 CHECK 와 정확히 같은 집합**이라는 것.
    @Test("CHECK 도메인이 LearnCore 열거형의 컬럼 표현과 정확히 일치한다")
    func checkDomainsMatchEnums() throws {
        let harness = try TestDatabase(.inMemory)

        #expect(
            try SchemaDomain.literals(of: "chk_review_log_state_before", in: harness.database)
                == Set(CardPhase.allCases.map(\.sqlText))
        )
        #expect(
            try SchemaDomain.literals(of: "chk_card_state_state", in: harness.database)
                == Set(CardPhase.allCases.map(\.sqlText))
        )
        #expect(
            try SchemaDomain.literals(of: "chk_review_log_source", in: harness.database)
                == Set(ReviewLogSource.allCases.map(\.sqlText))
        )

        // 매핑이 왕복해야 저장한 행을 다시 읽을 수 있다.
        for phase in CardPhase.allCases { #expect(CardPhase(sqlText: phase.sqlText) == phase) }
        for source in ReviewLogSource.allCases {
            #expect(ReviewLogSource(sqlText: source.sqlText) == source)
        }

        // rating 은 정수 1..4 — 열거형 rawValue 가 그 범위를 벗어나면 CHECK 가 틀린 것이다.
        #expect(ReviewRating.allCases.map(\.rawValue).sorted() == [1, 2, 3, 4])
    }

    // MARK: - {#review-log-no-fk}

    @Test("팩 소유 테이블로 나가는 외래키가 없다 — 유일한 FK 는 scheduler_parameters")
    func onlyForeignKeyIsParameterSet() throws {
        let harness = try TestDatabase(.inMemory)
        let schema = try harness.database.schemaDump()
        guard let table = schema.range(of: "CREATE TABLE review_log")
            .map({ String(schema[$0.lowerBound...]) })?
            .components(separatedBy: ") STRICT;").first
        else {
            Issue.record("review_log 정의를 찾지 못했다")
            return
        }
        let references = table.components(separatedBy: "REFERENCES").dropFirst()
        #expect(references.count == 1, "review_log 의 FK 는 하나여야 한다")
        #expect(references.first?.contains("scheduler_parameters") == true)
    }

    @Test("존재하지 않는 파라미터 세트를 참조하면 거부된다", arguments: DatabaseFlavor.allCases)
    func unknownParameterSetIsRejected(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        var entry = Fixture.reviewEntry()
        entry.parameterSetID = ParameterSetID("does-not-exist")

        await #expect(throws: StoreError.self) {
            try await harness.database.reviewLogStore.append(entry)
        }
        #expect(try await harness.database.reviewLogStore.count() == 0)
    }

    // MARK: - {#review-log-indexes}

    @Test("리플레이 쿼리가 인덱스를 타고 SCAN 이 없다", arguments: DatabaseFlavor.allCases)
    func replayQueryUsesIndex(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let plan = try harness.database.queryPlan(
            for: "SELECT * FROM review_log WHERE card_id = 'py-001' ORDER BY reviewed_at, id"
        )
        #expect(plan.contains { $0.contains("idx_review_log_card_replay") }, "\(plan)")
        #expect(!plan.contains { $0.contains("SCAN") }, "전체 스캔이 있다: \(plan)")
        // 인덱스 순서가 정렬을 그대로 만족하므로 임시 B-트리가 생기면 안 된다.
        #expect(!plan.contains { $0.contains("TEMP B-TREE") }, "정렬이 인덱스로 안 끝났다: \(plan)")
    }

    @Test("통계 쿼리가 reviewed_at 인덱스를 타고 SCAN 이 없다", arguments: DatabaseFlavor.allCases)
    func statisticsQueryUsesIndex(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let plan = try harness.database.queryPlan(
            for: "SELECT COUNT(*) FROM review_log WHERE reviewed_at >= 0 AND reviewed_at < 1"
        )
        #expect(plan.contains { $0.contains("idx_review_log_reviewed_at") }, "\(plan)")
        #expect(!plan.contains { $0.contains("SCAN") }, "전체 스캔이 있다: \(plan)")
    }

    // MARK: - 읽기 경로

    @Test("카드 이력은 (reviewed_at, id) 오름차순으로 나온다", arguments: DatabaseFlavor.allCases)
    func entriesAreOrdered(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.reviewLogStore
        // 일부러 뒤섞어 넣는다.
        try await store.append(Fixture.reviewEntry(at: 2, rating: .easy))
        try await store.append(Fixture.reviewEntry(at: 0, rating: .again))
        try await store.append(Fixture.reviewEntry(at: 1, rating: .hard))
        try await store.append(Fixture.reviewEntry(card: "sql-001", at: 0))

        let entries = try await store.entries(forCard: CardID("py-001"))
        #expect(entries.map(\.rating) == [.again, .hard, .easy])
        #expect(entries.map(\.reviewedAt) == entries.map(\.reviewedAt).sorted())
        #expect(try await store.count() == 4)
    }

    @Test("append 는 저장한 값을 그대로 되돌려준다 (라운드트립)", arguments: DatabaseFlavor.allCases)
    func roundTripsAllColumns(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let original = ReviewLogEntry(
            cardID: CardID("swift-042"),
            reviewedAt: Fixture.days(7),
            rating: .hard,
            stateBefore: .relearning,
            elapsedDays: 9,
            scheduledDays: 4,
            reviewDurationMS: 12_345,
            schedulerID: "fsrs6",
            parameterSetID: .fsrs6Default,
            source: .cram
        )
        let id = try await harness.database.reviewLogStore.append(original)

        let fetched = try await harness.database.reviewLogStore
            .entries(forCard: CardID("swift-042"))
        var expected = original
        expected.id = id
        #expect(fetched == [expected])
    }

    @Test("id 페이지네이션이 로그를 빠짐없이 훑는다", arguments: DatabaseFlavor.allCases)
    func paginationCoversEverything(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.reviewLogStore
        try await store.append(contentsOf: (0..<25).map { Fixture.reviewEntry(at: $0) })

        var cursor: ReviewLogID?
        var seen: [ReviewLogID] = []
        while true {
            let page = try await store.entries(after: cursor, limit: 10)
            if page.isEmpty { break }
            seen.append(contentsOf: page.compactMap(\.id))
            cursor = page.last?.id
        }
        #expect(seen.count == 25)
        #expect(seen == seen.sorted())
        #expect(Set(seen).count == 25)
    }

    @Test("기간 집계는 반열린 구간이다", arguments: DatabaseFlavor.allCases)
    func countUsesHalfOpenRange(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.reviewLogStore
        try await store.append(contentsOf: (0..<5).map { Fixture.reviewEntry(at: $0) })

        #expect(try await store.count(from: Fixture.epoch, to: Fixture.epoch) == 0)
        #expect(try await store.count(from: Fixture.epoch, to: Fixture.days(1)) == 1)
        #expect(try await store.count(from: Fixture.epoch, to: Fixture.days(5)) == 5)
    }

    // MARK: - {#scheduler-parameters}

    @Test("마이그레이션이 활성 세트를 정확히 하나 심는다", arguments: DatabaseFlavor.allCases)
    func exactlyOneActiveParameterSetIsSeeded(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let active = try await harness.database.reviewLogStore.activeParameterSet()
        #expect(active.id == .fsrs6Default)
        #expect(active.schedulerID == "fsrs6")
        // nil = 스케줄러 내장 기본 가중치. 상수 사본을 영속화 계층에 두지 않는다.
        #expect(active.weights == nil)
        #expect(try harness.database.scalarInt(
            "SELECT COUNT(*) FROM scheduler_parameters WHERE is_active = 1"
        ) == 1)
    }

    @Test("활성 세트가 둘이 되는 것을 부분 유니크 인덱스가 막는다")
    func partialUniqueIndexForbidsTwoActiveSets() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO scheduler_parameters
                    (id, scheduler_id, weights, desired_retention, created_at, is_active)
                VALUES ('rival', 'fsrs6', NULL, 0.9, 1, 1)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintUnique)
    }

    @Test("비활성 세트는 여러 개 있어도 된다 — 과거 리뷰를 설명해야 하므로")
    func inactiveSetsMayCoexist() async throws {
        let harness = try TestDatabase(.inMemory)
        let store = harness.database.reviewLogStore

        try await store.save(
            parameterSet: SchedulerParameterSet(
                id: ParameterSetID("optimized-2026-03"),
                weights: [0.4, 1.2, 3.1],
                desiredRetention: 0.92,
                createdAt: Fixture.epoch,
                isActive: false
            ),
            activate: false
        )
        try await store.save(
            parameterSet: SchedulerParameterSet(
                id: ParameterSetID("optimized-2026-06"),
                weights: [0.5, 1.3, 3.2],
                desiredRetention: 0.9,
                createdAt: Fixture.epoch,
                isActive: false
            ),
            activate: false
        )

        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM scheduler_parameters") == 3)
        #expect(try await store.activeParameterSet().id == .fsrs6Default)
    }

    @Test("세트 활성화는 원자적으로 교체된다 — 중간에 활성 0개나 2개가 없다")
    func activationSwapsAtomically() async throws {
        let harness = try TestDatabase(.inMemory)
        let store = harness.database.reviewLogStore
        let next = SchedulerParameterSet(
            id: ParameterSetID("optimized-2026-03"),
            weights: [0.4, 1.2, 3.1],
            desiredRetention: 0.92,
            createdAt: Fixture.epoch,
            isActive: false
        )

        try await store.save(parameterSet: next, activate: true)

        #expect(try await store.activeParameterSet().id == next.id)
        #expect(try await store.activeParameterSet().weights == [0.4, 1.2, 3.1])
        #expect(try harness.database.scalarInt(
            "SELECT COUNT(*) FROM scheduler_parameters WHERE is_active = 1"
        ) == 1)
        // 이전 세트는 남아 있어야 한다 — 그걸로 스케줄된 과거 리뷰가 설명 불가가 되면 안 된다.
        #expect(try await store.parameterSet(id: .fsrs6Default) != nil)
    }

    @Test("활성 세트를 0개로 만드는 저장은 롤백된다", arguments: DatabaseFlavor.allCases)
    func cannotLeaveZeroActiveSets(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        let store = harness.database.reviewLogStore
        var active = try await store.activeParameterSet()
        active.isActive = false

        await #expect(throws: StoreError.self) {
            try await store.save(parameterSet: active, activate: false)
        }
        #expect(try await store.activeParameterSet().id == .fsrs6Default)
        #expect(try harness.database.scalarInt(
            "SELECT COUNT(*) FROM scheduler_parameters WHERE is_active = 1"
        ) == 1)
    }

    @Test("weights JSON 이 아닌 값은 CHECK 가 거부한다")
    func weightsMustBeValidJSON() throws {
        let harness = try TestDatabase(.inMemory)
        let failure = #expect(throws: RawSQLFailure.self) {
            try harness.database.executeRaw("""
                INSERT INTO scheduler_parameters
                    (id, scheduler_id, weights, desired_retention, created_at, is_active)
                VALUES ('broken', 'fsrs6', 'not json', 0.9, 1, 0)
                """)
        }
        #expect(failure?.extendedResultCode == SQLiteResultCode.constraintCheck)
    }
}
