import Foundation
public import LearnCore

/// FSRS-6 복습 스케줄러. `{#scheduler-protocol}`
///
/// 벤더 FSRS 는 이 타입 안에서만 존재한다. 밖으로 나가는 것은 `LearnCore` 값 타입뿐이고,
/// `LearnCore` 는 FSRS 를 임포트하지 않는다 — 그래서 `LearnPersistence` 도, UI 도
/// FSRS 를 모른다.
///
/// 값 타입이고 `Sendable` 이다. 벤더 `FSRS` 인스턴스는 생성 후 불변이라 여러 태스크가
/// 같은 스케줄러를 공유해도 안전하다(퍼즈 시드는 리뷰마다 새로 만드는 스케줄러 객체가
/// 들고 있고, 우리는 퍼즈 자체를 봉인했다).
public struct FSRSReviewScheduler: ReviewScheduler {
    /// 스케줄러 신원. 알고리즘 세대 + 벤더 커밋까지 박아서 `review_log` 에 남긴다.
    /// 나중에 "이 행은 어떤 구현이 만들었나" 를 소급 판정할 수 있어야 하기 때문이다.
    public static let identifier = "fsrs-6/swift-fsrs@4fbaf20"

    public let parameters: FSRSParameterSet
    public let dayBoundary: DayBoundary
    public let clock: any SchedulerClock

    private let engine: FSRS

    public var schedulerID: String { Self.identifier }
    public var parameterSetID: String { parameters.identifier }

    /// - Throws: `ReviewSchedulingError.unsupportedAlgorithm` — `w` 가 21개가 아니거나
    ///   학습 스텝이 비어 있는 경우. `ReviewSchedulingError.fuzzNotSealed` — 어떤 경로로든
    ///   퍼즈가 켜진 파라미터가 엔진에 도달한 경우(정상 경로에서는 불가능하지만, 벤더를
    ///   업데이트했을 때 조용히 켜지는 것을 막는 최후 방어선이다).
    public init(
        parameters: FSRSParameterSet = .fsrs6Default,
        dayBoundary: DayBoundary = DayBoundary(),
        clock: any SchedulerClock = SystemSchedulerClock()
    ) throws {
        guard parameters.weights.count == 21 else {
            throw ReviewSchedulingError.unsupportedAlgorithm(
                reason: "FSRS-6 는 21개짜리 w 가 필요하다 — \(parameters.weights.count)개가 들어왔다. "
                    + "19개는 FSRS-5 이고 벤더는 19→21 자동 승격을 하지 않는다"
            )
        }
        if parameters.enableShortTerm && parameters.learningSteps.isEmpty {
            throw ReviewSchedulingError.unsupportedAlgorithm(
                reason: "enableShortTerm 인데 learningSteps 가 비어 있다"
            )
        }

        let engine = FSRS(parameters: parameters.vendorParameters())

        // ── 퍼즈 봉인 검증 `{#fuzz-seal}` ─────────────────────────────────────
        // `FuzzSeal` 에 `.disabled` 밖에 없고 `vendorParameters()` 가 상수 false 를 넣지만,
        // 벤더 업데이트가 기본값을 바꿀 수 있다. 실제로 엔진이 들고 있는 값을 확인한다.
        guard engine.parameters.enableFuzz == false else {
            throw ReviewSchedulingError.fuzzNotSealed(parameterSetID: parameters.identifier)
        }
        guard engine.version == .v6 else {
            throw ReviewSchedulingError.unsupportedAlgorithm(
                reason: "엔진이 FSRS-6 로 해석하지 않았다 — w 길이 \(engine.parameters.w.count)"
            )
        }

        self.parameters = parameters
        self.dayBoundary = dayBoundary
        self.clock = clock
        self.engine = engine
    }

    // MARK: - ReviewScheduler

    public func initialState(for cardID: CardID, createdAt: EpochMillis) -> CardSchedulingState {
        .newCard(cardID, createdAt: createdAt, parameterSetID: parameterSetID)
    }

    public func preview(_ card: CardSchedulingState, at now: EpochMillis) throws -> ReviewPreview {
        let previewLog: IPreview
        do {
            previewLog = try engine.repeat(card: card.vendorCard, now: now.vendorDate)
        } catch {
            throw wrapEngineError(error, cardID: card.cardID)
        }

        func schedule(_ rating: ReviewRating) throws -> ReviewSchedule {
            guard let item = previewLog[rating.vendor] else {
                throw ReviewSchedulingError.engineFailure(
                    cardID: card.cardID,
                    reason: "preview 에 \(rating) 항목이 없다"
                )
            }
            let state = CardSchedulingState(
                vendor: item.card,
                cardID: card.cardID,
                parameterSetID: parameterSetID,
                derivedFromLogID: nil
            )
            return ReviewSchedule(
                rating: rating,
                state: state,
                intervalMinutes: max(0, state.dueAt.minutes(since: now))
            )
        }

        return ReviewPreview(
            cardID: card.cardID,
            evaluatedAt: now,
            again: try schedule(.again),
            hard: try schedule(.hard),
            good: try schedule(.good),
            easy: try schedule(.easy)
        )
    }

    public func apply(
        _ rating: ReviewRating,
        to card: CardSchedulingState,
        at now: EpochMillis,
        reviewDurationMS: Int?,
        source: ReviewLogSource
    ) throws -> ReviewOutcome {
        // 몰아보기는 기록만 남기고 스케줄을 건드리지 않는다. 리플레이도 같은 규칙으로
        // 건너뛰므로 재구축 결과가 원본과 어긋나지 않는다.
        guard source != .cram else {
            let entry = ReviewLogEntry(
                cardID: card.cardID,
                reviewedAt: now,
                rating: rating,
                stateBefore: card.phase,
                elapsedDays: elapsedDays(from: card.lastReviewedAt, to: now),
                scheduledDays: card.scheduledDays,
                reviewDurationMS: reviewDurationMS,
                schedulerID: schedulerID,
                parameterSetID: parameterSetID,
                source: .cram
            )
            return ReviewOutcome(state: card, logEntry: entry)
        }

        let item: RecordLogItem
        do {
            item = try engine.next(card: card.vendorCard, now: now.vendorDate, grade: rating.vendor)
        } catch {
            throw wrapEngineError(error, cardID: card.cardID)
        }

        let state = CardSchedulingState(
            vendor: item.card,
            cardID: card.cardID,
            parameterSetID: parameterSetID,
            derivedFromLogID: nil
        )
        let entry = ReviewLogEntry(
            cardID: card.cardID,
            reviewedAt: now,
            rating: rating,
            stateBefore: card.phase,
            // FSRS 가 계산한 "직전 리뷰로부터 지난 일수". 로그의 기록값이며 리플레이는
            // 이 값을 읽지 않고 시각열에서 다시 계산한다.
            elapsedDays: Int(item.log.elapsedDays.rounded()),
            // 이 리뷰가 **새로 잡은** 간격. 학습 스텝으로 넘어갔으면 0.
            scheduledDays: state.scheduledDays,
            reviewDurationMS: reviewDurationMS,
            schedulerID: schedulerID,
            parameterSetID: parameterSetID,
            source: source
        )
        return ReviewOutcome(state: state, logEntry: entry)
    }

    public func replay(_ log: [ReviewLogEntry]) throws -> CardSchedulingState {
        let ordered = log.replayOrdered()
        guard let first = ordered.first else { throw ReviewSchedulingError.emptyLog }
        for entry in ordered where entry.cardID != first.cardID {
            throw ReviewSchedulingError.mixedCards(expected: first.cardID, found: entry.cardID)
        }
        return try replayOneCard(cardID: first.cardID, ordered: ordered).state
    }

    public func rebuild(_ log: [ReviewLogEntry]) throws -> CardStateRebuild {
        let ordered = log.replayOrdered()

        // 카드별로 잘라 스트리밍 처리한다. 전역 정렬을 먼저 했으므로 각 버킷은 이미
        // 카드 내 시간순이다.
        var buckets: [CardID: [ReviewLogEntry]] = [:]
        for entry in ordered { buckets[entry.cardID, default: []].append(entry) }

        var states: [CardSchedulingState] = []
        states.reserveCapacity(buckets.count)
        var applied = 0
        var skipped = 0

        // 사전 순회 순서는 실행마다 다르다 — 정렬해야 스냅샷이 바이트 단위로 재현된다.
        for cardID in buckets.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let result = try replayOneCard(cardID: cardID, ordered: buckets[cardID] ?? [])
            states.append(result.state)
            applied += result.applied
            skipped += result.skipped
        }

        return CardStateRebuild(
            states: states,
            appliedEntryCount: applied,
            skippedEntryCount: skipped,
            schedulerID: schedulerID,
            parameterSetID: parameterSetID
        )
    }

    // MARK: - 내부

    /// 한 카드의 정렬된 로그를 순수하게 접는다.
    ///
    /// 초기 카드의 `due` 는 첫 리뷰 시각으로 둔다. 새 카드(`state == .new`)의 첫 리뷰에서
    /// FSRS 는 `elapsedDays` 를 0 으로 강제하고 `due` 를 읽지 않으므로, 이 선택은 결과에
    /// 영향을 주지 않으면서 "카드 생성 시각" 이라는 로그에 없는 정보를 요구하지 않는다.
    private func replayOneCard(
        cardID: CardID,
        ordered: [ReviewLogEntry]
    ) throws -> (state: CardSchedulingState, applied: Int, skipped: Int) {
        guard let first = ordered.first else { throw ReviewSchedulingError.emptyLog }

        var card = initialState(for: cardID, createdAt: first.reviewedAt).vendorCard
        var applied = 0
        var skipped = 0
        var derivedFromLogID: Int64?

        for entry in ordered {
            guard entry.affectsSchedule else {
                skipped += 1
                continue
            }
            do {
                card = try engine.next(
                    card: card,
                    now: entry.reviewedAt.vendorDate,
                    grade: entry.rating.vendor
                ).card
            } catch {
                throw wrapEngineError(error, cardID: cardID)
            }
            applied += 1
            derivedFromLogID = entry.logID
        }

        let state = CardSchedulingState(
            vendor: card,
            cardID: cardID,
            parameterSetID: parameterSetID,
            derivedFromLogID: derivedFromLogID
        )
        return (state, applied, skipped)
    }

    /// FSRS 와 같은 정의(UTC 캘린더 일수 차이)로 경과일을 센다. `.cram` 로그 행에만 쓴다.
    private func elapsedDays(from last: EpochMillis?, to now: EpochMillis) -> Int {
        guard let last else { return 0 }
        return Int(Date.dateDiffInDays(from: last.vendorDate, to: now.vendorDate).rounded())
    }
}
