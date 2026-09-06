import Foundation
import Testing

import LearnCore
@testable import LearnScheduling

/// `DayBoundary` 배선. `{#queue-mixing}`
///
/// 저장 계층은 학습일 시작을 **정수로 받기만** 한다 — 롤오버를 아는 계층은 여기다.
/// 그 한 줄을 호출부마다 손으로 넣으면 언젠가 한 군데를 빼먹고, 그 순간 일일 상한이
/// 세션 상한으로 조용히 강등된다. 이 스위트는 배선이 실제로 그 값을 넣는지,
/// 그리고 넣은 값이 롤오버 정책과 일치하는지를 본다.
@Suite("DayBoundary 큐 배선")
struct DueQueueWiringTests {

    /// 2026-01-05 09:00:00 UTC.
    private static let base = EpochMillis(1_767_603_600_000)

    private func instant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> EpochMillis {
        EpochMillis(Int64((utcDate(year, month, day, hour, minute).timeIntervalSince1970 * 1_000).rounded()))
    }

    private func scheduler(_ dayBoundary: DayBoundary, now: EpochMillis) throws -> FSRSReviewScheduler {
        try FSRSReviewScheduler(dayBoundary: dayBoundary, clock: FixedSchedulerClock(now))
    }

    // MARK: - 배선이 값을 넣는가

    @Test("dayBoundary 를 받는 큐가 startOfStudyDay 를 저장 계층에 넣는다")
    func dayBoundaryOverloadSuppliesStudyDayStart() async throws {
        let boundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "Asia/Seoul")
        let spy = QueueSpyCardStateStore()
        let now = instant(2026, 1, 5, 20)

        _ = try await spy.queue(languageID: .python, now: now, dayBoundary: boundary)

        let call = try #require(await spy.lastCall)
        #expect(call.now == now)
        #expect(call.studyDayStart == boundary.startOfStudyDay(containing: now))
        #expect(call.languageID == .python)
        #expect(call.policy == .default)
    }

    @Test("스케줄러를 받는 큐가 스케줄러의 롤오버 정책과 클록을 쓴다")
    func schedulerOverloadUsesSchedulerBoundaryAndClock() async throws {
        let boundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "Asia/Seoul")
        let now = instant(2026, 1, 5, 20)
        let scheduler = try scheduler(boundary, now: now)
        let spy = QueueSpyCardStateStore()
        let policy = DueQueuePolicy(dailyLimit: 30, newShare: 0.5, sessionLimit: 12)

        _ = try await spy.queue(languageID: .sql, using: scheduler, policy: policy)

        let call = try #require(await spy.lastCall)
        #expect(call.now == now, "클록의 지금을 쓰지 않았다")
        #expect(call.studyDayStart == boundary.startOfStudyDay(containing: now))
        #expect(call.languageID == .sql)
        #expect(call.policy == policy)
    }

    @Test("명시한 시각이 클록보다 우선한다")
    func explicitInstantWinsOverClock() async throws {
        let boundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "Asia/Seoul")
        let scheduler = try scheduler(boundary, now: Self.base)
        let spy = QueueSpyCardStateStore()
        let later = instant(2026, 3, 1, 12)

        _ = try await spy.queue(languageID: .swift, using: scheduler, at: later)

        let call = try #require(await spy.lastCall)
        #expect(call.now == later)
        #expect(call.studyDayStart == boundary.startOfStudyDay(containing: later))
    }

    @Test("스케줄러가 같은 경계를 큐 밖에서도 답한다")
    func schedulerExposesStartOfStudyDay() throws {
        let boundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "Asia/Seoul")
        let now = instant(2026, 1, 5, 20)
        let scheduler = try scheduler(boundary, now: now)

        #expect(scheduler.startOfStudyDay() == boundary.startOfStudyDay(containing: now))
        let other = instant(2026, 2, 9, 1)
        #expect(scheduler.startOfStudyDay(containing: other) == boundary.startOfStudyDay(containing: other))
    }

    // MARK: - 넣은 값이 롤오버 정책과 맞는가

    /// 롤오버 이전(새벽)의 리뷰는 **어제** 몫이다. 배선이 그냥 자정을 넣으면 여기가 깨진다.
    @Test("롤오버 이전 시각은 전날 04:00 을 학습일 시작으로 준다")
    func beforeRolloverBelongsToYesterday() throws {
        let boundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "Asia/Seoul")

        // 2026-01-06 02:00 KST = 2026-01-05 17:00 UTC → 학습일 시작은 2026-01-05 04:00 KST.
        let earlyMorning = instant(2026, 1, 5, 17)
        #expect(boundary.startOfStudyDay(containing: earlyMorning) == instant(2026, 1, 4, 19))

        // 2026-01-06 05:00 KST = 2026-01-05 20:00 UTC → 학습일 시작은 2026-01-06 04:00 KST.
        let afterRollover = instant(2026, 1, 5, 20)
        #expect(boundary.startOfStudyDay(containing: afterRollover) == instant(2026, 1, 5, 19))
    }

    /// 배선이 실제로 일일 상한을 학습일 단위로 만드는지 — 페이크 큐로 끝까지 돌려 본다.
    @Test("같은 학습일에 이미 푼 몫이 큐에서 빠진다")
    func todaysAllowanceIsSpentWithinTheStudyDay() async throws {
        let boundary = DayBoundary(rolloverHour: 4, timeZoneIdentifier: "Asia/Seoul")
        // 2026-01-06 05:00 KST — 학습일이 막 시작한 직후.
        let now = instant(2026, 1, 5, 20)
        let scheduler = try scheduler(boundary, now: now)

        let log = InMemoryReviewLogStore(parameterSets: [
            SchedulerParameterSet(
                id: scheduler.parameterSetID,
                schedulerID: scheduler.schedulerID,
                createdAt: Self.base,
                isActive: true
            )
        ])
        let cards = InMemoryCardStateStore(reviewLog: log)

        var snapshots: [CardStateSnapshot] = []
        for index in 0..<10 {
            snapshots.append(
                CardStateSnapshot(
                    cardID: CardID(String(format: "py-review-%02d", index)),
                    languageID: .python,
                    stability: 10,
                    difficulty: 5,
                    dueAt: now.adding(minutes: -60),
                    lastReviewedAt: now.adding(days: -3),
                    phase: .review,
                    reps: 3,
                    lapses: 0,
                    elapsedDays: 3,
                    scheduledDays: 3,
                    learningStepIndex: 0,
                    derivedFromLogID: nil,
                    parameterSetID: scheduler.parameterSetID,
                    rebuiltAt: Self.base
                )
            )
        }
        try await cards.replaceAll(with: snapshots)

        let policy = DueQueuePolicy(dailyLimit: 4, newShare: 0, sessionLimit: 50)
        let first = try await cards.queue(languageID: .python, using: scheduler, policy: policy)
        #expect(first.count == 4, "복습 몫 4장이 나와야 한다")

        // 어제(롤오버 직전)에 푼 리뷰는 오늘 몫을 갉아먹지 않는다.
        try await log.append(
            ReviewLogEntry(
                cardID: CardID("py-review-00"),
                reviewedAt: instant(2026, 1, 5, 18),
                rating: .good,
                stateBefore: .review,
                parameterSetID: scheduler.parameterSetID,
                source: .review
            )
        )
        #expect(
            try await cards.queue(languageID: .python, using: scheduler, policy: policy).count == 4,
            "롤오버 이전 리뷰가 오늘 몫을 먹었다 — 학습일 경계가 배선되지 않았다"
        )

        // 오늘(롤오버 이후) 푼 두 장은 오늘 몫에서 빠진다.
        for index in 1...2 {
            try await log.append(
                ReviewLogEntry(
                    cardID: CardID(String(format: "py-review-%02d", index)),
                    reviewedAt: now.adding(minutes: -30),
                    rating: .good,
                    stateBefore: .review,
                    parameterSetID: scheduler.parameterSetID,
                    source: .review
                )
            )
        }
        #expect(try await cards.queue(languageID: .python, using: scheduler, policy: policy).count == 2)
    }
}

// MARK: - 테스트 더블

/// 저장 계층이 실제로 무엇을 받았는지만 기록하는 캐시.
private actor QueueSpyCardStateStore: CardStateStore {
    struct Call: Sendable {
        var languageID: LanguageID
        var now: EpochMillis
        var studyDayStart: EpochMillis
        var policy: DueQueuePolicy
    }

    private(set) var lastCall: Call?

    func queue(
        languageID: LanguageID,
        now: EpochMillis,
        studyDayStart: EpochMillis,
        policy: DueQueuePolicy
    ) async throws -> [DueQueueEntry] {
        lastCall = Call(
            languageID: languageID,
            now: now,
            studyDayStart: studyDayStart,
            policy: policy
        )
        return []
    }

    func snapshot(forCard cardID: CardID) async throws -> CardStateSnapshot? { nil }
    func upsert(_ snapshot: CardStateSnapshot) async throws {}
    func count() async throws -> Int { 0 }
    func replaceAll(with snapshots: [CardStateSnapshot]) async throws {}
    func deleteAll() async throws {}

    func dueCards(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis,
        limit: Int
    ) async throws -> [CardStateSnapshot] { [] }

    func staleCards(limit: Int) async throws -> [CardStaleness] { [] }
    func staleCount() async throws -> Int { 0 }

    nonisolated func observeDueCount(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis
    ) -> AsyncThrowingStream<Int, any Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
