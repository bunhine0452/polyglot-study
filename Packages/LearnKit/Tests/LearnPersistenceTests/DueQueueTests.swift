import Foundation
import Testing
@testable import LearnPersistence
import LearnCore

/// `{#due-queue-benchmark}` `{#queue-mixing}`
///
/// 두 가지를 지킨다. **혼합과 상한이 SQL 안에서 결정되는가**, 그리고 **22.8만 행에서도
/// 인덱스만으로 끝나는가**. 앞의 것은 값으로, 뒤의 것은 쿼리 플랜으로 못박는다.
@Suite("due 큐 — 혼합 비율·일일 상한·22.8만 행 실측")
struct DueQueueTests {
    // MARK: - 정책 산수

    @Test("일일 상한 20 · 신규 몫 0.25 는 신규 5 · 복습 15 로 갈린다")
    func policySplitsTheDailyLimit() {
        let policy = DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        #expect(policy.newAllowance == 5)
        #expect(policy.reviewAllowance == 15)
        #expect(policy.newAllowance + policy.reviewAllowance == policy.dailyLimit)
    }

    @Test("두 몫의 합은 언제나 일일 상한이다 — 반올림은 신규 쪽에서 한 번만", arguments: [0.0, 0.1, 0.33, 0.5, 0.9, 1.0])
    func allowancesAlwaysSumToTheLimit(share: Double) {
        let policy = DueQueuePolicy(dailyLimit: 20, newShare: share)
        #expect(policy.newAllowance + policy.reviewAllowance == 20)
        #expect(policy.newAllowance >= 0)
        #expect(policy.reviewAllowance >= 0)
    }

    // MARK: - 큐가 실제로 그렇게 자르는가

    /// `{#queue-mixing}` 의 완료 기준.
    @Test("일일 상한 20 설정에서 신규 5 · 복습 15 가 나온다", arguments: DatabaseFlavor.allCases)
    func queueRespectsTheDailyMix(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [trackSnapshots(reviews: 100, news: 100, learning: 0)])

        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )

        #expect(bucketCounts(queue) == [.review: 15, .new: 5])
        #expect(queue.count == 20)
        // 우선순위 순서 — 복습이 먼저, 신규가 뒤.
        #expect(queue.map(\.bucket) == Array(repeating: .review, count: 15) + Array(repeating: .new, count: 5))
    }

    @Test("학습중 카드는 일일 상한 밖이다 — 상한 20 인데 23장이 나온다", arguments: DatabaseFlavor.allCases)
    func learningCardsBypassTheDailyLimit(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [trackSnapshots(reviews: 100, news: 100, learning: 3)])

        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )

        #expect(bucketCounts(queue) == [.learning: 3, .review: 15, .new: 5])
        #expect(queue.prefix(3).allSatisfy { $0.bucket == .learning }, "학습중이 맨 앞이 아니다")
    }

    @Test("몫은 서로 넘겨받지 않는다 — 신규가 2장뿐이어도 복습은 15장 그대로", arguments: DatabaseFlavor.allCases)
    func allowancesDoNotBackfillEachOther(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [trackSnapshots(reviews: 100, news: 2, learning: 0)])

        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )

        #expect(bucketCounts(queue) == [.review: 15, .new: 2])
    }

    /// 상한은 세션이 아니라 학습일 단위다 — 앱을 다시 열 때마다 20장이 새로 나오면 상한이 아니다.
    @Test("오늘 이미 푼 만큼 남은 몫이 줄어든다", arguments: DatabaseFlavor.allCases)
    func todaysProgressConsumesTheAllowance(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [trackSnapshots(reviews: 100, news: 100, learning: 0)])

        // 오늘 신규 3장, 복습 4장을 큐로 풀었다. 같은 신규 카드의 학습 스텝 두 번째 리뷰는
        // 새 카드를 소비한 게 아니므로 한 장으로 센다.
        for index in 0..<3 {
            try await harness.database.reviewLogStore.append(
                queueReview(card: newCardID(.python, index), stateBefore: .new, at: Fixture.days(10))
            )
        }
        try await harness.database.reviewLogStore.append(
            queueReview(card: newCardID(.python, 0), stateBefore: .learning, at: Fixture.days(10))
        )
        for index in 0..<4 {
            try await harness.database.reviewLogStore.append(
                queueReview(card: reviewCardID(.python, index), stateBefore: .review, at: Fixture.days(10))
            )
        }

        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10).adding(minutes: 1),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )

        #expect(bucketCounts(queue) == [.review: 11, .new: 2])
    }

    @Test("어제 푼 것은 오늘 몫을 건드리지 않는다", arguments: DatabaseFlavor.allCases)
    func yesterdaysProgressIsIrrelevant(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [trackSnapshots(reviews: 100, news: 100, learning: 0)])
        for index in 0..<5 {
            try await harness.database.reviewLogStore.append(
                queueReview(card: newCardID(.python, index), stateBefore: .new, at: Fixture.days(9))
            )
        }

        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )
        #expect(bucketCounts(queue) == [.review: 15, .new: 5])
    }

    /// 몰아보기가 오늘의 복습 예산을 갉아먹으면 시험 전날 정규 복습이 사라진다.
    @Test("몰아보기(cram)는 오늘 몫을 소비하지 않는다", arguments: DatabaseFlavor.allCases)
    func cramDoesNotConsumeTheAllowance(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [trackSnapshots(reviews: 100, news: 100, learning: 0)])
        for index in 0..<10 {
            try await harness.database.reviewLogStore.append(
                queueReview(card: reviewCardID(.python, index), stateBefore: .review, at: Fixture.days(10), source: .cram)
            )
        }

        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10).adding(minutes: 1),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )
        #expect(bucketCounts(queue) == [.review: 15, .new: 5])
    }

    @Test("다른 트랙의 진도는 이 트랙의 몫을 건드리지 않는다", arguments: DatabaseFlavor.allCases)
    func otherTracksAreIndependent(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [
            trackSnapshots(reviews: 100, news: 100, learning: 0),
            trackSnapshots(language: .sql, reviews: 100, news: 100, learning: 0),
        ])
        for index in 0..<5 {
            try await harness.database.reviewLogStore.append(
                queueReview(card: newCardID(.sql, index), stateBefore: .new, at: Fixture.days(10))
            )
        }

        let python = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10).adding(minutes: 1),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )
        #expect(bucketCounts(python) == [.review: 15, .new: 5])
        #expect(python.allSatisfy { $0.snapshot.languageID == .python })

        let sql = try await harness.database.cardStateStore.queue(
            languageID: .sql,
            now: Fixture.days(10).adding(minutes: 1),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )
        #expect(bucketCounts(sql) == [.review: 15])
    }

    @Test("아직 due 가 아닌 카드는 나오지 않는다", arguments: DatabaseFlavor.allCases)
    func futureCardsStayOut(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [
            trackSnapshots(reviews: 100, news: 0, learning: 0, dueSpread: true),
        ])

        // due 는 days(1)...days(100). 기준을 days(4) 로 두면 4장만 남는다.
        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(4),
            studyDayStart: Fixture.days(4),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )
        #expect(bucketCounts(queue) == [.review: 4])
    }

    @Test("sessionLimit 은 상한과 별개로 반환 행 수를 자른다", arguments: DatabaseFlavor.allCases)
    func sessionLimitCapsTheReturnedRows(flavor: DatabaseFlavor) async throws {
        let harness = try TestDatabase(flavor)
        try await seedTracks(harness.database, [trackSnapshots(reviews: 100, news: 100, learning: 10)])

        let queue = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(200),
            studyDayStart: Fixture.days(200),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25, sessionLimit: 5)
        )
        #expect(queue.count == 5)
        #expect(queue.allSatisfy { $0.bucket == .learning }, "가장 급한 갈래가 먼저 채워야 한다")
    }

    /// 페이크로 짠 스케줄링 로직이 실제 DB 에서 다르게 돌면 늦게 발견될수록 비싸다.
    @Test("페이크와 GRDB 구현이 같은 큐를 낸다")
    func fakeAndRealAgreeOnTheQueue() async throws {
        let harness = try TestDatabase(.inMemory)
        let fakes = InMemoryStores()

        let snapshots = trackSnapshots(reviews: 30, news: 30, learning: 2)
        try await harness.database.cardStateStore.replaceAll(with: snapshots)
        try await fakes.cardState.replaceAll(with: snapshots)
        for index in 0..<2 {
            let entry = queueReview(card: newCardID(.python, index), stateBefore: .new, at: Fixture.days(10))
            try await harness.database.reviewLogStore.append(entry)
            try await fakes.reviewLog.append(entry)
        }

        let policy = DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        let real = try await harness.database.cardStateStore.queue(
            languageID: .python,
            now: Fixture.days(10).adding(minutes: 1),
            studyDayStart: Fixture.days(10),
            policy: policy
        )
        let fake = try await fakes.cardState.queue(
            languageID: .python,
            now: Fixture.days(10).adding(minutes: 1),
            studyDayStart: Fixture.days(10),
            policy: policy
        )
        #expect(real == fake)
        #expect(bucketCounts(real) == [.learning: 2, .review: 15, .new: 3])
    }

    // MARK: - {#due-queue-benchmark} 쿼리 플랜

    /// **회귀를 잡는 건 이 단언이다.** 시간은 CI 머신에 좌우되지만 플랜은 아니다.
    ///
    /// `card_state` 와 `review_log` 는 반드시 인덱스로 접근해야 한다. 플랜에 남는 `SCAN` 은
    /// 전부 20~50행짜리 CTE 를 훑는 것이고, 그건 자르고 난 **뒤**의 일이라 규모와 무관하다.
    @Test("큐 쿼리 플랜에 기반 테이블 전체 스캔이 없다", arguments: DatabaseFlavor.allCases)
    func queuePlanNeverScansABaseTable(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let plan = try harness.database.dueQueuePlan(
            languageID: .python,
            now: Fixture.days(10),
            studyDayStart: Fixture.days(10),
            policy: DueQueuePolicy(dailyLimit: 20, newShare: 0.25)
        )

        // 잘라낸 결과를 담는 CTE 들. 이것들만 SCAN 되어도 된다.
        let boundedRelations: Set<String> = ["learning", "reviewing", "introducing", "picked", "p", "done"]
        let scanned = plan.compactMap(scannedRelation(in:))
        #expect(
            Set(scanned).isSubset(of: boundedRelations),
            "기반 테이블을 통째로 훑는다: \(Set(scanned).subtracting(boundedRelations)) — 전체 플랜 \(plan)"
        )

        // 버킷 셋이 전부 큐 인덱스를 탄다.
        let bucketSearches = plan.filter { $0.contains("idx_card_state_queue") }
        #expect(bucketSearches.count == 3, "버킷 3개가 모두 큐 인덱스를 타야 한다: \(plan)")
        #expect(bucketSearches.allSatisfy { $0.contains("COVERING INDEX") }, "커버링이 아니다: \(bucketSearches)")

        // 기반 테이블에 닿는 모든 줄이 SEARCH + 인덱스다.
        for line in plan where line.contains("card_state") || line.contains("review_log") {
            #expect(line.contains("SEARCH") && line.contains("INDEX"), "인덱스 없이 접근한다: \(line)")
        }
    }

    @Test("002 의 (language_id, due_at) 인덱스도 그대로 살아 있다", arguments: DatabaseFlavor.allCases)
    func legacyDueIndexStillServesTheRawQuery(flavor: DatabaseFlavor) throws {
        let harness = try TestDatabase(flavor)
        let plan = try harness.database.queryPlan(for: """
            SELECT COUNT(*) FROM card_state WHERE language_id = 'python' AND due_at <= 0
            """)
        #expect(plan.contains { $0.contains("idx_card_state_due") }, "\(plan)")
    }

    // MARK: - {#due-queue-benchmark} 22.8만 행 실측

    /// 228 레슨 × 카드 = 약 22.8만 행. 픽스처는 **코드로 만든다** — 바이너리를 커밋하면
    /// 스키마가 바뀔 때마다 썩고, 썩은 픽스처는 벤치를 조용히 무의미하게 만든다.
    ///
    /// 시간 단언이 관대한 것은 의도다. CI 머신의 성능 편차가 5ms 를 우습게 넘기므로,
    /// 여기서 회귀를 잡는 것은 위의 플랜 단언이고 이 숫자는 "자릿수가 틀리지 않았나" 를 본다.
    @Test("22.8만 행에서 언어 하나의 due 큐 50장이 인덱스만으로 끝난다")
    func benchmarkAtFullScale() async throws {
        let harness = try TestDatabase(.file)
        let rows = 228_000
        let languages = 10
        try seedBenchmarkFixture(harness.database, cards: rows, languages: languages, logs: 20_000)

        #expect(try harness.database.scalarInt("SELECT COUNT(*) FROM card_state") == rows)

        let language = LanguageID("lang-3")
        let now = EpochMillis(400_000_000)
        // 로그의 reviewed_at 은 1000...20_000_000 이다. 오늘의 시작을 여기 두면 마지막 100여 건만
        // 오늘 몫으로 잡혀 done 집계가 실제로 일을 하면서도 몫을 다 태우지는 않는다.
        let dayStart = EpochMillis(19_900_000)
        let policy = DueQueuePolicy(dailyLimit: 40, newShare: 0.25, sessionLimit: 50)

        let plan = try harness.database.dueQueuePlan(
            languageID: language, now: now, studyDayStart: dayStart, policy: policy
        )
        let boundedRelations: Set<String> = ["learning", "reviewing", "introducing", "picked", "p", "done"]
        #expect(Set(plan.compactMap(scannedRelation(in:))).isSubset(of: boundedRelations), "\(plan)")

        let store = harness.database.cardStateStore
        // 첫 호출은 페이지 캐시를 데우는 값이라 재지 않는다.
        _ = try await store.queue(languageID: language, now: now, studyDayStart: dayStart, policy: policy)

        var samples: [Double] = []
        for _ in 0..<20 {
            let start = DispatchTime.now().uptimeNanoseconds
            let queue = try await store.queue(
                languageID: language, now: now, studyDayStart: dayStart, policy: policy
            )
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            #expect(queue.count == 50)
        }
        samples.sort()
        let median = samples[samples.count / 2]

        // 실측 수치를 남긴다 — 벤치는 통과 여부보다 값이 정보다.
        print("""
            [due-queue-benchmark] \(rows) 행 / \(languages) 트랙, 50장 조회 (20회)
              중앙값 \(String(format: "%.3f", median))ms \
            최소 \(String(format: "%.3f", samples[0]))ms \
            최대 \(String(format: "%.3f", samples[samples.count - 1]))ms
              플랜: \(plan.joined(separator: " | "))
            """)
        #expect(median < 50, "22.8만 행 due 큐가 \(median)ms — 5ms 목표의 10배를 넘었다면 인덱스가 죽은 것이다")
    }

    // MARK: - 헬퍼

    private func bucketCounts(_ queue: [DueQueueEntry]) -> [DueQueueBucket: Int] {
        Dictionary(queue.map { ($0.bucket, 1) }, uniquingKeysWith: +)
    }

    /// `EXPLAIN QUERY PLAN` 한 줄이 통째로 훑는 관계 이름. 훑지 않으면 `nil`.
    private func scannedRelation(in detail: String) -> String? {
        // 줄머리의 트리 글리프(`|--`, `` `-- ``)와 공백을 걷어낸다.
        let body = detail.drop { "|`- ".contains($0) }
        guard body.hasPrefix("SCAN ") else { return nil }
        return body.dropFirst("SCAN ".count).split(separator: " ").first.map(String.init)
    }

    private func queueReview(
        card: String,
        stateBefore: CardPhase,
        at instant: EpochMillis,
        source: ReviewLogSource = .review
    ) -> ReviewLogEntry {
        ReviewLogEntry(
            cardID: CardID(card),
            reviewedAt: instant,
            rating: .good,
            stateBefore: stateBefore,
            elapsedDays: 1,
            scheduledDays: 1,
            reviewDurationMS: 3_000,
            source: source
        )
    }

    /// 카드 id 규약 — `done` CTE 가 `review_log` 를 `card_state` 로 조인하므로
    /// 로그가 가리키는 카드가 같은 트랙에 실제로 있어야 한다.
    private func newCardID(_ language: LanguageID, _ index: Int) -> String {
        "\(language.rawValue)-new-\(String(format: "%03d", index))"
    }

    private func reviewCardID(_ language: LanguageID, _ index: Int) -> String {
        "\(language.rawValue)-review-\(String(format: "%03d", index))"
    }

    /// 한 트랙의 카드 셋.
    ///
    /// `dueSpread` 가 `false` 면 전부 첫날에 due 라 **일일 상한이 유일한 제한**이 된다.
    /// `true` 면 하루씩 밀어 due 판정 자체를 시험한다.
    private func trackSnapshots(
        language: LanguageID = .python,
        reviews: Int,
        news: Int,
        learning: Int,
        dueSpread: Bool = false
    ) -> [CardStateSnapshot] {
        func snapshot(_ id: String, _ phase: CardPhase, _ dueDay: Int) -> CardStateSnapshot {
            CardStateSnapshot(
                cardID: CardID(id),
                languageID: language,
                stability: 3.5,
                difficulty: 5.25,
                dueAt: Fixture.days(dueDay),
                lastReviewedAt: Fixture.epoch,
                phase: phase,
                reps: 2,
                lapses: 0,
                elapsedDays: 1,
                scheduledDays: 1,
                learningStepIndex: phase == .learning ? 1 : 0,
                derivedFromLogID: nil,
                parameterSetID: .fsrs6Default,
                rebuiltAt: Fixture.epoch
            )
        }
        return (0..<learning).map { snapshot("\(language.rawValue)-learn-\($0)", .learning, 1) }
            + (0..<reviews).map { snapshot(reviewCardID(language, $0), .review, dueSpread ? $0 + 1 : 1) }
            + (0..<news).map { snapshot(newCardID(language, $0), .new, 1) }
    }

    private func seedTracks(_ database: LearnDatabase, _ tracks: [[CardStateSnapshot]]) async throws {
        try await database.cardStateStore.replaceAll(with: tracks.flatMap { $0 })
    }

    /// 22.8만 행 픽스처. 행마다 Swift 객체를 만들면 벤치 준비가 벤치보다 오래 걸리므로
    /// 재귀 CTE 로 DB 안에서 만든다. 여전히 **코드**이고, 스키마가 바뀌면 컴파일이 아니라
    /// SQL 이 곧바로 실패해 픽스처가 썩은 채 통과하지 않는다.
    private func seedBenchmarkFixture(
        _ database: LearnDatabase,
        cards: Int,
        languages: Int,
        logs: Int
    ) throws {
        try database.executeRaw("""
            INSERT INTO card_state
                (card_id, language_id, stability, difficulty, due_at, last_reviewed_at, state,
                 reps, lapses, elapsed_days, scheduled_days, learning_step_index,
                 derived_from_log_id, parameter_set_id, rebuilt_at)
            WITH RECURSIVE seq(n) AS (
                SELECT 0 UNION ALL SELECT n + 1 FROM seq WHERE n + 1 < \(cards)
            )
            SELECT
                printf('card-%07d', n),
                'lang-' || (n % \(languages)),
                3.5, 5.25,
                1000000 + (n % 5000) * 60000,
                1000,
                -- 7 과 트랙 수가 서로소라 단계가 트랙마다 고르게 섞인다.
                CASE n % 7
                    WHEN 0 THEN 'new' WHEN 1 THEN 'new'
                    WHEN 2 THEN 'learning' WHEN 3 THEN 'relearning'
                    ELSE 'review'
                END,
                2, 0, 1, 1, 0, NULL, 'fsrs6-default', 1
            FROM seq
            """)
        try database.executeRaw("""
            INSERT INTO review_log
                (card_id, reviewed_at, rating, state_before, elapsed_days, scheduled_days,
                 review_duration_ms, scheduler_id, parameter_set_id, source)
            WITH RECURSIVE seq(n) AS (
                SELECT 0 UNION ALL SELECT n + 1 FROM seq WHERE n + 1 < \(logs)
            )
            SELECT
                printf('card-%07d', (n * 3) % \(cards)),
                1000 + n * 1000, 3,
                CASE n % 3 WHEN 0 THEN 'new' ELSE 'review' END,
                1, 1, 4200, 'fsrs6', 'fsrs6-default', 'scheduled'
            FROM seq
            """)
        // 플래너가 인덱스 선택을 통계로 하도록 — 실사용 DB 도 같은 상태다.
        try database.executeRaw("ANALYZE")
    }
}
