/// `card_state` 한 행 — **언제든 버리고 재생성할 수 있는 파생 캐시**다.
///
/// 이 타입에 있는 값 중 `review_log` 에서 재계산되지 않는 것은 하나도 없다. 그래서
/// `CardStateStore.replaceAll(with:)` 이 통째 교체를 지원하고, 재구축 후에도 같은 행이 나와야 한다.
/// 캐시를 진실처럼 다루기 시작하면(예: 여기에만 있는 사용자 입력을 넣으면) 재구축이 파괴적 연산이 된다.
public struct CardStateSnapshot: Hashable, Sendable, Codable {
    public var cardID: CardID

    /// 트랙별 독립 학습이라 큐 쿼리는 **항상 언어로 먼저 좁힌다**. `review_log` 에는 없는 컬럼이
    /// 여기 있는 이유가 이것 — 로그는 카드 단위 사실만 남기고, 캐시는 큐 쿼리에 필요한 걸 비정규화한다.
    public var languageID: LanguageID

    /// FSRS 안정성(일). 신규 카드는 0.
    public var stability: Double
    /// FSRS 난이도. FSRS 는 1...10 범위를 유지한다.
    public var difficulty: Double
    public var dueAt: EpochMilliseconds
    /// 한 번도 복습하지 않은 카드는 nil.
    public var lastReviewedAt: EpochMilliseconds?
    public var state: LearningState
    public var reps: Int
    public var lapses: Int
    public var scheduledDays: Int

    /// 이 행이 반영한 마지막 `review_log.id`. nil 이면 "리뷰가 아직 없는 신규 카드로 시드됨".
    ///
    /// 이 값과 해당 카드의 `MAX(review_log.id)` 가 다르면 캐시가 뒤처진 것(stale)이다.
    public var derivedFromLogID: ReviewLogID?

    /// 이 행을 계산할 때 쓴 파라미터 세트. 활성 세트와 다르면 stale 이다.
    public var parameterSetID: ParameterSetID
    public var rebuiltAt: EpochMilliseconds

    public init(
        cardID: CardID,
        languageID: LanguageID,
        stability: Double,
        difficulty: Double,
        dueAt: EpochMilliseconds,
        lastReviewedAt: EpochMilliseconds? = nil,
        state: LearningState,
        reps: Int = 0,
        lapses: Int = 0,
        scheduledDays: Int = 0,
        derivedFromLogID: ReviewLogID? = nil,
        parameterSetID: ParameterSetID = .fsrs6Default,
        rebuiltAt: EpochMilliseconds
    ) {
        self.cardID = cardID
        self.languageID = languageID
        self.stability = stability
        self.difficulty = difficulty
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.state = state
        self.reps = reps
        self.lapses = lapses
        self.scheduledDays = scheduledDays
        self.derivedFromLogID = derivedFromLogID
        self.parameterSetID = parameterSetID
        self.rebuiltAt = rebuiltAt
    }
}

/// 캐시 한 행이 왜 뒤처졌는지.
///
/// 두 원인을 나눠 세는 이유는 대응이 다르기 때문이다 — `logDrift` 는 해당 카드만 이어서 적용하면 되고,
/// `parameterDrift` 는 그 카드의 이력을 처음부터 다시 돌려야 한다.
public struct CardStaleness: Hashable, Sendable {
    public var cardID: CardID
    public var languageID: LanguageID
    /// 캐시가 참조한 파라미터 세트가 더 이상 활성이 아니다 → 전체 리플레이 필요.
    public var parameterDrift: Bool
    /// 캐시가 반영한 로그 워터마크보다 새 로그가 있다 → 증분 적용으로 충분.
    public var logDrift: Bool

    public init(cardID: CardID, languageID: LanguageID, parameterDrift: Bool, logDrift: Bool) {
        self.cardID = cardID
        self.languageID = languageID
        self.parameterDrift = parameterDrift
        self.logDrift = logDrift
    }

    public var isStale: Bool { parameterDrift || logDrift }
}
