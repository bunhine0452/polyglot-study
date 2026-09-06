/// 복습 평가. 복습 UI 버튼 4개와 1:1 이다.
///
/// rawValue 는 `review_log.rating` 의 `CHECK (rating BETWEEN 1 AND 4)` 와 같은 값이고,
/// 벤더 FSRS 의 `Rating` 과도 같은 값이다 — 두 경계 모두에서 재해석이 필요 없다.
/// FSRS 의 `Rating.manual(0)` 은 **의도적으로 없다**: 수동 조작은 평가가 아니라 로그
/// `source` 로 표현한다.
public enum ReviewRating: Int, Hashable, Sendable, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

/// 카드의 학습 단계. rawValue 는 `card_state.state` 컬럼 값이자 벤더 FSRS `CardState` 값이다.
public enum CardPhase: Int, Hashable, Sendable, Codable, CaseIterable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// 이 리뷰가 어디서 왔는가. `review_log.source` 컬럼.
///
/// 리플레이 정책이 여기 걸려 있다 — `.cram` 은 **기록은 되지만 스케줄을 바꾸지 않는다**.
/// 시험 전 몰아보기가 장기 스케줄을 흔들면 안 되기 때문이고, 리플레이는 이 규칙을
/// 그대로 재현해야 재구축 결과가 원본과 일치한다.
public enum ReviewLogSource: String, Hashable, Sendable, Codable, CaseIterable {
    /// 정규 복습 큐에서 온 리뷰. 스케줄에 반영된다.
    case review
    /// 추가 연습(몰아보기). 기록만 하고 스케줄에는 반영하지 않는다.
    case cram
    /// 외부 도구(Anki 등)에서 옮겨온 이력. 스케줄에 반영된다.
    case imported
}
