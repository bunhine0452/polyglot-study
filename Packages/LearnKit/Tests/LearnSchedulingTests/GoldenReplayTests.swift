import Foundation
import Testing

import LearnCore
@testable import LearnScheduling

/// 골든 리플레이 회귀 방지 + 결정성.
/// `{#replay-determinism}` `{#card-state-rebuild}` `{#rebuild-on-param-change}`
///
/// `card_state` 를 "언제든 버리고 재구축 가능한 파생 캐시" 로 취급하려면 두 가지가 참이어야
/// 한다. 이 스위트가 둘 다 못박는다.
///
/// 1. **재구축이 결정적이다** — 같은 로그를 몇 번 돌려도, 어떤 순서로 넣어도 같은 결과.
/// 2. **재구축 결과가 변하지 않는다** — 체크인된 200건 로그의 기대 상태가 고정돼 있다.
@Suite("골든 리플레이")
struct GoldenReplayTests {

    private func scheduler() throws -> FSRSReviewScheduler {
        try FSRSReviewScheduler(clock: FixedSchedulerClock(GoldenReviewLog.base))
    }

    @Test(
        "픽스처 재생성 — LEARNKIT_REGENERATE_GOLDEN=1 일 때만 돈다",
        .enabled(if: GoldenReviewLog.shouldRegenerate, "픽스처 갱신은 명시적으로만 한다")
    )
    func regenerateFixturesOnDemand() throws {
        try GoldenReviewLog.regenerate()
    }

    // MARK: - 픽스처 형태

    @Test("체크인된 골든 로그는 200건 / 40카드다")
    func fixtureShape() throws {
        let entries = try GoldenReviewLog.loadEntries()
        #expect(entries.count == 200, "골든 로그가 200건이 아니다 — \(entries.count)건")
        #expect(Set(entries.map(\.cardID)).count == 40)
        #expect(Set(entries.compactMap(\.logID)).count == 200, "logID 가 유일하지 않다")

        // 파일에는 뒤섞인 순서로 저장돼 있어야 한다 — 리플레이의 정렬 책임을 실제로 시험한다.
        #expect(
            entries.map(\.reviewedAt) != entries.map(\.reviewedAt).sorted(),
            "픽스처가 이미 시간순이라 정렬 경로를 시험하지 못한다"
        )
        // cram 경로도 로그에 실려 있어야 한다.
        #expect(entries.contains { $0.source == .cram })
    }

    @Test("픽스처가 손으로 편집되지 않았다 — 생성기 출력과 바이트 일치")
    func fixtureMatchesGenerator() throws {
        let regenerated = try GoldenReviewLog.encodeJSONL(try GoldenReviewLog.generate())
        let onDisk = try Fixtures.data(GoldenReviewLog.logFileName)
        #expect(
            regenerated == onDisk,
            """
            골든 로그가 생성기 출력과 다르다. 스케줄러를 의도적으로 바꿨다면
            `LEARNKIT_REGENERATE_GOLDEN=1 swift test --filter Golden` 으로 갱신하고,
            **기대 card_state 가 어떻게 달라졌는지** 를 반드시 리뷰해라
            """
        )
    }

    // MARK: - 골든 재구축

    @Test("200건 로그 재구축이 기대 card_state 와 바이트 일치한다")
    func rebuildMatchesGoldenSnapshot() throws {
        let entries = try GoldenReviewLog.loadEntries()
        let rebuild = try scheduler().rebuild(entries)

        var actual = try snapshotEncoder.encode(rebuild)
        actual.append(0x0a)
        let expected = try Fixtures.data(GoldenReviewLog.stateFileName)

        #expect(
            actual == expected,
            """
            골든 재구축 결과가 체크인된 스냅샷과 다르다 — 스케줄링 동작이 바뀌었다는 뜻이다.
            기대: \(expected.count) bytes, 실제: \(actual.count) bytes
            """
        )

        #expect(rebuild.states.count == 40)
        #expect(rebuild.appliedEntryCount + rebuild.skippedEntryCount == 200)
        #expect(rebuild.skippedEntryCount > 0, "cram 건너뛰기 경로가 한 번도 안 탔다")
        #expect(rebuild.states.map(\.cardID.rawValue) == rebuild.states.map(\.cardID.rawValue).sorted())
    }

    @Test("로그가 기록한 마지막 간격이 재구축 결과와 일치한다")
    func loggedIntervalsAgreeWithRebuild() throws {
        let entries = try GoldenReviewLog.loadEntries()
        let byCard = try scheduler().rebuild(entries).byCardID

        var grouped: [CardID: [ReviewLogEntry]] = [:]
        for entry in entries.replayOrdered() where entry.affectsSchedule {
            grouped[entry.cardID, default: []].append(entry)
        }

        for (cardID, cardEntries) in grouped {
            guard let last = cardEntries.last, let state = byCard[cardID] else { continue }
            // `scheduled_days` 는 리플레이 입력이 아니라 기록이다 — 그래서 검산에 쓸 수 있다.
            #expect(
                last.scheduledDays == state.scheduledDays,
                """
                \(cardID.rawValue): 로그의 scheduled_days \(last.scheduledDays) 와 \
                재구축 결과 \(state.scheduledDays) 가 다르다
                """
            )
            #expect(state.lastReviewedAt == last.reviewedAt)
            #expect(state.derivedFromLogID == last.logID)
        }
    }

    // MARK: - 결정성

    @Test("같은 로그를 100회 재구축해도 바이트 단위로 동일하다")
    func rebuildIsDeterministicAcrossHundredRuns() throws {
        let entries = try GoldenReviewLog.loadEntries()
        let scheduler = try scheduler()
        let baseline = try snapshotEncoder.encode(scheduler.rebuild(entries))

        for iteration in 1...100 {
            let snapshot = try snapshotEncoder.encode(scheduler.rebuild(entries))
            #expect(snapshot == baseline, "\(iteration)회차 재구축 결과가 1회차와 다르다")
        }
    }

    @Test("스케줄러 인스턴스를 새로 만들어도 결과가 같다")
    func rebuildIsDeterministicAcrossInstances() throws {
        let entries = try GoldenReviewLog.loadEntries()
        let baseline = try snapshotEncoder.encode(scheduler().rebuild(entries))
        for _ in 0..<10 {
            #expect(try snapshotEncoder.encode(scheduler().rebuild(entries)) == baseline)
        }
    }

    @Test("입력 순서를 뒤섞어도 결과가 같다 — 리플레이가 스스로 전순서를 만든다")
    func rebuildIsOrderIndependent() throws {
        let entries = try GoldenReviewLog.loadEntries()
        let scheduler = try scheduler()
        let baseline = try snapshotEncoder.encode(scheduler.rebuild(entries))

        var random = GoldenReviewLog.SeededRandom(seed: 0xDEAD_BEEF_CAFE_0001)
        for round in 1...20 {
            let shuffled = random.shuffled(entries)
            #expect(
                try snapshotEncoder.encode(scheduler.rebuild(shuffled)) == baseline,
                "\(round)번째 셔플에서 재구축 결과가 달라졌다 — 정렬이 전순서가 아니다"
            )
        }
    }

    @Test("동일 밀리초·logID 없는 행도 입력 순서로 안정 정렬된다")
    func replayOrderingIsTotalEvenWithoutLogIDs() throws {
        let scheduler = try scheduler()
        let at = GoldenReviewLog.base
        func entry(_ rating: ReviewRating) -> ReviewLogEntry {
            ReviewLogEntry(
                logID: nil, cardID: CardID("tie"), reviewedAt: at, rating: rating,
                stateBefore: .new, elapsedDays: 0, scheduledDays: 0,
                schedulerID: scheduler.schedulerID, parameterSetID: scheduler.parameterSetID,
                source: .review
            )
        }
        // 같은 밀리초에 3건. `Swift.sort` 는 안정 정렬이 아니므로 입력 인덱스를 마지막
        // 키로 쓰지 않으면 여기가 실행마다 흔들린다.
        let log = [entry(.again), entry(.good), entry(.easy)]
        let baseline = try scheduler.replay(log)
        for _ in 0..<200 {
            #expect(try scheduler.replay(log) == baseline)
        }
        #expect(log.replayOrdered().map(\.rating) == [.again, .good, .easy])
    }

    // MARK: - 단일 카드 replay 와 일괄 rebuild 의 일치

    @Test("카드별 replay 와 일괄 rebuild 가 같은 상태를 낸다")
    func perCardReplayMatchesBatchRebuild() throws {
        let entries = try GoldenReviewLog.loadEntries()
        let scheduler = try scheduler()
        let byCard = try scheduler.rebuild(entries).byCardID

        var grouped: [CardID: [ReviewLogEntry]] = [:]
        for entry in entries { grouped[entry.cardID, default: []].append(entry) }

        for (cardID, cardEntries) in grouped {
            let single = try scheduler.replay(cardEntries)
            #expect(single == byCard[cardID], "\(cardID.rawValue): replay 와 rebuild 결과가 다르다")
        }
    }

    // MARK: - 파라미터 세트 변경

    @Test("파라미터 세트를 바꾸면 기존 상태가 전부 stale 이 되고 재구축이 다른 값을 낸다")
    func parameterChangeMarksEverythingStaleAndChangesOutcome() throws {
        let entries = try GoldenReviewLog.loadEntries()
        let original = try scheduler()
        let originalRebuild = try original.rebuild(entries)

        // 목표 유지율을 올리면 간격이 짧아진다 — 다른 파라미터 세트다.
        let tuned = try FSRSReviewScheduler(
            parameters: FSRSParameterSet(requestRetention: 0.95),
            clock: FixedSchedulerClock(GoldenReviewLog.base)
        )
        #expect(tuned.parameterSetID != original.parameterSetID)

        // 기존 캐시는 전부 stale — 40장 모두 재구축 대상이다.
        #expect(tuned.staleCards(in: originalRebuild.states).count == 40)

        let tunedRebuild = try tuned.rebuild(entries)
        #expect(tunedRebuild.states.allSatisfy { $0.parameterSetID == tuned.parameterSetID })
        #expect(tuned.staleCards(in: tunedRebuild.states).isEmpty)
        #expect(
            tunedRebuild.states != originalRebuild.states,
            "파라미터를 바꿨는데 재구축 결과가 같다 — 파라미터가 반영되지 않았다"
        )

        // 그리고 새 재구축도 여전히 결정적이어야 한다.
        let baseline = try snapshotEncoder.encode(tunedRebuild)
        for _ in 0..<10 {
            #expect(try snapshotEncoder.encode(tuned.rebuild(entries)) == baseline)
        }
    }
}
