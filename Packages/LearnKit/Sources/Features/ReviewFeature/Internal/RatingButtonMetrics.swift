internal import SwiftUI
internal import DesignSystem
internal import LearnCore

/// 4개 채점 버튼이 공유하는 **단 하나의** 시각 스펙. `{#screen-review}` `{#review-no-nudge}`
///
/// 완료 기준이 "4버튼의 폭·높이·배경·테두리가 완전히 동일" 이다. 이걸 지키는 가장 확실한
/// 방법은 rating 별로 조건을 만들지 않는 것이다 — 그래서 이 값들은 전부 `switch` 없이
/// 하나의 상수로만 존재한다. 폭은 여기 없다: 렌더 쪽에서 4개 버튼 모두
/// `.frame(maxWidth: .infinity)` 로 같은 `HStack` 안에서 폭을 균등 분할하기 때문에
/// (`SegmentedProgress` 가 진도칸에 쓰는 것과 같은 관용구) 애초에 폭을 스펙에 넣어
/// 비교할 대상이 없다 — 분할 자체가 항상 균등하다.
struct RatingButtonMetrics: Equatable {
    /// 디자인 실측 72px. 8px 그리드의 9배.
    var height: CGFloat
    var background: Color
    var borderColor: Color
    var borderWidth: CGFloat
    /// 이 디자인에 곡률은 없다 — 0 은 값이 아니라 규칙이다.
    var cornerRadius: CGFloat

    static let shared = RatingButtonMetrics(
        height: 72,
        background: Palette.paper,
        borderColor: Palette.ink,
        borderWidth: Rules.thickness,
        cornerRadius: 0
    )

    /// rating 을 받지만 **절대 분기하지 않고 항상 `shared` 를 돌려준다.**
    ///
    /// 시그니처에 `rating` 을 남겨 둔 이유: 언젠가 "특정 rating 만 강조하자" 는 요청이
    /// 들어와도 고칠 자리가 여기 한 곳이라는 걸 분명히 하기 위해서다. `RatingButtonMetricsTests`
    /// 가 4개 rating 전부 이 함수의 결과가 완전히 같은지 검사하므로, 여기 `switch` 를
    /// 붙이는 순간 테스트가 즉시 깨진다.
    static func metrics(for rating: ReviewRating) -> RatingButtonMetrics { shared }
}

/// 버튼 하나에 필요한 표시 정보. **시각 속성이 하나도 없다** — 텍스트와 숫자 힌트뿐이고,
/// 스타일은 전부 `RatingButtonMetrics` 에서 온다. 이 타입에 색이나 크기 필드를 추가하면
/// "버튼마다 다른 스타일" 의 문이 열리므로 추가하지 않는다.
struct RatingButtonSpec: Identifiable, Equatable {
    let rating: ReviewRating
    /// `scheduler.preview(_:at:)` 가 계산한 실제 FSRS-6 간격 라벨(`"10분"` 등).
    let intervalLabel: String

    var id: ReviewRating { rating }
    var label: String { ReviewCopy.label(for: rating) }
    var keyHint: Int { ReviewCopy.keyHint(for: rating) }
}

/// `ReviewPreview` 한 번의 계산에서 버튼 4개의 스펙을 만든다. `{#scheduler-preview}`
enum RatingButtonRow {
    /// 순서는 again → hard → good → easy — `ReviewRating.allCases` 선언 순서 그대로다.
    static func specs(from preview: ReviewPreview) -> [RatingButtonSpec] {
        ReviewRating.allCases.map { rating in
            RatingButtonSpec(rating: rating, intervalLabel: preview[rating].shortDescription)
        }
    }
}
