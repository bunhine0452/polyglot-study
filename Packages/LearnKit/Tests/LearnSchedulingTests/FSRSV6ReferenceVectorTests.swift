import Foundation
import Testing

@testable import LearnScheduling

/// FSRS-6 참조 벡터. `{#fsrs-reference-vectors}` `{#vector-provenance}`
///
/// **출처 사슬** — 이 파일의 오라클 숫자는 우리가 만든 값이 아니다.
///
/// 1. 원본: `open-spaced-repetition/ts-fsrs` 의 `__tests__/FSRS-6.test.ts` (MIT).
///    FSRS-6 레퍼런스 구현의 테스트이고, 이 값들이 FSRS-6 알고리즘의 사실상 정의다.
/// 2. 이식 1차: `open-spaced-repetition/swift-fsrs` 의 `Tests/FSRSTests/FSRSV6Tests.swift`
///    (MIT, 커밋 `4fbaf20184d62f82a9f44f343337c61a2c5483e9`). 업스트림이 ts-fsrs 값을
///    **verbatim** 으로 옮겨 Swift 포팅이 bit-comparable 함을 고정했다.
/// 3. 이식 2차(여기): 벤더 포크가 그 상태에서 표류하지 않았음을 우리 저장소 CI 에서 증명한다.
///
/// 즉 이 스위트가 녹색이면 "우리 벤더 트리 = swift-fsrs@4fbaf20 = ts-fsrs FSRS-6" 이다.
/// 빨간불이 나면 벤더 트리를 건드렸거나 잘못된 커밋을 벤더링한 것이다.
@Suite("FSRS-6 참조 벡터 (ts-fsrs FSRS-6.test.ts)")
struct FSRSV6ReferenceVectorTests {

    /// ts-fsrs FSRS-6 테스트가 쓰는 w. `FSRSDefaults.defaultWv6` 와 같은 값이다.
    let w: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133,
        0.8334, 3.0194, 0.001, 1.8722, 0.1666,
        0.796, 1.4835, 0.0614, 0.2629, 1.6483,
        0.6014, 1.8729, 0.5425, 0.0912, 0.0658,
        0.1542,
    ]

    @Test("체크인된 w 가 벤더 기본값과 동일하다")
    func testWMatchesVendorDefault() {
        expectOracle(w, FSRSDefaults.defaultWv6, oracle: "swift-fsrs FSRSDefaults.defaultWv6")
    }

    // MARK: - first repeat

    @Test("첫 복습 — 4개 rating 의 S·D·상태")
    func firstRepeat() throws {
        let f = FSRS(parameters: FSRSParameters(w: w))
        let card = FSRSDefaults().createEmptyCard()
        let now = utcDate(2022, 12, 29, 12, 30)
        let log = try f.repeat(card: card, now: now)

        var stability: [Double] = []
        var difficulty: [Double] = []
        var reps: [Int] = []
        var lapses: [Int] = []
        var scheduledDays: [Double] = []
        var states: [CardState] = []
        for grade in [Rating.again, .hard, .good, .easy] {
            let card = log[grade]!.card
            stability.append(card.stability)
            difficulty.append(card.difficulty)
            reps.append(card.reps)
            lapses.append(card.lapses)
            scheduledDays.append(card.scheduledDays)
            states.append(card.state)
        }

        expectOracle(stability, [0.212, 1.2931, 2.3065, 8.2956], oracle: "FSRS-6.test.ts › first repeat › stability")
        expectOracle(difficulty[0], 6.4133, oracle: "FSRS-6.test.ts › first repeat › difficulty[again]")
        expectOracle(difficulty[1], 5.11217071, oracle: "FSRS-6.test.ts › first repeat › difficulty[hard]")
        expectOracle(difficulty[2], 2.11810397, oracle: "FSRS-6.test.ts › first repeat › difficulty[good]")
        expectOracle(difficulty[3], 1.0, oracle: "FSRS-6.test.ts › first repeat › difficulty[easy]")
        expectOracle(reps, [1, 1, 1, 1], oracle: "FSRS-6.test.ts › first repeat › reps")
        expectOracle(lapses, [0, 0, 0, 0], oracle: "FSRS-6.test.ts › first repeat › lapses")
        expectOracle(scheduledDays, [0, 0, 0, 8], oracle: "FSRS-6.test.ts › first repeat › scheduled_days")
        expectOracle(
            states, [.learning, .learning, .learning, .review],
            oracle: "FSRS-6.test.ts › first repeat › state"
        )
    }

    // MARK: - interval history

    @Test("13회 리뷰 간격 히스토리 + rollback 왕복 + repeat/next 일치")
    func intervalHistory() throws {
        let f = FSRS(parameters: FSRSParameters(w: w))
        var card = FSRSDefaults().createEmptyCard()
        var now = utcDate(2022, 12, 29, 12, 30)
        var schedulingCards = try f.repeat(card: card, now: now)

        let ratings: [Rating] = [
            .good, .good, .good, .good, .good, .good,
            .again, .again, .good, .good, .good, .good, .good,
        ]

        var ivlHistory: [Int] = []
        for rating in ratings {
            for check in [Rating.again, .hard, .good, .easy] {
                let rollback = try f.rollback(
                    card: schedulingCards[check]!.card,
                    log: schedulingCards[check]!.log
                )
                #expect(rollback == card, "rollback 이 원래 카드로 돌아오지 않았다 — rating \(check)")

                let elapsed = card.lastReview != nil
                    ? Date.dateDiff(now: now, pre: card.lastReview, unit: .days)
                    : 0
                #expect(
                    schedulingCards[check]!.log.elapsedDays == elapsed,
                    "log.elapsedDays 가 실제 경과일과 다르다 — rating \(check)"
                )

                let next = try FSRS(parameters: FSRSParameters(w: w)).next(card: card, now: now, grade: check)
                #expect(
                    schedulingCards[check] == next,
                    "repeat(...)[\(check)] 와 next(..., grade: \(check)) 결과가 다르다"
                )
            }

            card = schedulingCards[rating]!.card
            ivlHistory.append(Int(card.scheduledDays))
            now = card.due
            schedulingCards = try f.repeat(card: card, now: now)
        }

        expectOracle(
            ivlHistory,
            [0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21],
            oracle: "FSRS-6.test.ts › ivl_history"
        )
    }

    // MARK: - memory state

    private func runMemoryStateSequence(enableShortTerm: Bool) throws -> Card {
        let f = FSRS(parameters: FSRSParameters(w: w, enableShortTerm: enableShortTerm))
        var card = FSRSDefaults().createEmptyCard()
        var now = utcDate(2022, 12, 29, 12, 30)
        let ratings: [Rating] = [.again, .good, .good, .good, .good, .good]
        let intervals: [Double] = [0, 0, 1, 3, 8, 21]

        for (index, rating) in ratings.enumerated() {
            now = Date(timeIntervalSince1970: now.timeIntervalSince1970 + intervals[index] * 86_400)
            card = try f.next(card: card, now: now, grade: rating).card
        }
        return card
    }

    @Test("메모리 상태 — 단기 스텝 켜짐")
    func memoryStateShortTerm() throws {
        let card = try runMemoryStateSequence(enableShortTerm: true)
        expectOracle(
            card.stability, 53.62691, tolerance: 1e-4,
            oracle: "FSRS-6.test.ts › memory state (short-term) › stability"
        )
        expectOracle(
            card.difficulty, 6.3574867, tolerance: 1e-4,
            oracle: "FSRS-6.test.ts › memory state (short-term) › difficulty"
        )
    }

    @Test("메모리 상태 — 단기 스텝 꺼짐")
    func memoryStateLongTerm() throws {
        let card = try runMemoryStateSequence(enableShortTerm: false)
        expectOracle(
            card.stability, 53.335106, tolerance: 1e-4,
            oracle: "FSRS-6.test.ts › memory state (long-term) › stability"
        )
        expectOracle(
            card.difficulty, 6.3574867, tolerance: 1e-4,
            oracle: "FSRS-6.test.ts › memory state (long-term) › difficulty"
        )
    }

    // MARK: - learnable decay

    @Test("망각 곡선이 학습된 decay(w[20])를 쓴다")
    func forgettingCurveUsesLearnableDecay() {
        let v5 = FSRS(parameters: FSRSParameters())
        let v6 = FSRS(parameters: FSRSParameters(w: w))

        expectOracle(
            v5.forgettingCurve(elapsedDays: 1, stability: 1), 0.9,
            oracle: "FSRS-6.test.ts › forgetting curve › v5 R(1,1)"
        )
        expectOracle(
            v6.forgettingCurve(elapsedDays: 1, stability: 1), 0.9, tolerance: 1e-4,
            oracle: "FSRS-6.test.ts › forgetting curve › v6 R(1,1)"
        )
        #expect(
            v6.forgettingCurve(elapsedDays: 10, stability: 1)
                > v5.forgettingCurve(elapsedDays: 10, stability: 1),
            "FSRS-6.test.ts › forgetting curve › v6 의 꼬리가 v5 보다 두꺼워야 한다"
        )
        #expect(v5.factor != v6.factor, "FSRS-6.test.ts › factor 가 버전별로 갈려야 한다")
        expectOracle(v5.decay, -0.5, tolerance: 1e-12, oracle: "FSRS-6.test.ts › v5 decay")
        expectOracle(v6.decay, -0.1542, tolerance: 1e-12, oracle: "FSRS-6.test.ts › v6 decay")
    }

    // MARK: - 1일 이상 학습 스텝

    @Test("1일 이상 학습 스텝은 review 로 졸업하며 scheduledDays 를 스텝에서 유도한다")
    func longLearningStepGraduatesToReview() throws {
        let f = FSRS(parameters: FSRSParameters(w: w, enableFuzz: false, learningSteps: ["1m", "2d"]))
        let card = FSRSDefaults().createEmptyCard()
        let now = utcDate(2024, 1, 1, 12)

        let item = try f.next(card: card, now: now, grade: .good)
        expectOracle(item.card.state, .review, oracle: "swift-fsrs V6 › ≥1d step › state")
        expectOracle(item.card.scheduledDays, 2, oracle: "swift-fsrs V6 › ≥1d step › scheduled_days")
        expectOracle(item.card.learningSteps, 1, oracle: "swift-fsrs V6 › ≥1d step › learning_steps")
    }

    @Test("정확히 1440분 스텝도 ≥1일 분기다")
    func exactlyOneDayLearningStepGraduates() throws {
        let f = FSRS(parameters: FSRSParameters(w: w, enableFuzz: false, learningSteps: ["1d"]))
        let card = FSRSDefaults().createEmptyCard()
        let now = utcDate(2024, 1, 1, 12)

        let item = try f.next(card: card, now: now, grade: .again)
        expectOracle(item.card.state, .review, oracle: "swift-fsrs V6 › ==1440m step › state")
        expectOracle(item.card.scheduledDays, 1, oracle: "swift-fsrs V6 › ==1440m step › scheduled_days")
    }
}
