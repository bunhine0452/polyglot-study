import Testing
import LearnCore
import LearnScheduling
@testable import ReviewFeature

/// `RatingButtonRow.specs(from:)` 가 실제 FSRS-6 `ReviewPreview` 에서 버튼 4개를 만든다.
/// 하드코딩된 숫자와 비교하지 않는다 — 같은 `scheduler.preview(...)` 호출 결과와 비교해서
/// "이 화면이 보여주는 간격이 스케줄러가 실제로 계산한 값과 정확히 같다" 를 증명한다.
@Suite("RatingButtonRow · 실 FSRS 프리뷰에서 스펙 조립")
struct RatingButtonRowTests {
    @Test("신규 카드의 4개 스펙이 scheduler.preview(_:at:) 결과와 정확히 일치한다")
    func specsMatchRealSchedulerPreview() throws {
        let scheduler = try ReviewFixtures.scheduler()
        let cardID = ReviewFixtures.swiftCard
        let card = scheduler.initialState(for: cardID, createdAt: ReviewFixtures.noon)

        let preview = try scheduler.preview(card, at: ReviewFixtures.noon)
        let specs = RatingButtonRow.specs(from: preview)

        #expect(specs.count == 4)
        #expect(specs.map(\.rating) == ReviewRating.allCases)
        #expect(specs.map(\.rating) == [.again, .hard, .good, .easy])

        // 4개 라벨 각각이 그 rating 의 `ReviewSchedule.shortDescription` 그대로다 —
        // 화면이 별도로 숫자를 다시 포매팅하지 않는다.
        #expect(specs[0].intervalLabel == preview.again.shortDescription)
        #expect(specs[1].intervalLabel == preview.hard.shortDescription)
        #expect(specs[2].intervalLabel == preview.good.shortDescription)
        #expect(specs[3].intervalLabel == preview.easy.shortDescription)
    }

    @Test("네 간격이 전부 다른 텍스트를 낼 수 있어도 스타일은 여전히 하나다")
    func differingIntervalsDoNotAffectStyle() throws {
        let scheduler = try ReviewFixtures.scheduler()
        let card = scheduler.initialState(for: ReviewFixtures.swiftCard, createdAt: ReviewFixtures.noon)
        let preview = try scheduler.preview(card, at: ReviewFixtures.noon)
        let specs = RatingButtonRow.specs(from: preview)

        // 실제로 텍스트가 갈린다는 걸 먼저 확인한다 — 우연히 전부 같은 라벨이면
        // 아래 "그래도 스타일은 하나" 라는 주장이 공허해진다.
        let distinctLabels = Set(specs.map(\.intervalLabel))
        #expect(distinctLabels.count > 1, "간격 라벨이 전부 같다 — 스케줄러 결과가 이상하다: \(specs)")

        let metrics = specs.map { RatingButtonMetrics.metrics(for: $0.rating) }
        #expect(metrics.allSatisfy { $0 == RatingButtonMetrics.shared })
    }
}
