/// 카드 하나의 **알고리즘 상태** — FSRS 가 읽고 쓰는 값 전부, 그리고 그것만.
///
/// **이 값은 캐시다.** 언제든 통째로 버리고 `review_log` 에서 재구축할 수 있어야 하고,
/// 재구축 결과는 원본과 바이트 단위로 같아야 한다 — 그 불변식이 `ReviewScheduler.replay(_:)`
/// 와 퍼즈 봉인(`FuzzSeal`)으로 지켜진다.
///
/// `card_state` **테이블 한 행**은 이 타입이 아니라 이 타입을 품은 `CardStateSnapshot` 이다.
/// 행에는 큐 쿼리를 위해 비정규화한 컬럼(`language_id`)과 캐시 메타데이터(`rebuilt_at`)가
/// 더 붙는데, 그건 알고리즘이 모르는 정보라 여기 섞으면 스케줄러가 저장 계층을 알게 된다.
public struct CardSchedulingState: Hashable, Sendable, Codable {
    public var cardID: CardID
    public var phase: CardPhase
    /// FSRS 안정성 S. 기억이 얼마나 오래 가는가 (R=90% 가 되는 간격, 일 단위). 신규 카드는 0.
    public var stability: Double
    /// FSRS 난이도 D, 1...10.
    public var difficulty: Double
    public var dueAt: EpochMillis
    /// 한 번도 복습하지 않은 카드는 nil.
    public var lastReviewedAt: EpochMillis?
    /// 직전 리뷰와 그 앞 리뷰 사이의 일수. FSRS 가 계산한 값을 그대로 옮긴 것.
    ///
    /// - Important: `card_state` 테이블에는 이 컬럼이 **없다**. `CardStateSnapshot` 을
    ///   거쳐 저장했다가 다시 읽으면 0 이 된다 — 정확한 값이 필요하면 로그를 리플레이해라.
    public var elapsedDays: Int
    /// 지금 걸려 있는 간격(일). 학습 단계 카드는 0.
    public var scheduledDays: Int
    /// `learning`/`relearning` 일 때만 의미 있는 학습 스텝 인덱스(0-기반).
    ///
    /// - Important: `elapsedDays` 와 같이 `card_state` 에 컬럼이 없다. 아래 주석 참고.
    public var learningStepIndex: Int
    public var reps: Int
    public var lapses: Int
    /// 이 상태를 만들어낸 마지막 `review_log` 행 id. 순수 리플레이에서는 로그가 들고 온
    /// 값을 그대로 전파하고, 로그에 id 가 없으면 `nil` 이다.
    ///
    /// 이 값과 해당 카드의 `MAX(review_log.id)` 가 다르면 캐시가 뒤처진 것(stale)이다.
    public var derivedFromLogID: ReviewLogID?
    /// 이 상태를 계산한 파라미터 세트. 활성 세트와 다르면 stale — 재구축 대상이다.
    public var parameterSetID: ParameterSetID

    public init(
        cardID: CardID,
        phase: CardPhase = .new,
        stability: Double = 0,
        difficulty: Double = 0,
        dueAt: EpochMillis,
        lastReviewedAt: EpochMillis? = nil,
        elapsedDays: Int = 0,
        scheduledDays: Int = 0,
        learningStepIndex: Int = 0,
        reps: Int = 0,
        lapses: Int = 0,
        derivedFromLogID: ReviewLogID? = nil,
        parameterSetID: ParameterSetID
    ) {
        self.cardID = cardID
        self.phase = phase
        self.stability = stability
        self.difficulty = difficulty
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.learningStepIndex = learningStepIndex
        self.reps = reps
        self.lapses = lapses
        self.derivedFromLogID = derivedFromLogID
        self.parameterSetID = parameterSetID
    }
}

extension CardSchedulingState {
    /// 아직 한 번도 복습하지 않은 카드.
    public static func newCard(
        _ cardID: CardID,
        createdAt: EpochMillis,
        parameterSetID: ParameterSetID
    ) -> CardSchedulingState {
        CardSchedulingState(cardID: cardID, phase: .new, dueAt: createdAt, parameterSetID: parameterSetID)
    }

    /// 지금 풀어야 하는 카드인가.
    ///
    /// 간격이 하루 이상인 카드는 **학습일 단위**로 판정한다 — 어제 04:00 에 "3일 뒤" 로 잡힌
    /// 카드는 사흘 뒤 04:00 부터 큐에 뜬다. 학습 단계 카드(간격 0, 분 단위)는 롤오버와
    /// 무관하게 정확한 시각으로 판정한다. 10분 뒤 카드가 하루의 시작이라는 이유로 즉시
    /// 뜨면 학습 스텝이 무의미해지기 때문이다.
    public func isDue(asOf now: EpochMillis, dayBoundary: DayBoundary) -> Bool {
        guard scheduledDays >= 1 else { return dueAt <= now }
        return dayBoundary.studyDay(containing: dueAt) <= dayBoundary.studyDay(containing: now)
    }

    /// 활성 파라미터 세트와 다른 세트로 계산된 상태인가. `{#rebuild-on-param-change}`
    public func isStale(activeParameterSetID: ParameterSetID) -> Bool {
        parameterSetID != activeParameterSetID
    }
}

/// 파라미터 세트가 바뀐 뒤 재구축이 필요한 카드를 집계한다.
///
/// 입력 순서와 무관하게 `cardID` 오름차순으로 돌려주므로 스냅샷 비교에 그대로 쓸 수 있다.
public func staleCardIDs(
    in states: some Sequence<CardSchedulingState>,
    activeParameterSetID: ParameterSetID
) -> [CardID] {
    states
        .filter { $0.isStale(activeParameterSetID: activeParameterSetID) }
        .map(\.cardID)
        .sorted { $0.rawValue < $1.rawValue }
}
