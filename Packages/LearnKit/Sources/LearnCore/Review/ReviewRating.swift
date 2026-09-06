/// 복습 평가. 복습 UI 버튼 4개와 1:1 이다.
///
/// rawValue 는 `review_log.rating` 의 `CHECK (rating BETWEEN 1 AND 4)` 와 같은 값이고,
/// 벤더 FSRS 의 `Rating`·ts-fsrs·Anki 와도 같은 값이다 — 세 경계 모두에서 재해석이 없다.
/// FSRS 의 `Rating.manual(0)` 은 **의도적으로 없다**: 수동 조작은 평가가 아니라 로그
/// `source` 로 표현한다.
public enum ReviewRating: Int, Hashable, Sendable, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

/// 카드의 학습 단계.
///
/// rawValue 가 정수인 것은 벤더 FSRS 의 `CardState` 와 값이 같아 경계에서 재해석이 필요
/// 없기 때문이다. **DB 컬럼(`card_state.state`·`review_log.state_before`)은 TEXT 다** —
/// `sqlite3` 덤프를 사람이 읽을 때 `state_before = 2` 보다 `'review'` 가 압도적으로 낫고,
/// 이 컬럼은 인덱스 선두가 아니라 폭 차이가 성능에 영향을 주지 않는다.
/// 정수 ↔ TEXT 변환은 `LearnPersistence` 의 행 매핑 계층이 혼자 담당한다.
public enum CardPhase: Int, Hashable, Sendable, Codable, CaseIterable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// 이 리뷰가 **왜** 일어났는가. `review_log.source` 컬럼.
///
/// 리플레이 정책이 여기 걸려 있다 — `.cram` 은 **기록은 되지만 스케줄을 바꾸지 않는다**.
/// 시험 전 몰아보기가 장기 스케줄을 흔들면 안 되기 때문이고, 리플레이는 이 규칙을
/// 그대로 재현해야 재구축 결과가 원본과 일치한다. 나머지 셋은 전부 스케줄에 반영된다 —
/// 사용자가 카드를 직접 열어 채점한 `.manual` 도 진짜 복습이다.
///
/// - Note: DB 에 적히는 문자열은 rawValue 와 **다르다**. `review_log.source` 의 CHECK 는
///   출시된 스키마라 `'scheduled'`·`'import'` 로 굳어 있고, 그 철자는
///   `LearnPersistence` 의 행 매핑 계층에만 존재한다.
public enum ReviewLogSource: String, Hashable, Sendable, Codable, CaseIterable {
    /// 정규 복습 큐에서 온 리뷰.
    case review
    /// 추가 연습(몰아보기). 기록만 하고 스케줄에는 반영하지 않는다.
    case cram
    /// 사용자가 큐 밖에서 카드를 직접 열어 채점했다.
    case manual
    /// 외부 도구(Anki 등)에서 옮겨온 과거 이력. `reviewDurationMS` 가 0 일 수 있다.
    case imported
}
