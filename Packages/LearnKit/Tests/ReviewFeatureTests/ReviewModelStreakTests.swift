import Testing
import LearnCore
import LearnScheduling
import LearnPersistence
@testable import ReviewFeature

/// 연속 복습 일수 — `review_log` 를 실제로 세어 계산한다. `{#screen-review}` 헤더의
/// "연속 복습 N일째" 값이 이 계산에서 나온다.
@Suite("ReviewModel · 연속 복습 일수")
struct ReviewModelStreakTests {
    /// 로그 한 건을 직접 심는다. `.fsrs6Default` 파라미터 세트는 마이그레이션 001 이
    /// 이미 활성으로 심어 둔 것이라 외래키가 곧바로 만족된다 — `ReviewModel.load()` 를
    /// 거치지 않고 로그만 쌓을 때는 이 경로가 가장 단순하다.
    private func seedReview(at instant: EpochMillis, cardID: CardID, in store: any ReviewLogStore) async throws {
        try await store.append(ReviewLogEntry(
            cardID: cardID,
            reviewedAt: instant,
            rating: .good,
            stateBefore: .review
        ))
    }

    private func makeModel(scheduler: FSRSReviewScheduler, database: LearnDatabase) -> ReviewModel {
        ReviewModel(
            languageIDs: [.swift],
            policy: ReviewFixtures.generousPolicy,
            scheduler: scheduler,
            cardStateStore: database.cardStateStore,
            reviewLogStore: database.reviewLogStore,
            contentProvider: StaticReviewCardContentProvider()
        )
    }

    @Test("어제까지 3일 연속이고 오늘은 아직 안 했으면 연속 3일이 유지된다")
    func todayNotYetDoneKeepsStreak() async throws {
        let scheduler = try ReviewFixtures.scheduler()
        let database = try ReviewFixtures.database()
        for offset in [-3, -2, -1] {
            try await seedReview(at: ReviewFixtures.day(offset), cardID: ReviewFixtures.swiftCard, in: database.reviewLogStore)
        }

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()

        #expect(model.streakDays == 3)
    }

    @Test("오늘도 이미 복습했으면 오늘까지 포함해서 센다")
    func todayAlreadyDoneCountsToday() async throws {
        let scheduler = try ReviewFixtures.scheduler()
        let database = try ReviewFixtures.database()
        for offset in [-1, 0] {
            try await seedReview(at: ReviewFixtures.day(offset), cardID: ReviewFixtures.swiftCard, in: database.reviewLogStore)
        }

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()

        #expect(model.streakDays == 2)
    }

    @Test("하루라도 빠지면 그 앞은 세지 않는다")
    func gapBreaksTheStreak() async throws {
        let scheduler = try ReviewFixtures.scheduler()
        let database = try ReviewFixtures.database()
        // -1일은 비우고 -2, -3일만 채운다 — 어제가 빠졌으므로 연속은 0이어야 한다.
        for offset in [-3, -2] {
            try await seedReview(at: ReviewFixtures.day(offset), cardID: ReviewFixtures.swiftCard, in: database.reviewLogStore)
        }

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()

        #expect(model.streakDays == 0)
    }

    @Test("로그가 하나도 없으면 연속 0일이다")
    func noHistoryMeansZero() async throws {
        let scheduler = try ReviewFixtures.scheduler()
        let database = try ReviewFixtures.database()

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()

        #expect(model.streakDays == 0)
    }

    @Test("채점을 하면 연속일수가 다시 계산된다 — 오늘 몫이 즉시 반영된다")
    func choosingRecomputesStreakForToday() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        try await seedReview(at: ReviewFixtures.day(-1), cardID: ReviewFixtures.pythonCard, in: database.reviewLogStore)
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()
        #expect(model.streakDays == 1, "어제만 있고 오늘은 아직 — 연속 1일 유지")

        _ = await model.choose(.good)

        #expect(model.streakDays == 2, "오늘 채점이 로그에 실제로 반영돼 연속 2일이 된다")
    }
}
