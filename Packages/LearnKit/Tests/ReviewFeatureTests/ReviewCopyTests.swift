import Testing
import LearnCore
@testable import ReviewFeature

/// `{#review-no-nudge}` 규칙 1 — 문구가 상수이고, 정확히 그 문장이다.
@Suite("ReviewCopy · 고정 문구")
struct ReviewCopyTests {
    @Test("카드가 사라지지 않는다는 문구가 정확히 이 문장이다")
    func noCardRemovalNoticeIsExactSentence() {
        #expect(ReviewCopy.noCardRemovalNotice == "어떤 답을 골라도 카드는 사라지지 않습니다.")
    }

    @Test("간격 설명 문구가 FSRS-6 출처를 밝힌다")
    func intervalExplanationMentionsFSRS() {
        #expect(ReviewCopy.intervalExplanation.contains("FSRS-6"))
    }

    @Test("rating 라벨 4개가 디자인과 정확히 같다 — 순서는 again → hard → good → easy")
    func labelsMatchDesign() {
        #expect(ReviewRating.allCases.map(ReviewCopy.label(for:)) == ["다시", "어려움", "좋음", "쉬움"])
    }

    @Test("키보드 숫자 힌트는 rating rawValue 와 같다")
    func keyHintMatchesRawValue() {
        for rating in ReviewRating.allCases {
            #expect(ReviewCopy.keyHint(for: rating) == rating.rawValue)
        }
        #expect(ReviewRating.allCases.map(ReviewCopy.keyHint(for:)) == [1, 2, 3, 4])
    }
}
