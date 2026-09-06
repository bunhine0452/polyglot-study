/// `review_log` 한 행. **이 앱의 유일한 진실의 원천**이다.
///
/// 나머지 학습 상태(`card_state`)는 전부 이 로그에서 재계산 가능한 파생물이다. 그래서 이 테이블은
/// append-only 이고, UPDATE·DELETE 는 트리거로 봉인돼 `SQLITE_CONSTRAINT` 로 ABORT 된다.
/// 실수로 지울 수 있게 두면 FSRS 파라미터 재최적화가 영영 불가능해진다.
///
/// `elapsedDays` 와 `scheduledDays` 는 **재구축 입력이 아니라 기록**이다 — 리플레이는 두 값을
/// 읽지 않고 로그의 시각열에서 다시 계산한다. 그래야 컬럼이 오염돼도 재구축이 흔들리지 않고,
/// 반대로 두 값은 재구축 결과를 검산하는 데 쓸 수 있다.
public struct ReviewLogEntry: Hashable, Sendable, Codable {
    /// DB 행 id. 저장 전에는 nil 이고 저장 후 DB 가 발급한 값이 채워진다.
    ///
    /// 순수 리플레이는 이 값을 쓰지 않지만, 동일 밀리초 리뷰의 **결정적 정렬**과
    /// `card_state.derived_from_log_id` 전파에 쓴다. 메모리상 로그에는 `nil` 이어도 된다.
    public var id: ReviewLogID?
    public var cardID: CardID
    /// epoch ms UTC.
    public var reviewedAt: EpochMillis
    public var rating: ReviewRating
    /// 이 복습을 적용하기 **직전**의 단계. 소급 통계·리플레이 검증(내 계산이 당시와 같은가)에
    /// 쓰며, 리플레이 자체는 이 값을 신뢰하지 않는다.
    public var stateBefore: CardPhase
    /// 직전 리뷰로부터 실제 경과한 일수(FSRS 가 계산한 값). 첫 복습은 0. 기록용.
    public var elapsedDays: Int
    /// 이 리뷰가 새로 잡은 간격(일). 학습 스텝으로 넘어갔으면 0. 기록용.
    public var scheduledDays: Int
    /// 카드를 보고 등급을 누르기까지 걸린 시간. 이후 FSRS 옵티마이저의 입력이 된다.
    ///
    /// 컬럼이 `NOT NULL` 이라 "모름" 을 표현하지 않는다 — 측정하지 않았으면 0 이다.
    public var reviewDurationMS: Int
    /// 어떤 스케줄러가 이 행을 만들었나. 예: `fsrs-6/swift-fsrs@4fbaf20`.
    /// 알고리즘 자체가 바뀌어도 과거 행의 의미가 흐려지지 않게 박아 둔다.
    public var schedulerID: String
    /// 어떤 파라미터 세트로 스케줄됐나. `scheduler_parameters` 테이블 키.
    public var parameterSetID: ParameterSetID
    public var source: ReviewLogSource

    public init(
        id: ReviewLogID? = nil,
        cardID: CardID,
        reviewedAt: EpochMillis,
        rating: ReviewRating,
        stateBefore: CardPhase,
        elapsedDays: Int = 0,
        scheduledDays: Int = 0,
        reviewDurationMS: Int = 0,
        schedulerID: String = "fsrs6",
        parameterSetID: ParameterSetID = .fsrs6Default,
        source: ReviewLogSource = .review
    ) {
        self.id = id
        self.cardID = cardID
        self.reviewedAt = reviewedAt
        self.rating = rating
        self.stateBefore = stateBefore
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.reviewDurationMS = reviewDurationMS
        self.schedulerID = schedulerID
        self.parameterSetID = parameterSetID
        self.source = source
    }

    /// 이 행이 스케줄에 반영되는가. `.cram` 은 기록만 된다.
    public var affectsSchedule: Bool { source != .cram }
}

extension Array where Element == ReviewLogEntry {
    /// 리플레이 정렬 순서 — `(reviewedAt, id, 입력 순서)`.
    ///
    /// `Swift.sort` 는 **안정 정렬이 아니다**. 같은 밀리초에 id 없는 두 행이 들어오면
    /// 정렬 결과가 실행마다 달라질 수 있고, 그러면 리플레이 결정성이 즉시 깨진다.
    /// 입력 인덱스를 마지막 키로 붙여 전순서를 만든다.
    public func replayOrdered() -> [ReviewLogEntry] {
        enumerated()
            .sorted { lhs, rhs in
                if lhs.element.reviewedAt != rhs.element.reviewedAt {
                    return lhs.element.reviewedAt < rhs.element.reviewedAt
                }
                let lhsID = lhs.element.id?.rawValue ?? Int64.min
                let rhsID = rhs.element.id?.rawValue ?? Int64.min
                if lhsID != rhsID { return lhsID < rhsID }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
