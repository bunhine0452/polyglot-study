/// `card_state` 한 행 — **언제든 버리고 재생성할 수 있는 파생 캐시**다.
///
/// 이 타입에 있는 값 중 `review_log` 에서 재계산되지 않는 것은 하나도 없다. 그래서
/// `CardStateStore.replaceAll(with:)` 이 통째 교체를 지원하고, 재구축 후에도 같은 행이 나와야 한다.
/// 캐시를 진실처럼 다루기 시작하면(예: 여기에만 있는 사용자 입력을 넣으면) 재구축이 파괴적 연산이 된다.
///
/// ## 알고리즘 상태를 **합성**한다
///
/// 행의 대부분은 스케줄러가 만든 `CardSchedulingState` 그 자체다. 두 타입이 stability·difficulty·
/// due 를 각자 들면 리플레이 결과를 행으로 옮길 때마다 필드를 손으로 베껴야 하고, 한쪽에 필드가
/// 늘면 다른 쪽이 조용히 뒤처진다. 그래서 행은 알고리즘 상태를 통째로 품고, **행만 아는 것**
/// 두 개를 더한다.
///
/// - `languageID` — 트랙별 독립 학습이라 큐 쿼리는 **항상 언어로 먼저 좁힌다**. `review_log`
///   에는 없는 컬럼이 여기 있는 이유가 이것: 로그는 카드 단위 사실만 남기고, 캐시는 큐 쿼리에
///   필요한 걸 비정규화한다.
/// - `rebuiltAt` — 이 행을 언제 계산했나. 알고리즘은 이 값을 읽지 않는다.
///
/// - Warning: `card_state` 테이블에는 `CardSchedulingState.elapsedDays` 와
///   `learningStepIndex` 에 대응하는 컬럼이 **없다**(출시된 스키마이고 마이그레이션은 불변이다).
///   저장했다 다시 읽으면 두 값은 0 이다. 즉 이 캐시에서 되살린 상태로 곧장
///   `ReviewScheduler.apply` 를 부르면 학습 단계 카드의 스텝 인덱스가 처음으로 되감긴다.
///   정확한 상태가 필요하면 `review_log` 를 리플레이해라 — 캐시가 아니라 로그가 진실이다.
public struct CardStateSnapshot: Hashable, Sendable, Codable {
    /// 로그에서 재계산되는 알고리즘 상태 전부.
    public var scheduling: CardSchedulingState

    /// 큐 쿼리를 위해 비정규화한 트랙. `(language_id, due_at)` 인덱스의 선두 컬럼이다.
    public var languageID: LanguageID

    /// 이 행을 계산한 시각.
    public var rebuiltAt: EpochMillis

    public init(
        scheduling: CardSchedulingState,
        languageID: LanguageID,
        rebuiltAt: EpochMillis
    ) {
        self.scheduling = scheduling
        self.languageID = languageID
        self.rebuiltAt = rebuiltAt
    }

    /// 컬럼 목록 그대로 받는 편의 생성자.
    ///
    /// 인자가 `card_state` 의 컬럼과 1:1 이라 행을 손으로 만들 때 읽기 쉽다. 대신 컬럼이 없는
    /// `elapsedDays`·`learningStepIndex` 는 표현하지 못한다 — 0 으로 들어간다.
    public init(
        cardID: CardID,
        languageID: LanguageID,
        stability: Double,
        difficulty: Double,
        dueAt: EpochMillis,
        lastReviewedAt: EpochMillis? = nil,
        phase: CardPhase,
        reps: Int = 0,
        lapses: Int = 0,
        scheduledDays: Int = 0,
        derivedFromLogID: ReviewLogID? = nil,
        parameterSetID: ParameterSetID = .fsrs6Default,
        rebuiltAt: EpochMillis
    ) {
        self.init(
            scheduling: CardSchedulingState(
                cardID: cardID,
                phase: phase,
                stability: stability,
                difficulty: difficulty,
                dueAt: dueAt,
                lastReviewedAt: lastReviewedAt,
                scheduledDays: scheduledDays,
                reps: reps,
                lapses: lapses,
                derivedFromLogID: derivedFromLogID,
                parameterSetID: parameterSetID
            ),
            languageID: languageID,
            rebuiltAt: rebuiltAt
        )
    }
}

// MARK: - 컬럼 접근자
//
// 합성한 알고리즘 상태를 한 겹 벗겨 준다. `snapshot.scheduling.dueAt` 보다
// `snapshot.dueAt` 이 컬럼 이름과 같아 SQL 을 읽다 온 눈에 자연스럽다.

extension CardStateSnapshot {
    public var cardID: CardID {
        get { scheduling.cardID }
        set { scheduling.cardID = newValue }
    }

    public var phase: CardPhase {
        get { scheduling.phase }
        set { scheduling.phase = newValue }
    }

    public var stability: Double {
        get { scheduling.stability }
        set { scheduling.stability = newValue }
    }

    public var difficulty: Double {
        get { scheduling.difficulty }
        set { scheduling.difficulty = newValue }
    }

    public var dueAt: EpochMillis {
        get { scheduling.dueAt }
        set { scheduling.dueAt = newValue }
    }

    public var lastReviewedAt: EpochMillis? {
        get { scheduling.lastReviewedAt }
        set { scheduling.lastReviewedAt = newValue }
    }

    public var reps: Int {
        get { scheduling.reps }
        set { scheduling.reps = newValue }
    }

    public var lapses: Int {
        get { scheduling.lapses }
        set { scheduling.lapses = newValue }
    }

    public var scheduledDays: Int {
        get { scheduling.scheduledDays }
        set { scheduling.scheduledDays = newValue }
    }

    public var derivedFromLogID: ReviewLogID? {
        get { scheduling.derivedFromLogID }
        set { scheduling.derivedFromLogID = newValue }
    }

    public var parameterSetID: ParameterSetID {
        get { scheduling.parameterSetID }
        set { scheduling.parameterSetID = newValue }
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
