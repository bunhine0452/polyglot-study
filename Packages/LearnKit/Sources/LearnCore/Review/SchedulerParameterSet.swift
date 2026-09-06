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
    public var createdAt: EpochMillis
    public var isActive: Bool

    public init(
        id: ParameterSetID,
        schedulerID: String = "fsrs6",
        weights: [Double]? = nil,
        desiredRetention: Double = 0.9,
        createdAt: EpochMillis,
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
