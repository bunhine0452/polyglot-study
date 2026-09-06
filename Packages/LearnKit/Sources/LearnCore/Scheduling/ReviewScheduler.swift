/// 어떤 rating 을 눌렀을 때 카드가 어떻게 되는가.
public struct ReviewSchedule: Hashable, Sendable, Codable {
    public var rating: ReviewRating
    /// 이 rating 을 눌렀을 때의 카드 상태.
    public var state: CardSchedulingState
    /// 지금부터 다음 복습까지의 분. 복습 UI 버튼 라벨의 원재료다.
    public var intervalMinutes: Int

    public init(rating: ReviewRating, state: CardSchedulingState, intervalMinutes: Int) {
        self.rating = rating
        self.state = state
        self.intervalMinutes = intervalMinutes
    }

    /// "10분" / "1일" / "4일" / "9일" 같은 짧은 라벨.
    ///
    /// 로케일 포매팅이 아니라 **버튼 4개가 세로로 정렬돼 보이는** 최소 표기다. 실제 지역화가
    /// 필요해지면 UI 계층이 `intervalMinutes` 로 직접 만들면 된다.
    public var shortDescription: String {
        switch intervalMinutes {
        case ..<1: return "지금"
        case ..<60: return "\(intervalMinutes)분"
        case ..<1_440: return "\(intervalMinutes / 60)시간"
        case ..<43_200: return "\(intervalMinutes / 1_440)일"
        case ..<525_600: return "\(intervalMinutes / 43_200)개월"
        default: return "\(intervalMinutes / 525_600)년"
        }
    }
}

/// 4개 rating 의 다음 간격을 **한 번에** 돌려준다. `{#scheduler-preview}`
///
/// 복습 화면은 버튼 4개에 "10분 / 1일 / 4일 / 9일" 을 동시에 띄워야 한다. rating 마다
/// 스케줄러를 네 번 부르면 FSRS 가 카드 상태 사본을 네 번 만들고, 그중 하나라도
/// 시각이 어긋나면 버튼끼리 앞뒤가 맞지 않는다. 한 시각·한 호출로 넷을 낸다.
public struct ReviewPreview: Hashable, Sendable, Codable {
    public var cardID: CardID
    /// 이 미리보기를 계산한 시각. 버튼을 실제로 누를 때도 같은 시각을 넘겨야 라벨과
    /// 실제 스케줄이 일치한다.
    public var evaluatedAt: EpochMillis
    public var again: ReviewSchedule
    public var hard: ReviewSchedule
    public var good: ReviewSchedule
    public var easy: ReviewSchedule

    public init(
        cardID: CardID,
        evaluatedAt: EpochMillis,
        again: ReviewSchedule,
        hard: ReviewSchedule,
        good: ReviewSchedule,
        easy: ReviewSchedule
    ) {
        self.cardID = cardID
        self.evaluatedAt = evaluatedAt
        self.again = again
        self.hard = hard
        self.good = good
        self.easy = easy
    }

    public subscript(rating: ReviewRating) -> ReviewSchedule {
        switch rating {
        case .again: return again
        case .hard: return hard
        case .good: return good
        case .easy: return easy
        }
    }

    /// 버튼 순서(again → hard → good → easy) 그대로.
    public var ordered: [ReviewSchedule] { [again, hard, good, easy] }
}

/// 리뷰 하나를 실제로 적용한 결과 — 새 캐시 행 + 새 로그 행.
///
/// 둘을 함께 돌려주는 이유는 영속화가 **한 트랜잭션**에서 `review_log` 에 append 하고
/// `card_state` 를 upsert 해야 하기 때문이다.
public struct ReviewOutcome: Hashable, Sendable, Codable {
    public var state: CardSchedulingState
    public var logEntry: ReviewLogEntry

    public init(state: CardSchedulingState, logEntry: ReviewLogEntry) {
        self.state = state
        self.logEntry = logEntry
    }
}

/// 여러 카드를 한 번에 재구축한 결과. `{#card-state-rebuild}`
///
/// `Dictionary` 순회 순서는 실행마다 다르다. 스냅샷을 바이트 단위로 비교하려면 결정적
/// 순서가 필요하므로 `states` 는 `cardID` 오름차순 **배열**이 정본이고 사전은 편의 접근자다.
///
/// ## 영속화 경계 — 여기가 `LearnScheduling` 의 끝이다
///
/// 트랜잭션 스왑(`{#rebuild-transactional}`)은 `LearnPersistence` 소유다. 이 타입은 그
/// 경계에 넘길 **완성된 값**이고, 스케줄링 쪽은 DB 를 전혀 모른다. 제안하는 소비 형태:
///
/// ```swift
/// // LearnPersistence 쪽 (이 세션의 소유가 아님)
/// func rebuildCardStates(
///     using scheduler: some ReviewScheduler,
///     cardIDs: [CardID]? = nil        // nil 이면 전체
/// ) async throws -> CardStateRebuild
/// ```
///
/// 구현 형태 제안 — 카드별로 `review_log` 를 스트리밍해 `replay(_:)` 를 호출하고, 결과를
/// 모아 **하나의 쓰기 트랜잭션**에서 `card_state` 를 갈아끼운다. 도중 실패하면 트랜잭션이
/// 롤백되어 기존 캐시가 그대로 남는다. `review_log` 행 수가 재구축 전후로 같은지 같은
/// 트랜잭션 안에서 단언하면 `{#derived-rebuild-idiom}` 의 요구도 만족한다.
public struct CardStateRebuild: Hashable, Sendable, Codable {
    /// `cardID` 오름차순.
    public var states: [CardSchedulingState]
    /// 스케줄에 반영된 로그 행 수.
    public var appliedEntryCount: Int
    /// `.cram` 이라 건너뛴 로그 행 수.
    public var skippedEntryCount: Int
    public var schedulerID: String
    public var parameterSetID: String

    public init(
        states: [CardSchedulingState],
        appliedEntryCount: Int,
        skippedEntryCount: Int,
        schedulerID: String,
        parameterSetID: String
    ) {
        self.states = states
        self.appliedEntryCount = appliedEntryCount
        self.skippedEntryCount = skippedEntryCount
        self.schedulerID = schedulerID
        self.parameterSetID = parameterSetID
    }

    public var byCardID: [CardID: CardSchedulingState] {
        Dictionary(uniqueKeysWithValues: states.map { ($0.cardID, $0) })
    }
}

/// 스케줄링이 실패하는 방식.
public enum ReviewSchedulingError: Error, Hashable, Sendable, CustomStringConvertible {
    /// 빈 로그로 단일 카드 리플레이를 시도했다.
    case emptyLog
    /// 단일 카드 리플레이에 두 카드의 로그가 섞여 있다.
    case mixedCards(expected: CardID, found: CardID)
    /// 퍼즈가 봉인되지 않은 파라미터로 스케줄러를 만들려 했다. `{#fuzz-seal}`
    case fuzzNotSealed(parameterSetID: String)
    /// FSRS-6 이 아닌 파라미터. (예: 19-length v5 `w`)
    case unsupportedAlgorithm(reason: String)
    /// 카드 상태가 FSRS 가 받아들일 수 없는 값이다.
    case invalidCardState(cardID: CardID, reason: String)
    /// 벤더 엔진이 던진 오류를 경계에서 감싼 것. FSRS 타입은 절대 밖으로 나가지 않는다.
    case engineFailure(cardID: CardID?, reason: String)

    public var description: String {
        switch self {
        case .emptyLog:
            return "빈 review_log 로는 카드 상태를 재구축할 수 없다"
        case let .mixedCards(expected, found):
            return "단일 카드 리플레이에 다른 카드가 섞였다 — 기대 \(expected.rawValue), 발견 \(found.rawValue)"
        case let .fuzzNotSealed(parameterSetID):
            return """
                파라미터 세트 '\(parameterSetID)' 의 FSRS 퍼즈가 봉인되지 않았다. \
                퍼즈를 켠 채 첫 리뷰가 기록되면 이후 어떤 replay 도 원본 스케줄을 재현하지 못한다
                """
        case let .unsupportedAlgorithm(reason):
            return "지원하지 않는 알고리즘 파라미터 — \(reason)"
        case let .invalidCardState(cardID, reason):
            return "카드 \(cardID.rawValue) 의 상태가 유효하지 않다 — \(reason)"
        case let .engineFailure(cardID, reason):
            let card = cardID.map { "카드 \($0.rawValue): " } ?? ""
            return "\(card)스케줄링 엔진 실패 — \(reason)"
        }
    }
}

/// 복습 스케줄링 계약. **벤더 FSRS 는 이 뒤에 완전히 숨는다.**
///
/// `LearnCore` 어디에도 FSRS 타입이 나타나지 않는다는 것이 이 프로토콜의 존재 이유다.
/// 알고리즘 교체(FSRS-6 → 7, 혹은 SM-2 폴백)는 구현 타입 하나를 갈아끼우는 일이어야 한다.
///
/// 모든 구현은 순수해야 한다 — DB 도, 파일도, 전역 시각도 모른다. 시각은 `clock` 으로
/// 들어오고, 이력은 `[ReviewLogEntry]` 로 들어온다.
public protocol ReviewScheduler: Sendable {
    /// 이 스케줄러의 안정 식별자. `review_log.scheduler_id` 에 그대로 들어간다.
    var schedulerID: String { get }
    /// 활성 파라미터 세트 id. `review_log.parameter_set_id` 이자 `card_state` 의 stale 판정 기준.
    var parameterSetID: String { get }
    var dayBoundary: DayBoundary { get }
    var clock: any SchedulerClock { get }

    /// 아직 복습한 적 없는 카드의 초기 상태.
    func initialState(for cardID: CardID, createdAt: EpochMillis) -> CardSchedulingState

    /// rating 4개의 다음 간격을 한 번에. `{#scheduler-preview}`
    func preview(_ card: CardSchedulingState, at now: EpochMillis) throws -> ReviewPreview

    /// 리뷰 하나를 적용해 새 상태와 로그 행을 만든다.
    func apply(
        _ rating: ReviewRating,
        to card: CardSchedulingState,
        at now: EpochMillis,
        reviewDurationMS: Int?,
        source: ReviewLogSource
    ) throws -> ReviewOutcome

    /// **DB 를 모르는 순수 함수.** 한 카드의 로그 전체 → 최종 상태. `{#replay-determinism}`
    ///
    /// 같은 입력이면 언제 몇 번을 돌려도 결과가 완전히 같아야 한다. 그 보장이 곧
    /// `card_state` 를 버릴 수 있는 캐시로 취급할 수 있는 근거다.
    func replay(_ log: [ReviewLogEntry]) throws -> CardSchedulingState

    /// 여러 카드가 섞인 로그 → 카드별 최종 상태. `{#card-state-rebuild}`
    func rebuild(_ log: [ReviewLogEntry]) throws -> CardStateRebuild
}

extension ReviewScheduler {
    /// 주입 클록의 "지금" 으로 미리보기.
    public func preview(_ card: CardSchedulingState) throws -> ReviewPreview {
        try preview(card, at: clock.now())
    }

    /// 주입 클록의 "지금" 으로 리뷰 적용.
    public func apply(
        _ rating: ReviewRating,
        to card: CardSchedulingState,
        reviewDurationMS: Int? = nil,
        source: ReviewLogSource = .review
    ) throws -> ReviewOutcome {
        try apply(rating, to: card, at: clock.now(), reviewDurationMS: reviewDurationMS, source: source)
    }

    /// 활성 파라미터 세트와 다른 세트로 계산된 카드들. `{#rebuild-on-param-change}`
    public func staleCards(in states: some Sequence<CardSchedulingState>) -> [CardID] {
        staleCardIDs(in: states, activeParameterSetID: parameterSetID)
    }
}
