/// 인메모리 페이크 — `review_log` + `scheduler_parameters`.
///
/// GRDB 구현과 **같은 계약**을 지키는 것이 목적이다. 특히 append-only: 이 타입에는 애초에
/// 수정·삭제 메서드가 없다. 스케줄러·UI 테스트가 SQLite 없이 돌 수 있게 하기 위한 것이지,
/// 성능이나 완전한 SQL 의미론을 흉내내려는 것이 아니다.
///
/// `actor` 인 것은 페이크가 가변 상태를 들기 때문이다. GRDB 구현은 **actor 로 감싸지 않는다** —
/// GRDB 7 의 writer 는 이미 `Sendable` 이고 직렬화를 스스로 하므로 actor 는 홉만 늘린다.
public actor InMemoryReviewLogStore: ReviewLogStore {
    private var entries: [ReviewLogEntry] = []
    private var nextID: Int64 = 1
    private var parameterSets: [ParameterSetID: SchedulerParameterSet] = [:]
    private var countObservers = ContinuationRegistry<Int>()

    public init(parameterSets: [SchedulerParameterSet] = [.inMemoryDefault]) {
        for set in parameterSets { self.parameterSets[set.id] = set }
    }

    @discardableResult
    public func append(_ entry: ReviewLogEntry) async throws -> ReviewLogID {
        try await append(contentsOf: [entry])[0]
    }

    @discardableResult
    public func append(contentsOf newEntries: [ReviewLogEntry]) async throws -> [ReviewLogID] {
        for entry in newEntries {
            guard parameterSets[entry.parameterSetID] != nil else {
                throw StoreError.notFound(
                    entity: "scheduler_parameters",
                    id: entry.parameterSetID.rawValue
                )
            }
            try Self.validate(entry)
        }

        var ids: [ReviewLogID] = []
        for var entry in newEntries {
            let id = ReviewLogID(nextID)
            nextID += 1
            entry.id = id
            entries.append(entry)
            ids.append(id)
        }
        countObservers.broadcast(entries.count)
        return ids
    }

    /// 마이그레이션 001 의 CHECK 6종을 그대로 옮긴 것. 두 구현이 같은 입력을 같은 이유로 거부해야 한다.
    private static func validate(_ entry: ReviewLogEntry) throws {
        guard entry.reviewedAt > EpochMillis(0) else {
            throw StoreError.constraint(message: "chk_review_log_reviewed_at")
        }
        guard entry.elapsedDays >= 0,
              entry.scheduledDays >= 0,
              entry.reviewDurationMS >= 0
        else {
            throw StoreError.constraint(message: "chk_review_log_intervals")
        }
        guard !entry.cardID.rawValue.isEmpty else {
            throw StoreError.constraint(message: "chk_review_log_card_id")
        }
    }

    public func entries(forCard cardID: CardID) async throws -> [ReviewLogEntry] {
        entries
            .filter { $0.cardID == cardID }
            .sorted { ($0.reviewedAt, $0.id?.rawValue ?? 0) < ($1.reviewedAt, $1.id?.rawValue ?? 0) }
    }

    public func entries(after id: ReviewLogID?, limit: Int) async throws -> [ReviewLogEntry] {
        let threshold = id?.rawValue ?? 0
        return entries
            .filter { ($0.id?.rawValue ?? 0) > threshold }
            .sorted { ($0.id?.rawValue ?? 0) < ($1.id?.rawValue ?? 0) }
            .prefix(max(0, limit))
            .map { $0 }
    }

    public func lastEntryID(forCard cardID: CardID) async throws -> ReviewLogID? {
        entries.filter { $0.cardID == cardID }.compactMap(\.id).max()
    }

    public func count() async throws -> Int { entries.count }

    public func count(from: EpochMillis, to: EpochMillis) async throws -> Int {
        entries.count { $0.reviewedAt >= from && $0.reviewedAt < to }
    }

    public func activeParameterSet() async throws -> SchedulerParameterSet {
        guard let active = parameterSets.values.first(where: \.isActive) else {
            throw StoreError.notFound(entity: "scheduler_parameters", id: "active")
        }
        return active
    }

    public func parameterSet(id: ParameterSetID) async throws -> SchedulerParameterSet? {
        parameterSets[id]
    }

    public func save(parameterSet: SchedulerParameterSet, activate: Bool) async throws {
        // GRDB 구현이 트랜잭션으로 하는 일을 여기서는 스냅샷·복원으로 흉내낸다.
        let snapshot = parameterSets
        var set = parameterSet
        set.isActive = activate || parameterSet.isActive
        if set.isActive {
            for key in parameterSets.keys { parameterSets[key]?.isActive = false }
        }
        parameterSets[set.id] = set

        let activeCount = parameterSets.values.count(where: \.isActive)
        guard activeCount == 1 else {
            parameterSets = snapshot
            throw StoreError.constraint(
                message: "활성 파라미터 세트는 정확히 하나여야 한다 (시도 결과 \(activeCount)개)"
            )
        }
    }

    nonisolated public func observeCount() -> AsyncThrowingStream<Int, any Error> {
        AsyncThrowingStream { continuation in
            Task { await self.registerCountObserver(continuation) }
        }
    }

    private func registerCountObserver(
        _ continuation: AsyncThrowingStream<Int, any Error>.Continuation
    ) {
        countObservers.add(continuation, current: entries.count)
    }
}

extension SchedulerParameterSet {
    /// 페이크가 기본으로 들고 있는 활성 세트. 마이그레이션 001 의 시드와 같은 id 를 쓴다.
    public static let inMemoryDefault = SchedulerParameterSet(
        id: .fsrs6Default,
        schedulerID: "fsrs6",
        weights: nil,
        desiredRetention: 0.9,
        createdAt: EpochMillis(0),
        isActive: true
    )
}

/// 인메모리 페이크 — `card_state`.
///
/// stale 판정을 하려면 로그를 봐야 하므로 `ReviewLogStore` 를 주입받는다. GRDB 구현에서는
/// 같은 판정이 `card_state_stale` 뷰 하나로 끝난다.
public actor InMemoryCardStateStore: CardStateStore {
    private var snapshots: [CardID: CardStateSnapshot] = [:]
    private let reviewLog: InMemoryReviewLogStore
    private var dueObservers = ContinuationRegistry<Int>()
    private var dueObserverKey: (LanguageID, EpochMillis)?

    public init(reviewLog: InMemoryReviewLogStore) {
        self.reviewLog = reviewLog
    }

    public func snapshot(forCard cardID: CardID) async throws -> CardStateSnapshot? {
        snapshots[cardID]
    }

    public func upsert(_ snapshot: CardStateSnapshot) async throws {
        snapshots[snapshot.cardID] = snapshot
        await broadcastDueCount()
    }

    public func count() async throws -> Int { snapshots.count }

    public func replaceAll(with newSnapshots: [CardStateSnapshot]) async throws {
        snapshots = Dictionary(
            newSnapshots.map { ($0.cardID, $0) },
            uniquingKeysWith: { _, last in last }
        )
        await broadcastDueCount()
    }

    public func deleteAll() async throws {
        snapshots.removeAll()
        await broadcastDueCount()
    }

    public func dueCards(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis,
        limit: Int
    ) async throws -> [CardStateSnapshot] {
        snapshots.values
            .filter { $0.languageID == languageID && $0.dueAt <= dueAtOrBefore }
            .sorted { ($0.dueAt, $0.cardID.rawValue) < ($1.dueAt, $1.cardID.rawValue) }
            .prefix(max(0, limit))
            .map { $0 }
    }

    public func staleCards(limit: Int) async throws -> [CardStaleness] {
        let activeID = try await reviewLog.activeParameterSet().id
        var result: [CardStaleness] = []
        for snapshot in snapshots.values.sorted(by: { $0.cardID.rawValue < $1.cardID.rawValue }) {
            let latest = try await reviewLog.lastEntryID(forCard: snapshot.cardID)
            let staleness = CardStaleness(
                cardID: snapshot.cardID,
                languageID: snapshot.languageID,
                parameterDrift: snapshot.parameterSetID != activeID,
                logDrift: snapshot.derivedFromLogID != latest
            )
            if staleness.isStale { result.append(staleness) }
            if result.count == limit { break }
        }
        return result
    }

    public func staleCount() async throws -> Int {
        try await staleCards(limit: .max).count
    }

    nonisolated public func observeDueCount(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis
    ) -> AsyncThrowingStream<Int, any Error> {
        AsyncThrowingStream { continuation in
            Task { await self.registerDueObserver(continuation, languageID, dueAtOrBefore) }
        }
    }

    private func registerDueObserver(
        _ continuation: AsyncThrowingStream<Int, any Error>.Continuation,
        _ languageID: LanguageID,
        _ dueAtOrBefore: EpochMillis
    ) {
        dueObserverKey = (languageID, dueAtOrBefore)
        dueObservers.add(continuation, current: dueCount(languageID, dueAtOrBefore))
    }

    private func broadcastDueCount() async {
        guard let key = dueObserverKey else { return }
        dueObservers.broadcast(dueCount(key.0, key.1))
    }

    private func dueCount(_ languageID: LanguageID, _ dueAtOrBefore: EpochMillis) -> Int {
        snapshots.values.count { $0.languageID == languageID && $0.dueAt <= dueAtOrBefore }
    }
}
