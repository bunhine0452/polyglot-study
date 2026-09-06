internal import GRDB
internal import LearnCore

/// GRDB 행 구조체는 DTO 와 **따로** 둔다.
///
/// 두 가지를 산다. 첫째, `LearnCore` 의 값 타입에 GRDB 프로토콜을 retroactive 하게 붙이지 않아도 된다
/// — 애초에 **붙일 수도 없다**. public 타입의 준수는 public 이고, Swift 6 는 public 준수에
/// public import 를 요구하는데 `public import GRDB` 는 `{#grdb-pin}` 이 금지한다
/// (`DomainColumns.swift` 의 `EpochMillis` 주석 참고).
/// 둘째, 컬럼명·컬럼값 드리프트가 허용된다 — SQL 관례와 Swift 관례가 각자 자연스러운 이름을
/// 쓰고(`review_duration_ms` ↔ `reviewDurationMS`), 표현이 달라도(정수 `CardPhase` ↔ TEXT
/// `state`) 매핑이 `DomainColumns.swift` 한 곳에 모인다.
///
/// 대가는 이 파일의 보일러플레이트다. 값이 있는 대가라고 본다 — 매핑이 명시적이라
/// 컬럼을 하나 바꿨을 때 컴파일러가 정확히 여기를 가리킨다.

// MARK: - review_log

struct ReviewLogRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "review_log"

    var id: Int64?
    var cardID: String
    var reviewedAt: Int64
    var rating: Int
    var stateBefore: String
    var elapsedDays: Int
    var scheduledDays: Int
    var reviewDurationMS: Int
    var schedulerID: String
    var parameterSetID: String
    var source: String

    init(row: Row) {
        id = row["id"]
        cardID = row["card_id"]
        reviewedAt = row["reviewed_at"]
        rating = row["rating"]
        stateBefore = row["state_before"]
        elapsedDays = row["elapsed_days"]
        scheduledDays = row["scheduled_days"]
        reviewDurationMS = row["review_duration_ms"]
        schedulerID = row["scheduler_id"]
        parameterSetID = row["parameter_set_id"]
        source = row["source"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["card_id"] = cardID
        container["reviewed_at"] = reviewedAt
        container["rating"] = rating
        container["state_before"] = stateBefore
        container["elapsed_days"] = elapsedDays
        container["scheduled_days"] = scheduledDays
        container["review_duration_ms"] = reviewDurationMS
        container["scheduler_id"] = schedulerID
        container["parameter_set_id"] = parameterSetID
        container["source"] = source
    }

    init(_ entry: ReviewLogEntry) {
        id = entry.id?.rawValue
        cardID = entry.cardID.rawValue
        reviewedAt = entry.reviewedAt.sqlValue
        rating = entry.rating.rawValue
        stateBefore = entry.stateBefore.sqlText
        elapsedDays = entry.elapsedDays
        scheduledDays = entry.scheduledDays
        reviewDurationMS = entry.reviewDurationMS
        schedulerID = entry.schedulerID
        parameterSetID = entry.parameterSetID.rawValue
        source = entry.source.sqlText
    }

    func toEntry() throws -> ReviewLogEntry {
        guard let rating = ReviewRating(rawValue: rating) else {
            throw StoreError.storage(message: "review_log.rating 값이 도메인 밖이다: \(rating)")
        }
        guard let stateBefore = CardPhase(sqlText: stateBefore) else {
            throw StoreError.storage(message: "review_log.state_before: \(stateBefore)")
        }
        guard let source = ReviewLogSource(sqlText: source) else {
            throw StoreError.storage(message: "review_log.source: \(source)")
        }
        return ReviewLogEntry(
            id: id.map { ReviewLogID($0) },
            cardID: CardID(cardID),
            reviewedAt: EpochMillis(sqlValue: reviewedAt),
            rating: rating,
            stateBefore: stateBefore,
            elapsedDays: elapsedDays,
            scheduledDays: scheduledDays,
            reviewDurationMS: reviewDurationMS,
            schedulerID: schedulerID,
            parameterSetID: ParameterSetID(parameterSetID),
            source: source
        )
    }
}

// MARK: - scheduler_parameters

struct SchedulerParameterRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "scheduler_parameters"

    var id: String
    var schedulerID: String
    /// JSON 배열 문자열 또는 nil. nil 은 "스케줄러 내장 기본 가중치".
    var weights: String?
    var desiredRetention: Double
    var createdAt: Int64
    var isActive: Bool

    init(row: Row) {
        id = row["id"]
        schedulerID = row["scheduler_id"]
        weights = row["weights"]
        desiredRetention = row["desired_retention"]
        createdAt = row["created_at"]
        isActive = row["is_active"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["scheduler_id"] = schedulerID
        container["weights"] = weights
        container["desired_retention"] = desiredRetention
        container["created_at"] = createdAt
        container["is_active"] = isActive
    }

    init(_ set: SchedulerParameterSet) throws {
        id = set.id.rawValue
        schedulerID = set.schedulerID
        weights = try set.weights.map(JSONArray.encode)
        desiredRetention = set.desiredRetention
        createdAt = set.createdAt.sqlValue
        isActive = set.isActive
    }

    func toParameterSet() throws -> SchedulerParameterSet {
        SchedulerParameterSet(
            id: ParameterSetID(id),
            schedulerID: schedulerID,
            weights: try weights.map(JSONArray.decodeDoubles),
            desiredRetention: desiredRetention,
            createdAt: EpochMillis(sqlValue: createdAt),
            isActive: isActive
        )
    }
}

// MARK: - card_state

struct CardStateRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "card_state"

    var cardID: String
    var languageID: String
    var stability: Double
    var difficulty: Double
    var dueAt: Int64
    var lastReviewedAt: Int64?
    var state: String
    var reps: Int
    var lapses: Int
    var scheduledDays: Int
    var derivedFromLogID: Int64?
    var parameterSetID: String
    var rebuiltAt: Int64

    init(row: Row) {
        cardID = row["card_id"]
        languageID = row["language_id"]
        stability = row["stability"]
        difficulty = row["difficulty"]
        dueAt = row["due_at"]
        lastReviewedAt = row["last_reviewed_at"]
        state = row["state"]
        reps = row["reps"]
        lapses = row["lapses"]
        scheduledDays = row["scheduled_days"]
        derivedFromLogID = row["derived_from_log_id"]
        parameterSetID = row["parameter_set_id"]
        rebuiltAt = row["rebuilt_at"]
    }

    func encode(to container: inout PersistenceContainer) {
        container["card_id"] = cardID
        container["language_id"] = languageID
        container["stability"] = stability
        container["difficulty"] = difficulty
        container["due_at"] = dueAt
        container["last_reviewed_at"] = lastReviewedAt
        container["state"] = state
        container["reps"] = reps
        container["lapses"] = lapses
        container["scheduled_days"] = scheduledDays
        container["derived_from_log_id"] = derivedFromLogID
        container["parameter_set_id"] = parameterSetID
        container["rebuilt_at"] = rebuiltAt
    }

    init(_ snapshot: CardStateSnapshot) {
        cardID = snapshot.cardID.rawValue
        languageID = snapshot.languageID.rawValue
        stability = snapshot.stability
        difficulty = snapshot.difficulty
        dueAt = snapshot.dueAt.sqlValue
        lastReviewedAt = snapshot.lastReviewedAt?.sqlValue
        state = snapshot.phase.sqlText
        reps = snapshot.reps
        lapses = snapshot.lapses
        scheduledDays = snapshot.scheduledDays
        derivedFromLogID = snapshot.derivedFromLogID?.rawValue
        parameterSetID = snapshot.parameterSetID.rawValue
        rebuiltAt = snapshot.rebuiltAt.sqlValue
    }

    /// - Important: `CardSchedulingState.elapsedDays` 와 `learningStepIndex` 는 컬럼이 없어
    ///   0 으로 되살아난다. 두 값은 로그 리플레이로만 정확히 복원된다 —
    ///   `CardStateSnapshot` 의 경고 참고.
    func toSnapshot() throws -> CardStateSnapshot {
        guard let phase = CardPhase(sqlText: state) else {
            throw StoreError.storage(message: "card_state.state: \(state)")
        }
        return CardStateSnapshot(
            cardID: CardID(cardID),
            languageID: LanguageID(languageID),
            stability: stability,
            difficulty: difficulty,
            dueAt: EpochMillis(sqlValue: dueAt),
            lastReviewedAt: lastReviewedAt.map(EpochMillis.init(sqlValue:)),
            phase: phase,
            reps: reps,
            lapses: lapses,
            scheduledDays: scheduledDays,
            derivedFromLogID: derivedFromLogID.map { ReviewLogID($0) },
            parameterSetID: ParameterSetID(parameterSetID),
            rebuiltAt: EpochMillis(sqlValue: rebuiltAt)
        )
    }
}
