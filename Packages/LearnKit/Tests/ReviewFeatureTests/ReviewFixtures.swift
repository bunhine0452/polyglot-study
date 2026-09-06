import Foundation
import LearnCore
import LearnScheduling
import LearnPersistence
@testable import ReviewFeature

/// 테스트 전용 고정 시각·픽스처. `CardStateRebuildRealE2ETests`(LearnPersistenceTests)와
/// 같은 관용구 — 항상 `FixedSchedulerClock` 을 주입하고, 하루 경계는 UTC 로 고정해
/// 실행 머신의 시간대에 결과가 흔들리지 않게 한다.
enum ReviewFixtures {
    /// 2026-01-01T12:00:00Z. 정오로 잡아 04:00 UTC 롤오버 경계에서 충분히 떨어뜨린다.
    static let noon = EpochMillis(1_767_225_600_000).adding(seconds: 12 * 3_600)
    static func day(_ offset: Int) -> EpochMillis { noon.adding(days: offset) }

    static let dayBoundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "UTC")

    /// 실 FSRS-6 스케줄러. 매 호출이 새 인스턴스를 만들므로 테스트끼리 상태를 공유하지 않는다.
    static func scheduler(now: EpochMillis = noon) throws -> FSRSReviewScheduler {
        try FSRSReviewScheduler(dayBoundary: dayBoundary, clock: FixedSchedulerClock(now))
    }

    /// 인메모리 `LearnDatabase`. 파일도, 목 스토어도 아니다 — 진짜 GRDB·진짜 스키마다.
    static func database() throws -> LearnDatabase { try LearnDatabase.inMemory() }

    /// `card_state.parameter_set_id` 와 `review_log.parameter_set_id` 는 둘 다
    /// `scheduler_parameters(id)` 를 참조하는 외래키다(`ON DELETE RESTRICT`). 새로 연
    /// `LearnDatabase` 는 마이그레이션 001 이 심은 자리표시 세트(`"fsrs6-default"` 문자열
    /// 그대로)만 갖고 있는데, 실제 `FSRSReviewScheduler` 의 id 는 파라미터 내용에서 유도한
    /// 해시라 그 문자열과 다르다. 그래서 **실 스케줄러로 카드를 하나라도 만들기 전에**
    /// 그 세트를 등록·활성화해야 한다 — `CardStateRebuildRealE2ETests`(LearnPersistenceTests)
    /// 가 쓰는 것과 같은 관용구다. `ReviewModel.load()` 는 자기 자신의 쓰기 경로
    /// (`choose()`)를 위해 이 등록을 스스로 하지만, 테스트가 `ReviewModel` 을 통하지 않고
    /// 직접 `cardStateStore.upsert(...)` 로 카드를 시드할 때는 그 자동 등록보다 먼저
    /// 일어나므로 여기서 미리 해 둬야 한다.
    static func activateSchedulerParameterSet(
        _ scheduler: FSRSReviewScheduler,
        in database: LearnDatabase
    ) async throws {
        try await database.reviewLogStore.save(
            parameterSet: SchedulerParameterSet(
                id: scheduler.parameterSetID,
                schedulerID: scheduler.schedulerID,
                weights: nil,
                createdAt: scheduler.clock.now(),
                isActive: true
            ),
            activate: true
        )
    }

    /// 스케줄러 + 인메모리 DB 를 만들고, 그 스케줄러의 파라미터 세트를 곧바로 활성화한다.
    /// 카드를 직접 시드하는 테스트는 대부분 이 조합을 쓴다.
    static func makeEnvironment(now: EpochMillis = noon) async throws -> (scheduler: FSRSReviewScheduler, database: LearnDatabase) {
        let scheduler = try scheduler(now: now)
        let database = try database()
        try await activateSchedulerParameterSet(scheduler, in: database)
        return (scheduler, database)
    }

    static let swiftCard = CardID("swift-lesson07-value-vs-reference")
    static let pythonCard = CardID("python-lesson03-mutability")

    static let swiftContent = ReviewCardContent(
        contextLabel: "Swift · 레슨 07 값 타입과 참조 타입",
        question: "let 으로 선언한 struct 인스턴스의 저장 속성을 바꿀 수 있습니까?",
        answer: "struct 는 바꿀 수 없습니다 — 값 타입은 let 으로 인스턴스 전체가 불변이 됩니다.",
        codeExample: "let p = Point(x: 1)\np.x = 2 // 컴파일 오류"
    )

    /// 여유 있는 정책 — 신규 카드 상한 때문에 테스트 카드가 큐에서 빠지지 않도록.
    static let generousPolicy = DueQueuePolicy(dailyLimit: 100, newShare: 1.0, sessionLimit: 100)

    /// 신규 카드 하나를 시드하고 스냅샷을 돌려준다.
    @discardableResult
    static func seedNewCard(
        _ cardID: CardID,
        language: LanguageID,
        scheduler: FSRSReviewScheduler,
        in store: any CardStateStore,
        createdAt: EpochMillis
    ) async throws -> CardStateSnapshot {
        let scheduling = scheduler.initialState(for: cardID, createdAt: createdAt)
        let snapshot = CardStateSnapshot(scheduling: scheduling, languageID: language, rebuiltAt: createdAt)
        try await store.upsert(snapshot)
        return snapshot
    }
}
