public import LearnCore

/// `card_state` 재구축 드라이버. `{#card-state-rebuild}` `{#rebuild-transactional}`
///
/// ## 왜 이 타입이 필요한가
///
/// 마이그레이션 006 은 `elapsed_days`·`learning_step_index` 를 추가하면서 기존 행을 전부
/// stale 로 표시했다(`derived_from_log_id = NULL`). 표시는 정확했지만 **그 표시를 읽어
/// 재구축을 돌리는 주체가 없었다** — 006 이 심어 둔 신호가 아무도 듣지 않는 채로 남아 있었다.
/// 이 타입이 그 주체다.
///
/// ## 세 단계
///
/// 1. **무엇이 뒤처졌나** — `card_state_stale` 뷰(`CardStateStore.staleCards(limit:)`)가
///    `log_drift`·`parameter_drift` 로 답한다. 재구축 대상 판정은 이 뷰가 유일한 근거다.
/// 2. **카드별 스트리밍 리플레이** — 카드 하나의 이력만 손에 들고 `ReviewScheduler.rebuild(_:)`
///    를 부른다. 22.8만 행 규모에서 로그를 통째로 메모리에 올리지 않기 위한 것이고,
///    워터마크 수집도 `ReviewLogStore.entries(after:limit:)` 로 페이지 단위로 한다.
/// 3. **한 트랜잭션 스왑** — `CardStateStore.replaceAll(with:)` 하나로 끝낸다. 도중 어디서
///    실패해도 기존 캐시가 그대로 남는다. 반쯤 재구축된 캐시는 due 큐가 조용히 카드를
///    빠뜨리는 상태이고, 그건 사용자가 며칠 뒤에나 알아채는 종류의 사고다.
///
/// ## 트랙 목록을 왜 받는가
///
/// `replaceAll` 은 **통째 교체**라 유지할 행까지 손에 들고 있어야 한다. 그런데
/// `CardStateStore` 에는 "모든 행" 열거가 없다 — 큐 쿼리가 언제나 언어로 먼저 좁히도록
/// 설계됐기 때문이다(`{#due-queue-benchmark}`). 그래서 인벤토리는 트랙별
/// `dueCards(languageID:dueAtOrBefore:limit:)` 를 합쳐서 만든다. 트랙 목록은 앱이 안다.
///
/// ## 워터마크는 "적용한 로그" 가 아니라 "반영한 로그" 다
///
/// 순수 리플레이(`ReviewScheduler.rebuild(_:)`)가 돌려주는 `derivedFromLogID` 는 **스케줄에
/// 적용된** 마지막 행이라 `.cram` 으로 끝난 카드에서는 그 앞 행을 가리킨다. 반면
/// `card_state_stale.log_drift` 는 `MAX(review_log.id)` 와 비교하므로, 그 값을 그대로 쓰면
/// 몰아보기로 끝난 카드가 **재구축 직후에도 stale** 로 남는다 — 재구축이 수렴하지 않는다.
/// 캐시 워터마크의 뜻은 "이 행이 어디까지의 로그를 반영했는가" 이고, 건너뛰기로 반영한
/// `.cram` 행도 반영은 반영이다. 그래서 스왑 직전에 워터마크만 진짜 마지막 id 로 덮는다.
/// 스케줄러 쪽은 건드리지 않는다 — 골든 리플레이 스냅샷의 정의가 거기 걸려 있다.
public struct CardStateRebuilder: Sendable {
    /// 로그를 훑을 때의 페이지 크기이자, 워터마크를 어떻게 얻을지 정하는 분기점.
    public static let defaultPageSize = 500

    public let scheduler: any ReviewScheduler
    public let cardStates: any CardStateStore
    public let reviewLog: any ReviewLogStore
    /// 1 이상. `entries(after:limit:)` 한 번이 읽는 행 수다.
    public let pageSize: Int

    public init(
        scheduler: any ReviewScheduler,
        cardStates: any CardStateStore,
        reviewLog: any ReviewLogStore,
        pageSize: Int = CardStateRebuilder.defaultPageSize
    ) {
        self.scheduler = scheduler
        self.cardStates = cardStates
        self.reviewLog = reviewLog
        self.pageSize = max(1, pageSize)
    }

    // MARK: - 조회

    /// 지금 뒤처진 행 수. `card_state_stale` 그대로다.
    public func staleCount() async throws -> Int {
        try await cardStates.staleCount()
    }

    /// 뒤처진 행 목록. `log_drift` 와 `parameter_drift` 를 나눠 들고 온다.
    public func staleCards(limit: Int = .max) async throws -> [CardStaleness] {
        try await cardStates.staleCards(limit: limit)
    }

    // MARK: - 재구축

    /// stale 로 표시된 행을 `review_log` 에서 다시 만들고, 나머지는 그대로 둔 채
    /// 캐시를 **한 트랜잭션**으로 갈아끼운다.
    ///
    /// 파라미터 세트가 바뀐 경우도 이 경로로 덮인다 — `parameter_drift` 가 모든 행을 stale 로
    /// 만들기 때문에 별도의 "전량 재구축" 진입점이 필요 없다 (`{#rebuild-on-param-change}`).
    ///
    /// - Parameters:
    ///   - tracks: 캐시가 담고 있는 트랙 전부. 하나라도 빠지면 그 트랙의 행이 스왑에서
    ///     사라지므로, 빠진 트랙에 stale 행이 있으면 던진다.
    ///   - now: 새 행의 `rebuiltAt`. 기본값은 스케줄러 클록의 "지금".
    /// - Returns: 무엇을 몇 개 만졌는지. 재구축이 필요 없었으면 전부 0 이다.
    @discardableResult
    public func rebuildStaleCards(
        in tracks: [LanguageID],
        at now: EpochMillis? = nil
    ) async throws -> CardStateRebuildReport {
        let rebuiltAt = now ?? scheduler.clock.now()

        // 스케줄러가 보는 파라미터 세트와 DB 의 활성 세트가 다르면, 재구축이 만들어 내는 행이
        // 만들어지자마자 parameter_drift 로 stale 이 된다. 조용히 헛도는 대신 여기서 멈춘다.
        let active = try await reviewLog.activeParameterSet()
        guard active.id == scheduler.parameterSetID else {
            throw CardStateRebuildError.parameterSetMismatch(
                scheduler: scheduler.parameterSetID,
                active: active.id
            )
        }

        let stale = try await cardStates.staleCards(limit: .max)
        let logCountBefore = try await reviewLog.count()
        guard !stale.isEmpty else {
            return CardStateRebuildReport(
                staleCardCount: 0,
                rebuiltCardCount: 0,
                preservedCardCount: try await cardStates.count(),
                appliedEntryCount: 0,
                skippedEntryCount: 0,
                scannedEntryCount: 0,
                reviewLogCount: logCountBefore,
                rebuiltAt: rebuiltAt,
                schedulerID: scheduler.schedulerID,
                parameterSetID: scheduler.parameterSetID
            )
        }

        let inventory = try await inventory(in: tracks)
        let known = Set(inventory.map(\.cardID))
        for card in stale where !known.contains(card.cardID) {
            throw CardStateRebuildError.cardOutsideTracks(
                cardID: card.cardID,
                languageID: card.languageID
            )
        }
        // stale 이 아닌 행이 트랙 목록 밖에 있으면 위 검사에 걸리지 않는다 — 그리고 통째
        // 스왑이 그 행을 조용히 지운다. 행 수로 인벤토리가 완전한지 확인한다.
        let cachedCount = try await cardStates.count()
        guard inventory.count == cachedCount else {
            throw CardStateRebuildError.incompleteInventory(
                found: inventory.count,
                cached: cachedCount
            )
        }

        let targets = Set(stale.map(\.cardID))
        let scan = try await watermarks(for: targets)

        var rows: [CardStateSnapshot] = []
        rows.reserveCapacity(inventory.count)
        var rebuilt = 0
        var preserved = 0
        var applied = 0
        var skipped = 0

        // 인벤토리는 `cardID` 오름차순이다 — 스왑 입력이 실행마다 같은 순서여야 재구축
        // 결과를 바이트로 비교할 수 있다.
        for existing in inventory {
            guard targets.contains(existing.cardID) else {
                rows.append(existing)
                preserved += 1
                continue
            }

            // 카드 하나의 이력만 손에 든다. 이게 "카드별 스트리밍" 의 실제 모습이다.
            let entries = try await reviewLog.entries(forCard: existing.cardID)
            guard !entries.isEmpty else {
                // 이력이 없는데 stale 이면 원인은 parameter_drift 뿐이다. 이력 없는 카드의
                // 알고리즘 상태는 파라미터와 무관하므로 세트 표기만 갱신하면 수렴한다.
                var row = existing
                row.parameterSetID = scheduler.parameterSetID
                row.derivedFromLogID = nil
                row.rebuiltAt = rebuiltAt
                rows.append(row)
                rebuilt += 1
                continue
            }

            let replayed = try scheduler.rebuild(entries)
            applied += replayed.appliedEntryCount
            skipped += replayed.skippedEntryCount
            guard var state = replayed.states.first else {
                throw CardStateRebuildError.emptyReplay(cardID: existing.cardID)
            }
            // 워터마크는 건너뛴 `.cram` 까지 포함한 진짜 마지막 행이다 (타입 주석 참고).
            state.derivedFromLogID = scan.map[existing.cardID] ?? state.derivedFromLogID
            rows.append(
                CardStateSnapshot(
                    scheduling: state,
                    languageID: existing.languageID,
                    rebuiltAt: rebuiltAt
                )
            )
            rebuilt += 1
        }

        // 여기까지 캐시에는 아무것도 쓰지 않았다. 위에서 던졌으면 기존 행이 그대로 남는다.
        try await cardStates.replaceAll(with: rows)

        // `{#derived-rebuild-idiom}` — 파생 재구축은 진실의 원천을 건드리지 않는다.
        let logCountAfter = try await reviewLog.count()
        guard logCountBefore == logCountAfter else {
            throw CardStateRebuildError.reviewLogChanged(
                before: logCountBefore,
                after: logCountAfter
            )
        }

        return CardStateRebuildReport(
            staleCardCount: stale.count,
            rebuiltCardCount: rebuilt,
            preservedCardCount: preserved,
            appliedEntryCount: applied,
            skippedEntryCount: skipped,
            scannedEntryCount: scan.scanned,
            reviewLogCount: logCountAfter,
            rebuiltAt: rebuiltAt,
            schedulerID: scheduler.schedulerID,
            parameterSetID: scheduler.parameterSetID
        )
    }

    // MARK: - 내부

    /// 캐시가 지금 들고 있는 행 전부를 `cardID` 오름차순으로.
    private func inventory(in tracks: [LanguageID]) async throws -> [CardStateSnapshot] {
        var rows: [CardStateSnapshot] = []
        for track in tracks {
            rows += try await cardStates.dueCards(
                languageID: track,
                dueAtOrBefore: .max,
                limit: .max
            )
        }
        return rows.sorted { $0.cardID.rawValue < $1.cardID.rawValue }
    }

    /// 대상 카드들의 마지막 `review_log` id.
    ///
    /// 얻는 방법이 두 가지인 이유는 비용이 정반대이기 때문이다. 몇 장이면 카드별 질의가
    /// 압도적으로 싸고(질의 3번 vs 로그 전량 훑기), 전량 재구축이면 페이지 스캔이 압도적으로
    /// 싸다(페이지 2천 번 vs 카드별 질의 22.8만 번). 분기점은 페이지 크기 하나로 둔다.
    private func watermarks(
        for targets: Set<CardID>
    ) async throws -> (map: [CardID: ReviewLogID], scanned: Int) {
        guard targets.count > pageSize else {
            var map: [CardID: ReviewLogID] = [:]
            for cardID in targets.sorted(by: { $0.rawValue < $1.rawValue }) {
                map[cardID] = try await reviewLog.lastEntryID(forCard: cardID)
            }
            return (map.compactMapValues { $0 }, 0)
        }

        var map: [CardID: ReviewLogID] = [:]
        var cursor: ReviewLogID?
        var scanned = 0
        while true {
            let page = try await reviewLog.entries(after: cursor, limit: pageSize)
            guard !page.isEmpty else { break }
            scanned += page.count

            for entry in page {
                guard let id = entry.id, targets.contains(entry.cardID) else { continue }
                if let seen = map[entry.cardID], seen >= id { continue }
                map[entry.cardID] = id
            }

            // id 오름차순이라 마지막 행이 다음 커서다. id 가 없는 로그(메모리 페이크의
            // 비정상 입력)를 만나면 커서가 전진하지 못하므로 무한 루프 대신 멈춘다.
            guard let next = page.compactMap(\.id).max(), next != cursor else { break }
            cursor = next
            if page.count < pageSize { break }
        }
        return (map, scanned)
    }
}

/// 재구축 한 번이 남기는 기록.
///
/// 숫자를 전부 남기는 이유는 "재구축이 돌았다" 와 "재구축이 무언가를 했다" 가 다르기
/// 때문이다. stale 이 0 이면 이 타입은 전부 0 을 들고 조용히 돌아온다.
public struct CardStateRebuildReport: Hashable, Sendable, Codable {
    /// 재구축 직전 `card_state_stale` 에 걸려 있던 행 수.
    public var staleCardCount: Int
    /// 실제로 다시 만든 행 수.
    public var rebuiltCardCount: Int
    /// 뒤처지지 않아 그대로 옮긴 행 수.
    public var preservedCardCount: Int
    /// 스케줄에 반영된 로그 행 수(재구축한 카드들 기준).
    public var appliedEntryCount: Int
    /// `.cram` 이라 건너뛴 로그 행 수.
    public var skippedEntryCount: Int
    /// 워터마크 페이지 스캔이 읽은 로그 행 수. 카드별 질의 경로였으면 0 이다.
    public var scannedEntryCount: Int
    /// 재구축 전후로 같아야 하는 `review_log` 행 수.
    public var reviewLogCount: Int
    public var rebuiltAt: EpochMillis
    public var schedulerID: String
    public var parameterSetID: ParameterSetID

    public init(
        staleCardCount: Int,
        rebuiltCardCount: Int,
        preservedCardCount: Int,
        appliedEntryCount: Int,
        skippedEntryCount: Int,
        scannedEntryCount: Int,
        reviewLogCount: Int,
        rebuiltAt: EpochMillis,
        schedulerID: String,
        parameterSetID: ParameterSetID
    ) {
        self.staleCardCount = staleCardCount
        self.rebuiltCardCount = rebuiltCardCount
        self.preservedCardCount = preservedCardCount
        self.appliedEntryCount = appliedEntryCount
        self.skippedEntryCount = skippedEntryCount
        self.scannedEntryCount = scannedEntryCount
        self.reviewLogCount = reviewLogCount
        self.rebuiltAt = rebuiltAt
        self.schedulerID = schedulerID
        self.parameterSetID = parameterSetID
    }

    /// 스왑 후 캐시에 남은 행 수.
    public var totalCardCount: Int { rebuiltCardCount + preservedCardCount }
    /// 이번 호출이 캐시를 실제로 바꿨는가.
    public var didRebuild: Bool { rebuiltCardCount > 0 }
}

/// 재구축이 실패하는 방식.
public enum CardStateRebuildError: Error, Hashable, Sendable, CustomStringConvertible {
    /// 스케줄러의 파라미터 세트가 DB 의 활성 세트와 다르다 — 만들자마자 stale 이 될 행이다.
    case parameterSetMismatch(scheduler: ParameterSetID, active: ParameterSetID)
    /// stale 카드가 `tracks` 밖에 있다. 그대로 진행하면 통째 스왑이 그 행을 지운다.
    case cardOutsideTracks(cardID: CardID, languageID: LanguageID)
    /// 트랙별로 모은 인벤토리가 캐시 행 수보다 적다 — 트랙 목록에 빠진 것이 있다.
    case incompleteInventory(found: Int, cached: Int)
    /// 로그가 있는데 리플레이가 상태를 하나도 내지 않았다. 스케줄러 계약 위반이다.
    case emptyReplay(cardID: CardID)
    /// 재구축이 `review_log` 를 건드렸다. `{#derived-rebuild-idiom}`
    case reviewLogChanged(before: Int, after: Int)

    public var description: String {
        switch self {
        case let .parameterSetMismatch(scheduler, active):
            return """
                스케줄러의 파라미터 세트 '\(scheduler.rawValue)' 가 DB 의 활성 세트 \
                '\(active.rawValue)' 와 다르다 — 재구축해도 parameter_drift 가 걷히지 않는다
                """
        case let .cardOutsideTracks(cardID, languageID):
            return """
                stale 카드 \(cardID.rawValue) 의 트랙 '\(languageID.rawValue)' 이 재구축 \
                대상 트랙 목록에 없다 — 통째 스왑이 그 행을 지웠을 것이다
                """
        case let .incompleteInventory(found, cached):
            return """
                트랙별로 모은 행이 \(found)개인데 캐시에는 \(cached)개가 있다 — 트랙 목록에 \
                빠진 것이 있고, 그대로 스왑하면 그 행들이 사라진다
                """
        case let .emptyReplay(cardID):
            return "카드 \(cardID.rawValue) 의 로그가 있는데 리플레이 결과가 비었다"
        case let .reviewLogChanged(before, after):
            return "파생 재구축이 review_log 를 건드렸다: \(before) → \(after)"
        }
    }
}
