/// FSRS 등급. 복습 UI 의 버튼 4개와 1:1 대응한다.
///
/// rawValue 를 정수로 고정하는 이유: `review_log.rating` 이 `CHECK (rating BETWEEN 1 AND 4)` 이고,
/// FSRS 참조 구현·ts-fsrs·Anki 가 전부 1..4 정수를 쓴다. 문자열로 바꾸면 참조 벡터와 대조가 어려워진다.
public enum ReviewRating: Int, Hashable, Sendable, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

/// FSRS 카드 학습 상태.
///
/// FSRS 참조 구현은 0..3 정수를 쓰지만 DB 에는 문자열로 넣는다 — 골든 스키마와 `sqlite3` 덤프를
/// 사람이 읽을 때 `state_before = 2` 보다 `'review'` 가 압도적으로 낫고, 이 컬럼은
/// 인덱스 선두가 아니라 폭 차이가 성능에 영향을 주지 않는다.
public enum LearningState: String, Hashable, Sendable, Codable, CaseIterable {
    case new
    case learning
    case review
    case relearning
}

/// 이 복습이 **왜** 일어났는가.
///
/// 리플레이가 `cram` 을 스케줄에 반영할지 말지는 스케줄러의 정책이다. 로그는 사실만 남긴다.
public enum ReviewSource: String, Hashable, Sendable, Codable, CaseIterable {
    /// 정규 복습 큐에서 나온 카드.
    case scheduled
    /// 시험 직전 몰아보기. 큐 밖에서 사용자가 연속 복습한 것.
    case cram
    /// 사용자가 카드를 직접 열어 채점했다.
    case manual
    /// 외부 앱(Anki 등)에서 가져온 과거 이력. `review_duration_ms` 가 0 일 수 있다.
    case imported = "import"
}

/// `review_log` 한 행. **이 앱의 유일한 진실의 원천**이다.
///
/// 나머지 학습 상태(`card_state`)는 전부 이 로그에서 재계산 가능한 파생물이다. 그래서 이 테이블은
/// append-only 이고, UPDATE·DELETE 는 트리거로 봉인돼 `SQLITE_CONSTRAINT` 로 ABORT 된다.
/// 실수로 지울 수 있게 두면 FSRS 파라미터 재최적화가 영영 불가능해진다.
public struct ReviewLogEntry: Hashable, Sendable, Codable {
    /// 저장 전에는 nil. 저장 후 DB 가 발급한 값이 채워진다.
    public var id: ReviewLogID?
    public var cardID: CardID
    public var reviewedAt: EpochMilliseconds
    public var rating: ReviewRating
    /// 이 복습을 적용하기 **직전**의 상태. 리플레이 검증(내 계산이 당시와 같은가)에 쓴다.
    public var stateBefore: LearningState
    /// 직전 복습으로부터 실제 경과한 일수. 첫 복습은 0.
    public var elapsedDays: Int
    /// 직전 복습이 예정했던 간격(일). 첫 복습은 0.
    public var scheduledDays: Int
    /// 카드를 보고 등급을 누르기까지 걸린 시간. 이후 FSRS 옵티마이저의 입력이 된다.
    public var reviewDurationMilliseconds: Int
    /// 알고리즘 식별자 (`"fsrs6"`). 알고리즘 자체가 바뀌어도 과거 행의 의미가 흐려지지 않게.
    public var schedulerID: String
    public var parameterSetID: ParameterSetID
    public var source: ReviewSource

    public init(
        id: ReviewLogID? = nil,
        cardID: CardID,
        reviewedAt: EpochMilliseconds,
        rating: ReviewRating,
        stateBefore: LearningState,
        elapsedDays: Int = 0,
        scheduledDays: Int = 0,
        reviewDurationMilliseconds: Int = 0,
        schedulerID: String = "fsrs6",
        parameterSetID: ParameterSetID = .fsrs6Default,
        source: ReviewSource = .scheduled
    ) {
        self.id = id
        self.cardID = cardID
        self.reviewedAt = reviewedAt
        self.rating = rating
        self.stateBefore = stateBefore
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.reviewDurationMilliseconds = reviewDurationMilliseconds
        self.schedulerID = schedulerID
        self.parameterSetID = parameterSetID
        self.source = source
    }
}

/// `scheduler_parameters` 한 행 — 어떤 가중치로 스케줄됐는지 소급 설명하기 위한 소형 테이블.
///
/// 활성 세트는 **정확히 하나**다. 상한은 부분 유니크 인덱스가, 하한은 마이그레이션 001 의 시드가 지킨다.
public struct SchedulerParameterSet: Hashable, Sendable, Codable {
    public var id: ParameterSetID
    public var schedulerID: String

    /// FSRS 가중치 배열. `nil` 이면 **스케줄러 내장 기본값**을 뜻한다.
    ///
    /// 기본 w(FSRS-6 은 21개)를 여기 복제하지 않는 이유: 상수의 주인은 `LearnScheduling` 이고,
    /// 영속화 계층이 사본을 들면 벤더 FSRS 를 갱신할 때 두 곳이 조용히 어긋난다.
    /// 개인화 옵티마이저가 실제로 값을 낸 뒤부터 이 배열이 채워진다.
    public var weights: [Double]?

    public var desiredRetention: Double
    public var createdAt: EpochMilliseconds
    public var isActive: Bool

    public init(
        id: ParameterSetID,
        schedulerID: String = "fsrs6",
        weights: [Double]? = nil,
        desiredRetention: Double = 0.9,
        createdAt: EpochMilliseconds,
        isActive: Bool
    ) {
        self.id = id
        self.schedulerID = schedulerID
        self.weights = weights
        self.desiredRetention = desiredRetention
        self.createdAt = createdAt
        self.isActive = isActive
    }
}
