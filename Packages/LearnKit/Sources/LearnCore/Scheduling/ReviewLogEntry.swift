/// `review_log` 한 행. **진실의 원천**이다 — 이 배열만 있으면 모든 `card_state` 를
/// 재구축할 수 있어야 한다.
///
/// 컬럼 구성은 플랜 `{#review-log-columns}` 를 그대로 따른다. `elapsedDays` 와
/// `scheduledDays` 는 **재구축 입력이 아니라 기록**이다 — 리플레이는 두 값을 읽지 않고
/// 로그의 시각열에서 다시 계산한다. 그래야 컬럼이 오염돼도 재구축이 흔들리지 않고,
/// 반대로 두 값은 재구축 결과를 검산하는 데 쓸 수 있다.
public struct ReviewLogEntry: Hashable, Sendable, Codable {
    /// DB 행 id. 순수 리플레이는 이 값을 쓰지 않지만, 동일 밀리초 리뷰의 **결정적 정렬**과
    /// `card_state.derived_from_log_id` 전파에 쓴다. 메모리상 로그에는 `nil` 이어도 된다.
    public var logID: Int64?
    public var cardID: CardID
    /// epoch ms UTC.
    public var reviewedAt: EpochMillis
    public var rating: ReviewRating
    /// 리뷰 **직전** 카드 단계. 소급 통계용 기록이며 리플레이는 이 값을 신뢰하지 않는다.
    public var stateBefore: CardPhase
    /// 직전 리뷰로부터 지난 일수(FSRS 가 계산한 값). 기록용.
    public var elapsedDays: Int
    /// 이 리뷰가 새로 잡은 간격(일). 학습 스텝으로 넘어갔으면 0. 기록용.
    public var scheduledDays: Int
    /// 카드를 붙잡고 있던 시간. 통계용이며 스케줄에 영향을 주지 않는다.
    public var reviewDurationMS: Int?
    /// 어떤 스케줄러가 이 행을 만들었나. 예: `fsrs-6/swift-fsrs@4fbaf20`.
    public var schedulerID: String
    /// 어떤 파라미터 세트로 스케줄됐나. `scheduler_parameters` 테이블 키.
    public var parameterSetID: String
    public var source: ReviewLogSource

    public init(
        logID: Int64? = nil,
        cardID: CardID,
        reviewedAt: EpochMillis,
        rating: ReviewRating,
        stateBefore: CardPhase,
        elapsedDays: Int,
        scheduledDays: Int,
        reviewDurationMS: Int? = nil,
        schedulerID: String,
        parameterSetID: String,
        source: ReviewLogSource = .review
    ) {
        self.logID = logID
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
    /// 리플레이 정렬 순서 — `(reviewedAt, logID, 입력 순서)`.
    ///
    /// `Swift.sort` 는 **안정 정렬이 아니다**. 같은 밀리초에 `logID` 없는 두 행이 들어오면
    /// 정렬 결과가 실행마다 달라질 수 있고, 그러면 리플레이 결정성이 즉시 깨진다.
    /// 입력 인덱스를 마지막 키로 붙여 전순서를 만든다.
    public func replayOrdered() -> [ReviewLogEntry] {
        enumerated()
            .sorted { lhs, rhs in
                if lhs.element.reviewedAt != rhs.element.reviewedAt {
                    return lhs.element.reviewedAt < rhs.element.reviewedAt
                }
                let lhsID = lhs.element.logID ?? Int64.min
                let rhsID = rhs.element.logID ?? Int64.min
                if lhsID != rhsID { return lhsID < rhsID }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
