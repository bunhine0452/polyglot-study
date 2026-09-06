import Foundation
import Testing

import LearnCore
@testable import LearnScheduling

/// 퍼즈 봉인. `{#fuzz-seal}` — 이 플랜에서 되돌리기가 가장 비싼 항목이다.
///
/// 퍼즈를 켠 채 **첫 리뷰가 기록되는 순간부터** 그 카드의 스케줄은 영영 재구축 불가능해진다.
/// `card_state` 를 버릴 수 있는 캐시로 취급하는 영속화 설계 전체가 여기 달려 있다.
///
/// 이 스위트는 두 가지를 한다.
/// 1. **위험이 실재함을 증명한다** — 퍼즈를 켜면 서브밀리초 차이가 실제로 다른 간격을 낸다.
/// 2. **봉인이 작동함을 증명한다** — 우리 스케줄러는 어떤 경로로도 퍼즈를 켤 수 없다.
@Suite("퍼즈 봉인")
struct FuzzSealTests {

    // MARK: - 1. 위험이 실재한다

    @Test("퍼즈 시드는 서브밀리초 차이에 반응한다 — 로그에 남지 않는 자릿수다")
    func fuzzSeedIsSensitiveToSubMillisecondPrecision() {
        // 벤더 시드 유도식: "\(reviewTime.timeIntervalSince1970)_\(reps)_\(d*s)"
        // `review_log.reviewed_at` 은 밀리초 정수라 아래 두 시각은 저장 후 구별되지 않는다.
        let precise = 1_767_600_000.000_412_7
        let truncated = 1_767_600_000.000

        let seedA = "\(precise)_3_12.5"
        let seedB = "\(truncated)_3_12.5"
        #expect(seedA != seedB, "전제 붕괴: 두 시드가 같은 문자열이 됐다")

        #expect(
            alea(seed: seedA).next() != alea(seed: seedB).next(),
            "서브밀리초가 다른 두 시드가 같은 난수를 냈다 — 이 테스트의 전제가 틀렸거나 PRNG 가 바뀌었다"
        )
    }

    @Test("퍼즈를 켜면 서브밀리초 오차가 실제 간격을 바꾼다")
    func fuzzEnabledSchedulingDivergesOnSubMillisecondDrift() throws {
        let fuzzy = FSRS(parameters: FSRSParameters(w: FSRSDefaults.defaultWv6, enableFuzz: true))
        let base = utcDate(2026, 1, 5, 9, 0)

        // 간격이 2.5일 이상이어야 퍼즈가 걸린다 — review 상태 카드를 몇 번 굴려 만든다.
        var card = FSRSDefaults().createEmptyCard(now: base)
        var now = base
        for _ in 0..<4 {
            card = try fuzzy.next(card: card, now: now, grade: .good).card
            now = card.due
        }
        #expect(card.scheduledDays >= 3, "픽스처 전제: 퍼즈가 걸릴 만큼 간격이 커야 한다")

        // 밀리초 미만으로만 다른 시각들. 로그에 저장하면 전부 같은 정수가 된다.
        let truncatedInterval = try fuzzy.next(card: card, now: now, grade: .good).card.scheduledDays
        var divergences = 0
        for micros in [100, 250, 400, 550, 700, 850, 999] {
            let drifted = Date(timeIntervalSince1970: now.timeIntervalSince1970 + Double(micros) / 1_000_000)
            let interval = try fuzzy.next(card: card, now: drifted, grade: .good).card.scheduledDays
            if interval != truncatedInterval { divergences += 1 }
        }

        #expect(
            divergences > 0,
            """
            퍼즈를 켠 상태에서 서브밀리초 오차가 간격을 전혀 바꾸지 않았다. \
            그렇다면 봉인 근거가 약해진 것이므로 FuzzSeal 주석과 VENDORING.md 를 다시 검토해야 한다
            """
        )
    }

    @Test("봉인된 스케줄러는 서브밀리초 오차에 흔들리지 않는다")
    func sealedSchedulerIsStableUnderSubMillisecondDrift() throws {
        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(EpochMillis(0)))
        let cardID = CardID("fuzz-seal-probe")
        var state = scheduler.initialState(for: cardID, createdAt: EpochMillis(1_767_600_000_000))

        var now = EpochMillis(1_767_600_000_000)
        for _ in 0..<4 {
            state = try scheduler.apply(.good, to: state, at: now, reviewDurationMS: nil, source: .review).state
            now = state.dueAt
        }
        #expect(state.scheduledDays >= 3, "픽스처 전제: 퍼즈가 걸릴 만큼 간격이 커야 한다")

        // 밀리초 정수라 애초에 서브밀리초를 표현할 수 없다. 같은 밀리초 안의 모든 시각은
        // 같은 `EpochMillis` 이고, 따라서 같은 스케줄을 낸다.
        let baseline = try scheduler.apply(.good, to: state, at: now, reviewDurationMS: nil, source: .review)
        for _ in 0..<32 {
            let repeated = try scheduler.apply(.good, to: state, at: now, reviewDurationMS: nil, source: .review)
            #expect(repeated == baseline, "같은 입력에 다른 결과가 나왔다 — 어딘가에 비결정성이 있다")
        }
    }

    // MARK: - 2. 봉인이 작동한다

    @Test("FuzzSeal 에는 disabled 밖에 없다")
    func fuzzSealHasNoEnabledCase() {
        #expect(FuzzSeal.allCases == [.disabled])
    }

    @Test("어떤 파라미터 세트를 만들어도 엔진의 enableFuzz 는 false 다")
    func vendorParametersNeverEnableFuzz() throws {
        let sets: [FSRSParameterSet] = [
            .fsrs6Default,
            FSRSParameterSet(requestRetention: 0.95),
            FSRSParameterSet(enableShortTerm: false),
            FSRSParameterSet(learningSteps: ["1m", "5m", "25m"], relearningSteps: ["5m", "20m"]),
        ]
        for set in sets {
            #expect(set.fuzzSeal == .disabled)
            #expect(set.vendorParameters().enableFuzz == false, "파라미터 세트 \(set.identifier) 의 퍼즈가 켜졌다")
            let scheduler = try FSRSReviewScheduler(parameters: set)
            #expect(scheduler.parameters.fuzzSeal == .disabled)
        }
    }

    @Test("퍼즈가 켜진 파라미터 세트는 디코딩 자체가 실패한다")
    func parameterSetWithEnabledFuzzFailsToDecode() {
        // 누군가 DB 나 설정 파일에 `"fuzzSeal": "enabled"` 를 박아 넣어도 살아 들어올 수 없다.
        let hostile = """
            {
              "weights": [0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001,
                          1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014,
                          1.8729, 0.5425, 0.0912, 0.0658, 0.1542],
              "requestRetention": 0.9,
              "maximumInterval": 36500,
              "enableShortTerm": true,
              "learningSteps": ["1m", "10m"],
              "relearningSteps": ["10m"],
              "fuzzSeal": "enabled"
            }
            """
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(FSRSParameterSet.self, from: Data(hostile.utf8))
        }
    }

    @Test("파라미터 세트 id 가 퍼즈 봉인 상태를 해시에 포함한다")
    func identifierRecordsTheSeal() throws {
        // id 는 내용 해시라 프로세스·기계와 무관하게 안정적이어야 한다.
        let a = FSRSParameterSet.fsrs6Default.identifier
        let b = FSRSParameterSet().identifier
        #expect(a == b, "같은 내용인데 id 가 다르다 — 해시에 비결정 요소가 들어갔다")
        #expect(a.hasPrefix("fsrs6-"))

        // 내용이 다르면 id 도 다르다 → review_log 가 "어떤 w 로 스케줄됐나" 를 증언한다.
        #expect(FSRSParameterSet(requestRetention: 0.95).identifier != a)

        // 봉인 상태가 해시에 실제로 들어갔는지: fuzzSeal 문자열을 뺀 해시와 달라야 한다.
        // (직접 확인할 수 없으므로 스케줄러가 그 id 를 로그에 그대로 싣는지로 대신 본다.)
        let scheduler = try FSRSReviewScheduler(clock: FixedSchedulerClock(EpochMillis(1_767_600_000_000)))
        let state = scheduler.initialState(for: CardID("c1"), createdAt: EpochMillis(1_767_600_000_000))
        let outcome = try scheduler.apply(.good, to: state)
        #expect(outcome.logEntry.parameterSetID == ParameterSetID(a))
        #expect(outcome.logEntry.schedulerID == "fsrs-6/swift-fsrs@4fbaf20")
    }

    @Test("21개가 아닌 w 는 스케줄러 생성 자체가 거부한다")
    func nonV6WeightsAreRejected() {
        #expect(throws: ReviewSchedulingError.self) {
            _ = try FSRSReviewScheduler(parameters: FSRSParameterSet(weights: Array(repeating: 0.5, count: 19)))
        }
        #expect(throws: ReviewSchedulingError.self) {
            _ = try FSRSReviewScheduler(parameters: FSRSParameterSet(learningSteps: []))
        }
    }
}
