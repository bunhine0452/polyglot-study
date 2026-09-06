import Testing
import LearnCore
import LearnScheduling
import LearnPersistence
@testable import ReviewFeature

/// `ReviewModel` 을 진짜 FSRS-6 스케줄러 + 진짜(인메모리) `LearnPersistence` 스토어로
/// 검증한다. **목 데이터가 없다** — 스토어는 `LearnDatabase.inMemory()` 가 여는 실제 GRDB
/// 인메모리 DB 이고, 스케줄러는 실제 `FSRSReviewScheduler` 다.
@Suite("ReviewModel · 실 스케줄러 + 실 스토어")
struct ReviewModelTests {
    private func makeModel(
        languageIDs: [LanguageID] = [.swift],
        scheduler: FSRSReviewScheduler,
        database: LearnDatabase,
        contents: [CardID: ReviewCardContent] = [ReviewFixtures.swiftCard: ReviewFixtures.swiftContent]
    ) -> ReviewModel {
        ReviewModel(
            languageIDs: languageIDs,
            policy: ReviewFixtures.generousPolicy,
            scheduler: scheduler,
            cardStateStore: database.cardStateStore,
            reviewLogStore: database.reviewLogStore,
            contentProvider: StaticReviewCardContentProvider(contents: contents)
        )
    }

    @Test("오늘 큐를 불러오면 시드한 카드가 실제 콘텐츠와 함께 나온다")
    func loadPopulatesQueueWithRealContent() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()

        #expect(model.errorMessage == nil)
        #expect(model.totalCount == 1)
        #expect(model.currentCard?.id == ReviewFixtures.swiftCard)
        #expect(model.currentCard?.content == ReviewFixtures.swiftContent)
    }

    @Test("버튼 미리보기가 scheduler.preview(_:at:) 실제 계산값과 정확히 같다")
    func previewMatchesRealSchedulerCalculation() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        let snapshot = try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()

        let expected = try scheduler.preview(snapshot.scheduling, at: ReviewFixtures.noon)
        #expect(model.preview == expected)

        let specs = model.ratingSpecs
        #expect(specs.map(\.intervalLabel) == expected.ordered.map(\.shortDescription))
    }

    @Test("채점해도 카드가 큐에서 사라지지 않는다 — 다음 카드로 넘어갈 뿐이다")
    func choosingNeverRemovesTheCard() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.pythonCard, language: .python,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = makeModel(
            languageIDs: [.swift, .python],
            scheduler: scheduler,
            database: database,
            contents: [
                ReviewFixtures.swiftCard: ReviewFixtures.swiftContent,
                ReviewFixtures.pythonCard: ReviewFixtures.swiftContent,
            ]
        )
        await model.load()
        #expect(model.totalCount == 2)

        let firstCardID = model.currentCard?.id
        let ok = await model.choose(.good)

        #expect(ok)
        #expect(model.errorMessage == nil)
        // 큐 길이는 그대로다 — 카드를 지우지 않는다.
        #expect(model.queue.count == 2)
        #expect(model.queue.contains { $0.id == firstCardID })
        // 다음 카드로만 넘어간다.
        #expect(model.currentIndex == 1)
        #expect(model.completedCount == 1)
        #expect(!model.isFinished)
    }

    @Test("채점 결과가 실제로 저장된다 — card_state 갱신 + review_log append")
    func choosingPersistsToRealStores() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()
        #expect(try await database.reviewLogStore.count() == 0)

        _ = await model.choose(.easy)

        #expect(try await database.reviewLogStore.count() == 1)
        let stored = try await database.cardStateStore.snapshot(forCard: ReviewFixtures.swiftCard)
        #expect(stored?.reps == 1)
        #expect(stored?.phase != .new)

        let history = try await database.reviewLogStore.entries(forCard: ReviewFixtures.swiftCard)
        #expect(history.count == 1)
        #expect(history[0].rating == .easy)
        #expect(history[0].source == .review)
    }

    @Test("모든 카드를 다 채점하면 끝났다는 상태가 된다")
    func finishesAfterAllCardsRated() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = makeModel(scheduler: scheduler, database: database)
        await model.load()
        #expect(!model.isFinished)

        _ = await model.choose(.good)

        #expect(model.isFinished)
        #expect(model.currentCard == nil)
        #expect(model.queue.count == 1, "끝났어도 카드가 배열에서 사라지지 않는다")
    }

    @Test("여러 트랙의 큐를 합쳐서 due 순으로 보여준다")
    func mergesMultipleTracksInDueOrder() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        // python 카드를 더 이르게 생성해 먼저 due 하게 만든다.
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.pythonCard, language: .python,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon.adding(minutes: -30)
        )
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = makeModel(
            languageIDs: [.swift, .python],
            scheduler: scheduler,
            database: database,
            contents: [
                ReviewFixtures.swiftCard: ReviewFixtures.swiftContent,
                ReviewFixtures.pythonCard: ReviewFixtures.swiftContent,
            ]
        )
        await model.load()

        #expect(model.totalCount == 2)
        #expect(model.currentCard?.id == ReviewFixtures.pythonCard, "더 일찍 due 한 카드가 먼저 나와야 한다")
    }

    @Test("빈 큐면 로딩 후 카드가 없다는 상태가 된다")
    func emptyQueueYieldsNoCurrentCard() async throws {
        let (scheduler, database) = try await ReviewFixtures.makeEnvironment()
        let model = makeModel(scheduler: scheduler, database: database, contents: [:])

        await model.load()

        #expect(model.totalCount == 0)
        #expect(model.currentCard == nil)
        #expect(!model.isFinished, "한 번도 카드가 없었던 것과 '다 풀었다' 는 다른 상태다")
        #expect(model.errorMessage == nil)
    }
}
