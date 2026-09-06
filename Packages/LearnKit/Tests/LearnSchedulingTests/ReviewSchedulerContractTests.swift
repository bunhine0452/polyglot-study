import Foundation
import Testing

import LearnCore
@testable import LearnScheduling

/// `ReviewScheduler` 계약. `{#scheduler-protocol}` `{#scheduler-preview}` `{#scheduler-clock}`
@Suite("ReviewScheduler 계약")
struct ReviewSchedulerContractTests {

    /// 2026-01-05 09:00:00 UTC.
    static let base = EpochMillis(1_767_603_600_000)

    private func makeScheduler(
        at instant: EpochMillis = ReviewSchedulerContractTests.base,
        rolloverHour: Int = DayBoundary.defaultRolloverHour,
        timeZone: String = "Asia/Seoul"
    ) throws -> FSRSReviewScheduler {
        try FSRSReviewScheduler(
            dayBoundary: DayBoundary(rolloverHour: rolloverHour, timeZoneIdentifier: timeZone),
            clock: FixedSchedulerClock(instant)
        )
    }

    // MARK: - preview

    @Test("preview 가 4개 rating 을 한 번에, 한 시각으로 낸다")
    func previewReturnsAllFourRatings() throws {
        let scheduler = try makeScheduler()
        let card = scheduler.initialState(for: CardID("py-001"), createdAt: Self.base)
        let preview = try scheduler.preview(card)

        #expect(preview.cardID == CardID("py-001"))
        #expect(preview.evaluatedAt == Self.base)
        #expect(preview.ordered.map(\.rating) == [.again, .hard, .good, .easy])
        for schedule in preview.ordered {
            #expect(preview[schedule.rating] == schedule)
        }

        // 새 카드 + 기본 스텝(1m/10m)에서의 실제 라벨. FSRS-6 기본 파라미터가 낳는 값이다.
        #expect(
            preview.ordered.map(\.shortDescription) == ["1분", "6분", "10분", "8일"],
            "복습 버튼 라벨: \(preview.ordered.map(\.shortDescription))"
        )
        #expect(preview.again.intervalMinutes == 1)
        #expect(preview.hard.intervalMinutes == 6)
        #expect(preview.good.intervalMinutes == 10)
        #expect(preview.easy.intervalMinutes == 8 * 1_440)
    }

    @Test("preview 는 단조 증가한다 — again ≤ hard ≤ good ≤ easy")
    func previewIntervalsAreMonotonic() throws {
        let scheduler = try makeScheduler()
        var card = scheduler.initialState(for: CardID("sql-007"), createdAt: Self.base)
        var now = Self.base

        for _ in 0..<6 {
            let preview = try scheduler.preview(card, at: now)
            let minutes = preview.ordered.map(\.intervalMinutes)
            #expect(
                minutes == minutes.sorted(),
                "rating 이 좋을수록 간격이 길어야 한다 — \(minutes) (phase: \(card.phase))"
            )
            card = try scheduler.apply(.good, to: card, at: now, reviewDurationMS: 4_200, source: .review).state
            now = card.dueAt
        }
    }

    @Test("preview 와 apply 가 같은 시각에서 같은 결과를 낸다")
    func previewAgreesWithApply() throws {
        let scheduler = try makeScheduler()
        var card = scheduler.initialState(for: CardID("swift-003"), createdAt: Self.base)
        var now = Self.base

        for step in 0..<8 {
            let preview = try scheduler.preview(card, at: now)
            for rating in ReviewRating.allCases {
                let applied = try scheduler.apply(rating, to: card, at: now, reviewDurationMS: nil, source: .review)
                #expect(
                    applied.state == preview[rating].state,
                    "step \(step), rating \(rating): preview 와 apply 가 다르다"
                )
            }
            let rating: ReviewRating = step == 3 ? .again : .good
            card = try scheduler.apply(rating, to: card, at: now, reviewDurationMS: nil, source: .review).state
            now = card.dueAt
        }
    }

    // MARK: - 클록 주입

    @Test("시각은 주입 클록에서만 온다")
    func clockIsInjected() throws {
        let instant = EpochMillis(1_800_000_000_000)
        let scheduler = try makeScheduler(at: instant)
        let card = scheduler.initialState(for: CardID("c"), createdAt: instant)

        #expect(scheduler.clock.now() == instant)
        #expect(try scheduler.preview(card).evaluatedAt == instant)
        #expect(try scheduler.apply(.good, to: card).logEntry.reviewedAt == instant)
    }

    @Test("모든 시각이 epoch ms UTC 로 왕복한다")
    func timestampsRoundTripAsEpochMilliseconds() throws {
        let scheduler = try makeScheduler()
        let card = scheduler.initialState(for: CardID("c"), createdAt: Self.base)
        let outcome = try scheduler.apply(.easy, to: card, at: Self.base, reviewDurationMS: nil, source: .review)

        // 8일 뒤, 밀리초 오차 없이.
        #expect(outcome.state.dueAt == Self.base.adding(days: 8))
        #expect(outcome.state.lastReviewedAt == Self.base)

        // JSON 왕복도 무손실.
        let encoded = try snapshotEncoder.encode(outcome)
        let decoded = try JSONDecoder().decode(ReviewOutcome.self, from: encoded)
        #expect(decoded == outcome)
    }

    // MARK: - 롤오버

    @Test("하루 경계 기본값은 로컬 04:00 이다")
    func dayBoundaryDefaultsToFourAM() {
        #expect(DayBoundary.defaultRolloverHour == 4)

        let seoul = DayBoundary(timeZoneIdentifier: "Asia/Seoul")
        // 2026-01-06 01:00 KST = 2026-01-05 16:00 UTC → 아직 "1월 5일" 이다.
        let lateNight = EpochMillis(1_767_628_800_000)
        // 2026-01-06 05:00 KST = 2026-01-05 20:00 UTC → 이제 "1월 6일".
        let afterRollover = EpochMillis(1_767_643_200_000)

        #expect(seoul.studyDay(containing: lateNight) + 1 == seoul.studyDay(containing: afterRollover))
        #expect(seoul.isSameStudyDay(lateNight, lateNight.adding(minutes: 30)))
        #expect(!seoul.isSameStudyDay(lateNight, afterRollover))
    }

    @Test("학습일 시작은 그 날 롤오버 시각이다")
    func startOfStudyDayIsRolloverInstant() {
        let seoul = DayBoundary(timeZoneIdentifier: "Asia/Seoul")
        let lateNight = EpochMillis(1_767_628_800_000)  // 2026-01-06 01:00 KST
        let start = seoul.startOfStudyDay(containing: lateNight)

        // 2026-01-05 04:00 KST = 2026-01-04 19:00 UTC.
        #expect(start == EpochMillis(1_767_553_200_000))
        #expect(seoul.isSameStudyDay(start, lateNight))
        #expect(!seoul.isSameStudyDay(start.adding(minutes: -1), lateNight))
    }

    @Test("DST 를 건너도 학습일 서수는 정확히 1씩 움직인다")
    func studyDayOrdinalSurvivesDST() {
        // 미국 동부 2026-03-08 02:00 에 DST 시작(하루가 23시간).
        let newYork = DayBoundary(timeZoneIdentifier: "America/New_York")
        var previous = newYork.studyDay(containing: EpochMillis(1_772_949_600_000))  // 2026-03-06 05:00 EST
        for day in 1...5 {
            let instant = EpochMillis(1_772_949_600_000).adding(days: day)
            let current = newYork.studyDay(containing: instant)
            #expect(current >= previous, "학습일 서수가 뒤로 갔다 — day \(day)")
            previous = current
        }
    }

    @Test("일 단위 카드는 학습일로, 분 단위 학습 카드는 정확한 시각으로 due 판정한다")
    func dueJudgementSplitsOnScheduledDays() throws {
        let boundary = DayBoundary(timeZoneIdentifier: "Asia/Seoul")
        let scheduler = try makeScheduler()

        // 10분짜리 학습 스텝 카드: 하루가 시작됐다고 즉시 뜨면 학습 스텝이 무의미해진다.
        let learning = try scheduler
            .apply(.good, to: scheduler.initialState(for: CardID("l"), createdAt: Self.base), at: Self.base,
                   reviewDurationMS: nil, source: .review).state
        #expect(learning.scheduledDays == 0)
        #expect(!learning.isDue(asOf: Self.base.adding(minutes: 9), dayBoundary: boundary))
        #expect(learning.isDue(asOf: Self.base.adding(minutes: 10), dayBoundary: boundary))

        // 8일짜리 review 카드: 그 날 롤오버가 지나면 시각과 무관하게 뜬다.
        let review = try scheduler
            .apply(.easy, to: scheduler.initialState(for: CardID("r"), createdAt: Self.base), at: Self.base,
                   reviewDurationMS: nil, source: .review).state
        #expect(review.scheduledDays == 8)
        let dueDay = review.dueAt
        #expect(!review.isDue(asOf: dueDay.adding(days: -1), dayBoundary: boundary))
        #expect(review.isDue(asOf: boundary.startOfStudyDay(containing: dueDay), dayBoundary: boundary))
    }

    // MARK: - cram

    @Test("cram 리뷰는 기록만 되고 스케줄을 바꾸지 않는다")
    func cramDoesNotAffectSchedule() throws {
        let scheduler = try makeScheduler()
        let card = try scheduler
            .apply(.easy, to: scheduler.initialState(for: CardID("c"), createdAt: Self.base), at: Self.base,
                   reviewDurationMS: nil, source: .review).state

        let cram = try scheduler.apply(
            .good, to: card, at: Self.base.adding(days: 2), reviewDurationMS: 900, source: .cram
        )
        #expect(cram.state == card, "cram 이 카드 상태를 바꿨다")
        #expect(cram.logEntry.source == .cram)
        #expect(cram.logEntry.affectsSchedule == false)
        #expect(cram.logEntry.elapsedDays == 2)

        // 리플레이도 같은 규칙 — cram 을 끼워 넣어도 최종 상태가 같아야 한다.
        let real = try scheduler.apply(.good, to: card, at: Self.base.adding(days: 8),
                                       reviewDurationMS: nil, source: .review)
        let withoutCram = try scheduler.replay([
            ReviewLogEntry(cardID: CardID("c"), reviewedAt: Self.base, rating: .easy, stateBefore: .new,
                           elapsedDays: 0, scheduledDays: 8, schedulerID: scheduler.schedulerID,
                           parameterSetID: scheduler.parameterSetID, source: .review),
            real.logEntry,
        ])
        let withCram = try scheduler.replay([
            ReviewLogEntry(cardID: CardID("c"), reviewedAt: Self.base, rating: .easy, stateBefore: .new,
                           elapsedDays: 0, scheduledDays: 8, schedulerID: scheduler.schedulerID,
                           parameterSetID: scheduler.parameterSetID, source: .review),
            cram.logEntry,
            real.logEntry,
        ])
        #expect(withCram == withoutCram, "cram 로그가 리플레이 결과를 바꿨다")
    }

    // MARK: - stale 집계

    @Test("파라미터 세트가 바뀐 카드를 stale 로 집계한다")
    func staleCardsAreDetected() throws {
        let scheduler = try makeScheduler()
        let active = scheduler.parameterSetID
        let states = [
            CardSchedulingState.newCard(CardID("c3"), createdAt: Self.base, parameterSetID: "fsrs6-oldhash"),
            CardSchedulingState.newCard(CardID("c1"), createdAt: Self.base, parameterSetID: active),
            CardSchedulingState.newCard(CardID("c2"), createdAt: Self.base, parameterSetID: "fsrs6-oldhash"),
        ]
        #expect(scheduler.staleCards(in: states) == [CardID("c2"), CardID("c3")])
        #expect(states[1].isStale(activeParameterSetID: active) == false)
    }

    // MARK: - 오류 경로

    @Test("빈 로그와 섞인 카드는 명확한 오류로 실패한다")
    func replayRejectsBadInput() throws {
        let scheduler = try makeScheduler()
        #expect(throws: ReviewSchedulingError.emptyLog) { _ = try scheduler.replay([]) }

        func entry(_ cardID: String, _ at: Int64) -> ReviewLogEntry {
            ReviewLogEntry(cardID: CardID(cardID), reviewedAt: EpochMillis(at), rating: .good,
                           stateBefore: .new, elapsedDays: 0, scheduledDays: 0,
                           schedulerID: scheduler.schedulerID, parameterSetID: scheduler.parameterSetID,
                           source: .review)
        }
        #expect(throws: ReviewSchedulingError.mixedCards(expected: CardID("a"), found: CardID("b"))) {
            _ = try scheduler.replay([entry("a", 1_000), entry("b", 2_000)])
        }
    }

    @Test("오류 메시지가 무엇이 왜 틀렸는지 말한다")
    func errorsAreDescriptive() {
        #expect(ReviewSchedulingError.fuzzNotSealed(parameterSetID: "fsrs6-abc").description.contains("replay"))
        #expect(ReviewSchedulingError.emptyLog.description.contains("review_log"))
        #expect(
            ReviewSchedulingError.mixedCards(expected: CardID("a"), found: CardID("b"))
                .description.contains("b")
        )
    }
}
