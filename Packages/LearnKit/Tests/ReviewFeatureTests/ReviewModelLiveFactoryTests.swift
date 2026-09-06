import Testing
import LearnCore
import LearnScheduling
import LearnPersistence
@testable import ReviewFeature

/// `ReviewModel.live(database:)` — 앱이 실제로 쓰는 조립 경로. `{#screen-review}`
///
/// 이 스위트가 지키는 것: 새로 연 `LearnDatabase` 의 활성 파라미터 세트(마이그레이션 001이
/// 심은 `"fsrs6-default"` 문자열)와 실제 `FSRSReviewScheduler.parameterSetID`(파라미터
/// 내용에서 유도한 해시)는 **다른 문자열**이다. 이 배선을 놓치면 `review_log` 의
/// `parameter_set_id` 외래키가 첫 채점에서 곧바로 실패한다 — `ReviewModel` 이 `load()` 에서
/// 이 세트를 등록·활성화해 두므로 여기서는 실패하지 않는다는 것을 실제로 확인한다.
@Suite("ReviewModel.live · 실물 조립")
struct ReviewModelLiveFactoryTests {
    @Test("스케줄러 파라미터 세트 id 는 마이그레이션 기본 시드와 다르다 — 이 테스트가 없으면 아래 시나리오가 왜 필요한지 알 수 없다")
    func schedulerIDDiffersFromMigrationSeed() throws {
        let scheduler = try FSRSReviewScheduler()
        #expect(scheduler.parameterSetID != .fsrs6Default)
    }

    @Test(".live 로 만든 모델이 실제로 로드되고 채점까지 끝까지 간다 — 외래키 위반 없이")
    func liveModelLoadsAndScoresWithoutForeignKeyFailure() async throws {
        let database = try LearnDatabase.inMemory()
        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(ReviewFixtures.noon))
        // `.live` 는 자체적으로 스케줄러를 만들지만, 이 테스트는 시드에 쓸 스케줄러가
        // 필요해서 하나 더 만든다 — 둘 다 같은 기본 파라미터라 `parameterSetID` 는 같다.
        // 카드를 시드하기 전에 그 세트를 미리 등록해 둔다 — `ReviewFixtures.swift` 의
        // `activateSchedulerParameterSet` 주석 참고. `.live` 가 만드는 모델도 `load()` 에서
        // 같은 등록을 시도하지만, 카드 시드는 그보다 먼저 일어난다.
        try await ReviewFixtures.activateSchedulerParameterSet(scheduler, in: database)
        try await ReviewFixtures.seedNewCard(
            ReviewFixtures.swiftCard, language: .swift,
            scheduler: scheduler, in: database.cardStateStore, createdAt: ReviewFixtures.noon
        )

        let model = try ReviewModel.live(
            database: database,
            languageIDs: [.swift],
            policy: ReviewFixtures.generousPolicy,
            contentProvider: StaticReviewCardContentProvider(
                contents: [ReviewFixtures.swiftCard: ReviewFixtures.swiftContent]
            )
        )
        await model.load()

        #expect(model.errorMessage == nil)
        #expect(model.totalCount == 1)

        let ok = await model.choose(.good)

        #expect(ok, "외래키 위반이면 여기서 false 가 나오고 errorMessage 가 채워진다")
        #expect(model.errorMessage == nil)
        #expect(try await database.reviewLogStore.count() == 1)
    }

    @Test("활성 파라미터 세트가 스케줄러 것으로 바뀐다")
    func loadActivatesSchedulersParameterSet() async throws {
        let database = try LearnDatabase.inMemory()
        let before = try await database.reviewLogStore.activeParameterSet()
        #expect(before.id == .fsrs6Default, "마이그레이션 001 이 심은 자리표시 세트가 처음엔 활성이다")

        let model = try ReviewModel.live(database: database, languageIDs: [.swift])
        await model.load()

        let after = try await database.reviewLogStore.activeParameterSet()
        #expect(after.id != .fsrs6Default)
        #expect(after.id == (try FSRSReviewScheduler()).parameterSetID)
    }
}
