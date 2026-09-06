import Foundation
import Testing

import LearnCore
@testable import LearnScheduling

/// `card_state` 재구축 드라이버. `{#card-state-rebuild}` `{#rebuild-transactional}`
///
/// 마이그레이션 006 이 심어 둔 stale 표시를 **실제로 듣는 주체**가 이 스위트의 대상이다.
/// 006 이 `elapsed_days`·`learning_step_index` 를 0 으로 채우고 워터마크를 지운 행이,
/// 재구축을 거쳐 리플레이 값으로 되돌아오는지를 끝에서 끝까지 확인한다.
@Suite("card_state 재구축 드라이버")
struct CardStateRebuildTests {

    // MARK: - 하네스

    /// 스케줄러 + 인메모리 스토어 두 짝. GRDB 구현과 같은 계약을 지키는 페이크다
    /// (`LearnPersistenceTests.CoreContractTests` 가 두 구현을 대조한다).
    struct Harness {
        let scheduler: FSRSReviewScheduler
        let reviewLog: InMemoryReviewLogStore
        let cardStates: InMemoryCardStateStore

        init(scheduler: FSRSReviewScheduler) {
            self.scheduler = scheduler
            // 활성 파라미터 세트는 스케줄러가 실제로 쓰는 세트여야 한다 — 다르면 재구축이
            // 만들어 내는 행이 만들어지자마자 parameter_drift 로 stale 이 된다.
            self.reviewLog = InMemoryReviewLogStore(parameterSets: [
                SchedulerParameterSet(
                    id: scheduler.parameterSetID,
                    schedulerID: scheduler.schedulerID,
                    createdAt: GoldenReviewLog.base,
                    isActive: true
                )
            ])
            self.cardStates = InMemoryCardStateStore(reviewLog: reviewLog)
        }

        func rebuilder(
            scheduler override: (any ReviewScheduler)? = nil,
            cardStates override2: (any CardStateStore)? = nil,
            pageSize: Int = CardStateRebuilder.defaultPageSize
        ) -> CardStateRebuilder {
            CardStateRebuilder(
                scheduler: override ?? scheduler,
                cardStates: override2 ?? cardStates,
                reviewLog: reviewLog,
                pageSize: pageSize
            )
        }

        /// 로그를 **id 순서대로** 넣어 픽스처의 id 를 그대로 재현한다.
        ///
        /// 페이크는 삽입 순서로 id 를 1 부터 발급한다. 골든 픽스처는 일부러 뒤섞여 저장돼
        /// 있으므로 그대로 넣으면 id 가 뒤바뀌고, `derived_from_log_id` 비교가 무의미해진다.
        @discardableResult
        func appendInIDOrder(_ entries: [ReviewLogEntry]) async throws -> [ReviewLogID] {
            let ordered = entries.sorted { ($0.id?.rawValue ?? 0) < ($1.id?.rawValue ?? 0) }
            return try await reviewLog.append(contentsOf: ordered)
        }

        /// 006 직후의 캐시 모양 — 두 컬럼이 0 이고 워터마크가 지워진 행.
        func seedLegacyRows(for cardIDs: [CardID]) async throws {
            for (index, cardID) in cardIDs.enumerated() {
                try await cardStates.upsert(
                    CardStateSnapshot(
                        cardID: cardID,
                        languageID: Self.tracks[index % Self.tracks.count],
                        stability: 1,
                        difficulty: 5,
                        dueAt: GoldenReviewLog.base,
                        lastReviewedAt: nil,
                        phase: .learning,
                        reps: 1,
                        lapses: 0,
                        // 006 이 `NOT NULL DEFAULT 0` 으로 채운 값. 틀렸을 수 있는 0 이다.
                        elapsedDays: 0,
                        scheduledDays: 0,
                        learningStepIndex: 0,
                        // 006 이 지운 워터마크 — "이 행은 어떤 로그도 온전히 반영하지 못했다".
                        derivedFromLogID: nil,
                        parameterSetID: scheduler.parameterSetID,
                        rebuiltAt: GoldenReviewLog.base
                    )
                )
            }
        }

        func allRows() async throws -> [CardStateSnapshot] {
            var rows: [CardStateSnapshot] = []
            for track in Self.tracks {
                rows += try await cardStates.dueCards(
                    languageID: track,
                    dueAtOrBefore: .max,
                    limit: .max
                )
            }
            return rows.sorted { $0.cardID.rawValue < $1.cardID.rawValue }
        }

        static let tracks: [LanguageID] = [.python, .sql, .swift]
    }

    private func scheduler(retention: Double = 0.9) throws -> FSRSReviewScheduler {
        try FSRSReviewScheduler(
            parameters: FSRSParameterSet(requestRetention: retention),
            clock: FixedSchedulerClock(GoldenReviewLog.base)
        )
    }

    /// 골든 로그를 넣고 006 모양의 낡은 캐시를 심은 하네스.
    private func goldenHarness() async throws -> (Harness, [ReviewLogEntry]) {
        let harness = Harness(scheduler: try scheduler())
        let entries = try GoldenReviewLog.loadEntries()
        try await harness.appendInIDOrder(entries)

        // 페이크가 발급한 id 가 픽스처 id 와 같은지 — 아래 모든 비교의 전제다.
        let stored = try await harness.reviewLog.entries(after: nil, limit: .max)
        #expect(
            stored.map(\.id) == entries.sorted { ($0.id?.rawValue ?? 0) < ($1.id?.rawValue ?? 0) }.map(\.id),
            "페이크가 픽스처와 다른 로그 id 를 발급했다 — derived_from_log_id 비교가 무의미해진다"
        )

        let cardIDs = Set(entries.map(\.cardID)).sorted { $0.rawValue < $1.rawValue }
        try await harness.seedLegacyRows(for: cardIDs)
        return (harness, entries)
    }

    /// 카드별 진짜 마지막 로그 id — `.cram` 도 포함한다. `card_state_stale.log_drift` 의 기준.
    private func watermarks(_ entries: [ReviewLogEntry]) -> [CardID: ReviewLogID] {
        var map: [CardID: ReviewLogID] = [:]
        for entry in entries {
            guard let id = entry.id else { continue }
            if let seen = map[entry.cardID], seen >= id { continue }
            map[entry.cardID] = id
        }
        return map
    }

    // MARK: - 골든 회귀 `{#card-state-rebuild}`

    @Test("006 모양의 낡은 캐시를 재구축하면 골든 card_state 가 그대로 나온다")
    func rebuildProducesGoldenCardState() async throws {
        let (harness, entries) = try await goldenHarness()
        let golden = try JSONDecoder().decode(
            CardStateRebuild.self,
            from: try Fixtures.data(GoldenReviewLog.stateFileName)
        )
        let expectedByCard = golden.byCardID
        let watermark = watermarks(entries)

        // 006 이 표시한 stale 이 실제로 잡히는가.
        #expect(try await harness.cardStates.staleCount() == 40)

        let report = try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)
        #expect(report.staleCardCount == 40)
        #expect(report.rebuiltCardCount == 40)
        #expect(report.preservedCardCount == 0)
        #expect(report.appliedEntryCount == golden.appliedEntryCount)
        #expect(report.skippedEntryCount == golden.skippedEntryCount)
        #expect(report.reviewLogCount == 200)

        let rows = try await harness.allRows()
        #expect(rows.count == 40)
        for row in rows {
            guard var expected = expectedByCard[row.cardID] else {
                Issue.record("골든에 없는 카드가 나왔다: \(row.cardID.rawValue)")
                continue
            }
            // 캐시 워터마크는 "반영한 로그" 라 건너뛴 `.cram` 까지 포함한다. 그 한 필드만
            // 순수 리플레이 결과와 다르고, 나머지는 전부 같아야 한다.
            expected.derivedFromLogID = watermark[row.cardID]
            #expect(row.scheduling == expected, "\(row.cardID.rawValue) 의 재구축 결과가 골든과 다르다")
            #expect(row.rebuiltAt == report.rebuiltAt)
        }
    }

    @Test("재구축이 두 새 컬럼을 리플레이 값으로 채운다 — 0 이 남아 있으면 실패")
    func rebuildFillsMigration006Columns() async throws {
        let (harness, entries) = try await goldenHarness()
        try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)

        let rows = try await harness.allRows()
        var byCard: [CardID: CardSchedulingState] = [:]
        for cardID in rows.map(\.cardID) {
            byCard[cardID] = try harness.scheduler.replay(entries.filter { $0.cardID == cardID })
        }

        for row in rows {
            let replayed = try #require(byCard[row.cardID])
            #expect(row.elapsedDays == replayed.elapsedDays, "\(row.cardID.rawValue): elapsed_days")
            #expect(
                row.learningStepIndex == replayed.learningStepIndex,
                "\(row.cardID.rawValue): learning_step_index"
            )
        }
        // 전부 0 이면 위 비교가 통과해도 아무것도 증명하지 못한다.
        #expect(rows.contains { $0.elapsedDays > 0 }, "재구축 후에도 elapsed_days 가 전부 0 이다")
    }

    /// 골든 40장은 전부 `learning_step_index == 0` 으로 끝난다. 006 이 메운 구멍의 본체는
    /// 학습 스텝이므로, 스텝이 0 이 아닌 카드를 따로 세워 되감김이 없는지 못박는다.
    @Test("학습 스텝이 남아 있는 카드도 리플레이 값으로 복구된다")
    func rebuildRestoresNonZeroLearningStep() async throws {
        let harness = Harness(scheduler: try scheduler())
        let cardID = CardID("py-learning")

        // 기본 학습 스텝은 ["1m", "10m"] — 신규 카드를 good 으로 한 번 넘기면 스텝 1 이다.
        let outcome = try harness.scheduler.apply(
            .good,
            to: harness.scheduler.initialState(for: cardID, createdAt: GoldenReviewLog.base),
            at: GoldenReviewLog.base,
            reviewDurationMS: 1_000,
            source: .review
        )
        try await harness.reviewLog.append(outcome.logEntry)
        try await harness.seedLegacyRows(for: [cardID])

        let expected = try harness.scheduler.replay(
            try await harness.reviewLog.entries(forCard: cardID)
        )
        #expect(expected.learningStepIndex > 0, "전제 붕괴: 리플레이가 스텝 0 을 냈다")
        #expect(expected.phase == .learning)

        try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)

        let row = try #require(try await harness.cardStates.snapshot(forCard: cardID))
        #expect(row.learningStepIndex == expected.learningStepIndex)
        #expect(row.elapsedDays == expected.elapsedDays)
        #expect(row.phase == expected.phase)
        #expect(row.scheduling == expected)
    }

    // MARK: - 수렴

    @Test("재구축이 끝나면 stale 이 0 이다 — cram 으로 끝난 카드 포함")
    func rebuildConverges() async throws {
        let (harness, entries) = try await goldenHarness()
        // 마지막 로그가 `.cram` 인 카드가 실제로 있어야 이 테스트가 의미를 갖는다.
        let watermark = watermarks(entries)
        let byID = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            entry.id.map { ($0, entry) }
        })
        let cramTailed = watermark.values.filter { byID[$0]?.source == .cram }.count
        #expect(cramTailed > 0, "cram 으로 끝나는 카드가 없어 워터마크 경로를 시험하지 못한다")

        try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)
        #expect(try await harness.cardStates.staleCount() == 0, "재구축이 수렴하지 않았다")

        // 두 번째 호출은 할 일이 없다.
        let second = try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)
        #expect(second.staleCardCount == 0)
        #expect(second.rebuiltCardCount == 0)
        #expect(second.didRebuild == false)
        #expect(second.preservedCardCount == 40)
    }

    @Test("파라미터 세트가 바뀌면 전량이 stale 이 되고 새 세트로 수렴한다")
    func parameterChangeTriggersFullRebuild() async throws {
        let (harness, _) = try await goldenHarness()
        try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)
        #expect(try await harness.cardStates.staleCount() == 0)

        // 목표 유지율을 올리면 다른 파라미터 세트다 — 40장 전부 parameter_drift 다.
        let tuned = try scheduler(retention: 0.95)
        #expect(tuned.parameterSetID != harness.scheduler.parameterSetID)
        try await harness.reviewLog.save(
            parameterSet: SchedulerParameterSet(
                id: tuned.parameterSetID,
                schedulerID: tuned.schedulerID,
                createdAt: GoldenReviewLog.base,
                isActive: true
            ),
            activate: true
        )
        #expect(try await harness.cardStates.staleCount() == 40)

        let report = try await harness.rebuilder(scheduler: tuned)
            .rebuildStaleCards(in: Harness.tracks)
        #expect(report.rebuiltCardCount == 40)
        #expect(report.parameterSetID == tuned.parameterSetID)
        #expect(try await harness.cardStates.staleCount() == 0)

        let rows = try await harness.allRows()
        #expect(rows.allSatisfy { $0.parameterSetID == tuned.parameterSetID })
    }

    @Test("이력이 없는 카드는 파라미터 표기만 갱신되고 워터마크는 nil 로 남는다")
    func historylessCardIsRefreshedNotReplayed() async throws {
        let harness = Harness(scheduler: try scheduler())
        try await harness.cardStates.upsert(
            CardStateSnapshot(
                cardID: CardID("py-fresh"),
                languageID: .python,
                stability: 0,
                difficulty: 5,
                dueAt: GoldenReviewLog.base,
                lastReviewedAt: nil,
                phase: .new,
                reps: 0,
                lapses: 0,
                elapsedDays: 0,
                scheduledDays: 0,
                learningStepIndex: 0,
                derivedFromLogID: nil,
                parameterSetID: ParameterSetID("stale-set"),
                rebuiltAt: GoldenReviewLog.base
            )
        )
        #expect(try await harness.cardStates.staleCount() == 1)

        let now = GoldenReviewLog.base.adding(days: 1)
        let report = try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks, at: now)
        #expect(report.rebuiltCardCount == 1)
        #expect(report.appliedEntryCount == 0)

        let row = try #require(try await harness.cardStates.snapshot(forCard: CardID("py-fresh")))
        #expect(row.parameterSetID == harness.scheduler.parameterSetID)
        #expect(row.derivedFromLogID == nil)
        #expect(row.rebuiltAt == now)
        #expect(row.phase == .new)
        #expect(try await harness.cardStates.staleCount() == 0)
    }

    // MARK: - 보존

    @Test("stale 이 아닌 행은 스왑을 지나도 한 글자도 바뀌지 않는다")
    func freshRowsSurviveTheSwap() async throws {
        let (harness, _) = try await goldenHarness()
        try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)

        // 카드 하나에만 새 리뷰를 얹는다 — 그 카드만 log_drift 다.
        let target = CardID("card-00")
        let current = try #require(try await harness.cardStates.snapshot(forCard: target))
        let outcome = try harness.scheduler.apply(
            .good,
            to: current.scheduling,
            at: current.dueAt.adding(minutes: 5),
            reviewDurationMS: 900,
            source: .review
        )
        try await harness.reviewLog.append(outcome.logEntry)
        #expect(try await harness.cardStates.staleCount() == 1)

        let before = try await harness.allRows()
        let report = try await harness.rebuilder(pageSize: 8)
            .rebuildStaleCards(in: Harness.tracks, at: GoldenReviewLog.base.adding(days: 7))
        #expect(report.rebuiltCardCount == 1)
        #expect(report.preservedCardCount == 39)

        let after = try await harness.allRows()
        #expect(after.count == before.count)
        for (old, new) in zip(before, after) where old.cardID != target {
            #expect(new == old, "\(old.cardID.rawValue) 이 재구축 대상도 아닌데 바뀌었다")
        }
        #expect(try await harness.cardStates.staleCount() == 0)
    }

    @Test("재구축은 review_log 를 한 행도 건드리지 않는다")
    func rebuildLeavesTheSourceOfTruthAlone() async throws {
        let (harness, entries) = try await goldenHarness()
        let before = try await harness.reviewLog.entries(after: nil, limit: .max)
        try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)
        let after = try await harness.reviewLog.entries(after: nil, limit: .max)
        #expect(after == before)
        #expect(after.count == entries.count)
    }

    // MARK: - 스트리밍

    /// 워터마크를 얻는 두 경로(카드별 질의 / 로그 페이지 스캔)가 같은 결과를 내야 한다.
    /// 분기점은 페이지 크기 하나뿐이라 잘못 고르면 조용히 다른 답이 나온다.
    @Test("페이지 크기와 무관하게 재구축 결과가 같다", arguments: [1, 7, 39, 200, 5_000])
    func rebuildIsIndependentOfPageSize(pageSize: Int) async throws {
        let (baseline, _) = try await goldenHarness()
        try await baseline.rebuilder(pageSize: 5_000).rebuildStaleCards(in: Harness.tracks)
        let expected = try await baseline.allRows()

        let (harness, _) = try await goldenHarness()
        let report = try await harness.rebuilder(pageSize: pageSize)
            .rebuildStaleCards(in: Harness.tracks)
        #expect(try await harness.allRows() == expected)

        // 대상이 페이지보다 많으면 페이지 스캔 경로, 아니면 카드별 질의 경로다.
        if 40 > pageSize {
            #expect(report.scannedEntryCount == 200, "페이지 스캔이 로그를 전부 읽지 않았다")
        } else {
            #expect(report.scannedEntryCount == 0, "카드별 질의 경로인데 로그를 훑었다")
        }
    }

    @Test("페이지 스캔은 한 번에 pageSize 행까지만 읽는다")
    func pageScanNeverReadsTheWholeLogAtOnce() async throws {
        let (harness, _) = try await goldenHarness()
        let spy = PageSpyReviewLogStore(base: harness.reviewLog)
        let rebuilder = CardStateRebuilder(
            scheduler: harness.scheduler,
            cardStates: harness.cardStates,
            reviewLog: spy,
            pageSize: 16
        )
        try await rebuilder.rebuildStaleCards(in: Harness.tracks)

        let pages = await spy.pageSizes
        #expect(!pages.isEmpty, "페이지 스캔 경로를 타지 않았다")
        #expect(pages.allSatisfy { $0 <= 16 }, "페이지 하나가 상한을 넘었다: \(pages)")
        #expect(pages.reduce(0, +) == 200)
    }

    // MARK: - 트랜잭션 `{#rebuild-transactional}`

    @Test("리플레이 도중 실패하면 캐시가 한 행도 바뀌지 않는다")
    func replayFailureLeavesCacheIntact() async throws {
        let (harness, _) = try await goldenHarness()
        let before = try await harness.allRows()
        let countBefore = try await harness.cardStates.count()

        let failing = FailingScheduler(base: harness.scheduler, failOn: CardID("card-17"))
        await #expect(throws: InjectedFailure.self) {
            try await harness.rebuilder(scheduler: failing).rebuildStaleCards(in: Harness.tracks)
        }

        #expect(try await harness.cardStates.count() == countBefore)
        #expect(try await harness.allRows() == before, "실패한 재구축이 캐시를 일부 갈아엎었다")
        #expect(try await harness.cardStates.staleCount() == 40, "여전히 stale 이어야 한다")
    }

    @Test("스왑이 실패하면 기존 행 수가 그대로다 — 드라이버는 스왑 말고는 쓰지 않는다")
    func swapFailureLeavesCacheIntact() async throws {
        let (harness, _) = try await goldenHarness()
        let before = try await harness.allRows()

        let failing = FailingCardStateStore(base: harness.cardStates)
        await #expect(throws: InjectedFailure.self) {
            try await harness.rebuilder(cardStates: failing).rebuildStaleCards(in: Harness.tracks)
        }

        #expect(try await harness.cardStates.count() == before.count)
        #expect(try await harness.allRows() == before)
        // 부분 쓰기 경로 자체를 쓰지 않았다는 것까지 확인한다 — 통째 스왑이 유일한 쓰기다.
        let calls = await failing.mutations
        #expect(calls == ["replaceAll"], "스왑 외의 쓰기가 있었다: \(calls)")
    }

    // MARK: - 거절

    @Test("스케줄러와 DB 의 활성 파라미터 세트가 다르면 던진다")
    func parameterSetMismatchIsRejected() async throws {
        let (harness, _) = try await goldenHarness()
        let other = try scheduler(retention: 0.95)
        await #expect(throws: CardStateRebuildError.self) {
            try await harness.rebuilder(scheduler: other).rebuildStaleCards(in: Harness.tracks)
        }
        #expect(try await harness.cardStates.staleCount() == 40)
    }

    @Test("stale 카드가 트랙 목록 밖이면 던진다 — 통째 스왑이 그 행을 지웠을 것이다")
    func cardOutsideTracksIsRejected() async throws {
        let (harness, _) = try await goldenHarness()
        let countBefore = try await harness.cardStates.count()

        await #expect(throws: CardStateRebuildError.self) {
            try await harness.rebuilder().rebuildStaleCards(in: [.python])
        }
        #expect(try await harness.cardStates.count() == countBefore)
    }

    /// stale 이 아닌 행이 트랙 목록 밖에 있으면 카드별 검사에 걸리지 않는다 — 그 행은
    /// 스왑에서 조용히 사라진다. 행 수 대조가 그 경로를 막는다.
    @Test("stale 이 아닌 행이 트랙 목록 밖에 있어도 던진다")
    func incompleteInventoryIsRejected() async throws {
        let (harness, _) = try await goldenHarness()
        try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)

        // 딱 한 장만 stale 로 만든다. 그 카드의 트랙만 넘기면 나머지 39장이 인벤토리 밖이다.
        let target = try #require(try await harness.cardStates.snapshot(forCard: CardID("card-00")))
        let outcome = try harness.scheduler.apply(
            .good,
            to: target.scheduling,
            at: target.dueAt.adding(minutes: 5),
            reviewDurationMS: 900,
            source: .review
        )
        try await harness.reviewLog.append(outcome.logEntry)

        let countBefore = try await harness.cardStates.count()
        await #expect(throws: CardStateRebuildError.self) {
            try await harness.rebuilder().rebuildStaleCards(in: [target.languageID])
        }
        #expect(try await harness.cardStates.count() == countBefore)
    }

    @Test("stale 이 없으면 아무것도 하지 않고 조용히 돌아온다")
    func noStaleCardsIsANoop() async throws {
        let harness = Harness(scheduler: try scheduler())
        let report = try await harness.rebuilder().rebuildStaleCards(in: Harness.tracks)
        #expect(report.staleCardCount == 0)
        #expect(report.rebuiltCardCount == 0)
        #expect(report.preservedCardCount == 0)
        #expect(report.totalCardCount == 0)
    }
}

// MARK: - 테스트 더블

/// 주입한 실패. 도메인 에러와 섞이지 않도록 전용 타입을 쓴다.
struct InjectedFailure: Error, Equatable {}

/// 지정한 카드의 리플레이에서 던지는 스케줄러.
private struct FailingScheduler: ReviewScheduler {
    let base: FSRSReviewScheduler
    let failOn: CardID

    var schedulerID: String { base.schedulerID }
    var parameterSetID: ParameterSetID { base.parameterSetID }
    var dayBoundary: DayBoundary { base.dayBoundary }
    var clock: any SchedulerClock { base.clock }

    func initialState(for cardID: CardID, createdAt: EpochMillis) -> CardSchedulingState {
        base.initialState(for: cardID, createdAt: createdAt)
    }

    func preview(_ card: CardSchedulingState, at now: EpochMillis) throws -> ReviewPreview {
        try base.preview(card, at: now)
    }

    func apply(
        _ rating: ReviewRating,
        to card: CardSchedulingState,
        at now: EpochMillis,
        reviewDurationMS: Int?,
        source: ReviewLogSource
    ) throws -> ReviewOutcome {
        try base.apply(rating, to: card, at: now, reviewDurationMS: reviewDurationMS, source: source)
    }

    func replay(_ log: [ReviewLogEntry]) throws -> CardSchedulingState {
        try guarded(log) { try base.replay(log) }
    }

    func rebuild(_ log: [ReviewLogEntry]) throws -> CardStateRebuild {
        try guarded(log) { try base.rebuild(log) }
    }

    private func guarded<T>(_ log: [ReviewLogEntry], _ body: () throws -> T) throws -> T {
        if log.contains(where: { $0.cardID == failOn }) { throw InjectedFailure() }
        return try body()
    }
}

/// 스왑에서 던지는 캐시. 어떤 쓰기 경로가 불렸는지도 기록한다.
private actor FailingCardStateStore: CardStateStore {
    private let base: InMemoryCardStateStore
    private(set) var mutations: [String] = []

    init(base: InMemoryCardStateStore) { self.base = base }

    func snapshot(forCard cardID: CardID) async throws -> CardStateSnapshot? {
        try await base.snapshot(forCard: cardID)
    }

    func upsert(_ snapshot: CardStateSnapshot) async throws {
        mutations.append("upsert")
        try await base.upsert(snapshot)
    }

    func count() async throws -> Int { try await base.count() }

    func replaceAll(with snapshots: [CardStateSnapshot]) async throws {
        mutations.append("replaceAll")
        throw InjectedFailure()
    }

    func deleteAll() async throws {
        mutations.append("deleteAll")
        try await base.deleteAll()
    }

    func dueCards(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis,
        limit: Int
    ) async throws -> [CardStateSnapshot] {
        try await base.dueCards(languageID: languageID, dueAtOrBefore: dueAtOrBefore, limit: limit)
    }

    func queue(
        languageID: LanguageID,
        now: EpochMillis,
        studyDayStart: EpochMillis,
        policy: DueQueuePolicy
    ) async throws -> [DueQueueEntry] {
        try await base.queue(
            languageID: languageID,
            now: now,
            studyDayStart: studyDayStart,
            policy: policy
        )
    }

    func staleCards(limit: Int) async throws -> [CardStaleness] {
        try await base.staleCards(limit: limit)
    }

    func staleCount() async throws -> Int { try await base.staleCount() }

    nonisolated func observeDueCount(
        languageID: LanguageID,
        dueAtOrBefore: EpochMillis
    ) -> AsyncThrowingStream<Int, any Error> {
        base.observeDueCount(languageID: languageID, dueAtOrBefore: dueAtOrBefore)
    }
}

/// 페이지 스캔이 실제로 몇 행씩 읽었는지 기록하는 로그 스토어.
private actor PageSpyReviewLogStore: ReviewLogStore {
    private let base: InMemoryReviewLogStore
    private(set) var pageSizes: [Int] = []

    init(base: InMemoryReviewLogStore) { self.base = base }

    @discardableResult
    func append(_ entry: ReviewLogEntry) async throws -> ReviewLogID {
        try await base.append(entry)
    }

    @discardableResult
    func append(contentsOf entries: [ReviewLogEntry]) async throws -> [ReviewLogID] {
        try await base.append(contentsOf: entries)
    }

    func entries(forCard cardID: CardID) async throws -> [ReviewLogEntry] {
        try await base.entries(forCard: cardID)
    }

    func entries(after id: ReviewLogID?, limit: Int) async throws -> [ReviewLogEntry] {
        let page = try await base.entries(after: id, limit: limit)
        pageSizes.append(page.count)
        return page
    }

    func lastEntryID(forCard cardID: CardID) async throws -> ReviewLogID? {
        try await base.lastEntryID(forCard: cardID)
    }

    func count() async throws -> Int { try await base.count() }

    func count(from: EpochMillis, to: EpochMillis) async throws -> Int {
        try await base.count(from: from, to: to)
    }

    func activeParameterSet() async throws -> SchedulerParameterSet {
        try await base.activeParameterSet()
    }

    func parameterSet(id: ParameterSetID) async throws -> SchedulerParameterSet? {
        try await base.parameterSet(id: id)
    }

    func save(parameterSet: SchedulerParameterSet, activate: Bool) async throws {
        try await base.save(parameterSet: parameterSet, activate: activate)
    }

    nonisolated func observeCount() -> AsyncThrowingStream<Int, any Error> {
        base.observeCount()
    }
}
