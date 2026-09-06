/// 오늘 풀 카드를 고르는 정책과 그 결과. `{#due-queue-benchmark}` `{#queue-mixing}`
///
/// ## 왜 이 타입들이 저장 계층 계약에 있는가
///
/// 혼합 비율과 일일 상한은 **큐 쿼리 안에서** 결정된다. 앱 레이어가 넉넉히 가져와서 자르는
/// 방식은 22.8만 행 규모에서 두 번 진다 — 한 번은 성능으로(50장을 위해 2만 행을 읽는다),
/// 한 번은 정확도로(어느 계층이 상한을 아는지가 흐려져 화면마다 다른 큐가 나온다).
/// 그래서 정책은 쿼리의 입력이고, 자르는 일은 SQL 의 `LIMIT` 이 한다.

/// 큐 한 자리가 어느 갈래에서 왔는가.
///
/// rawValue 는 **우선순위**다. 작을수록 먼저 나온다.
public enum DueQueueBucket: Int, Hashable, Sendable, Codable, CaseIterable {
    /// 이미 시작한 카드의 다음 스텝. 분 단위로 돌아오므로 미루면 학습 스텝 자체가 무의미해진다.
    case learning = 0
    /// 간격이 하루 이상인 복습.
    case review = 1
    /// 오늘 처음 보는 카드.
    case new = 2
}

/// 큐 한 자리.
public struct DueQueueEntry: Hashable, Sendable {
    public var snapshot: CardStateSnapshot
    public var bucket: DueQueueBucket

    public init(snapshot: CardStateSnapshot, bucket: DueQueueBucket) {
        self.snapshot = snapshot
        self.bucket = bucket
    }

    public var cardID: CardID { snapshot.cardID }
}

/// 혼합 비율과 일일 상한.
///
/// ## 세 갈래를 나누는 규칙
///
/// - **학습중(`learning`/`relearning`)은 일일 상한 밖이다.** 상한은 "오늘 새로 떠안는 부담" 을
///   제한하는 장치인데, 학습중 카드는 이미 떠안은 부담이다. 10분 뒤 다시 보기로 한 카드를
///   상한 때문에 내일로 미루면 FSRS 의 학습 스텝이 그냥 깨진다.
/// - **신규와 복습이 `dailyLimit` 을 나눠 쓴다.** 몫은 `newShare` 다. 비율을 두는 이유는
///   신규만 계속 밀어넣으면 며칠 뒤 복습 부채가 폭발하고, 복습만 하면 진도가 멈추기 때문이다.
/// - **몫은 서로 넘겨받지 않는다.** 신규가 모자라도 복습이 그 자리를 채우지 않는다. 채우게
///   만들면 "복습은 하루 15장" 이라는 약속이 조건부가 되고, 사용자는 어제와 오늘의 분량이
///   왜 다른지 설명받을 수 없다.
///
/// ## 이미 오늘 한 몫은 빠진다
///
/// 상한은 세션이 아니라 **학습일** 단위다. 앱을 다시 열 때마다 20장이 새로 나오면 상한이 아니다.
/// 그래서 큐 쿼리는 오늘(= `DayBoundary` 가 계산한 학습일 시작 이후) 큐를 통해 푼 카드 수를
/// `review_log` 에서 세어 남은 몫만 낸다. 세는 대상은 `source == .review` 뿐이다 —
/// 몰아보기(`.cram`)나 큐 밖에서 직접 연 카드(`.manual`)가 오늘의 복습 예산을 갉아먹으면 안 된다.
public struct DueQueuePolicy: Hashable, Sendable, Codable {
    /// 하루에 새로 내보낼 신규 + 복습 카드 수. 학습중 카드는 여기 포함되지 않는다.
    public var dailyLimit: Int
    /// `dailyLimit` 중 신규 카드의 몫. 0...1 로 클램프된다.
    public var newShare: Double
    /// 한 번의 호출이 돌려줄 최대 행 수. 화면이 한 번에 들고 있을 양이지 정책 상한이 아니다.
    public var sessionLimit: Int

    public init(dailyLimit: Int = 20, newShare: Double = 0.25, sessionLimit: Int = 50) {
        self.dailyLimit = max(0, dailyLimit)
        self.newShare = min(max(newShare, 0), 1)
        self.sessionLimit = max(0, sessionLimit)
    }

    /// 기본값 — 하루 20장, 그중 신규 5장.
    public static let `default` = DueQueuePolicy()

    /// 오늘 낼 수 있는 신규 카드 수. 반올림은 신규 쪽에서 한 번만 일어난다.
    public var newAllowance: Int {
        min(dailyLimit, Int((Double(dailyLimit) * newShare).rounded()))
    }

    /// 오늘 낼 수 있는 복습 카드 수. 나머지 전부라 두 몫의 합이 항상 `dailyLimit` 이다.
    public var reviewAllowance: Int { dailyLimit - newAllowance }
}
