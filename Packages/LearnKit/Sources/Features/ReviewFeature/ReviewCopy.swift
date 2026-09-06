public import LearnCore

/// 이 화면의 고정 문구 + rating 라벨. `{#review-no-nudge}`
///
/// ## 다크 패턴 방지 규칙
///
/// 1. **`noCardRemovalNotice` 는 항상, 그대로 보여준다.** rating 이나 카드 상태에 따라
///    문구를 바꾸거나 숨기지 않는다 — 어떤 답을 골라도 카드가 사라지지 않는다는 사실을
///    사용자가 매번 같은 문장으로 확인할 수 있어야 한다.
/// 2. **'좋음' 을 포함해 어떤 rating 도 시각적으로 유도하지 않는다.** 이 열거형은 텍스트만
///    돌려준다 — 색·크기·강조 같은 시각 속성은 여기 없고, 그 전부는
///    `RatingButtonMetrics.shared` 하나로만 정해진다(`Internal/RatingButtonMetrics.swift`).
///    새 코드가 `label(for:)` 나 그 근처에 `case .good: /* 강조 */` 같은 분기를 추가하면
///    이 규칙을 깬 것이다.
public enum ReviewCopy {
    /// 규칙 1의 문구. 상수로 고정한다 — 화면 어디서도 이 문자열을 다시 조립하지 않는다.
    public static let noCardRemovalNotice = "어떤 답을 골라도 카드는 사라지지 않습니다."
    /// 간격 계산의 출처를 밝히는 문구. 실제 값은 항상 `ReviewScheduler.preview(_:at:)` 에서 온다.
    public static let intervalExplanation = "간격은 이 카드의 복습 기록으로 FSRS-6 가 계산합니다."

    /// rating → 버튼 라벨. 순서는 `ReviewRating.allCases`(again → hard → good → easy)와 같다.
    public static func label(for rating: ReviewRating) -> String {
        switch rating {
        case .again: "다시"
        case .hard: "어려움"
        case .good: "좋음"
        case .easy: "쉬움"
        }
    }

    /// 버튼 위 숫자 힌트. `ReviewRating.rawValue` 와 같은 값이라 별도 매핑을 두지 않는다.
    public static func keyHint(for rating: ReviewRating) -> Int { rating.rawValue }
}
