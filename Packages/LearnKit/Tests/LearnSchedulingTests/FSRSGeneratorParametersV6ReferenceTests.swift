import Foundation
import Testing

@testable import LearnScheduling

/// 파라미터 정규화·클램프 참조 벡터. `{#fsrs-reference-vectors}` `{#vector-provenance}`
///
/// 출처: `swift-fsrs@4fbaf20` 의 `Tests/FSRSTests/FSRSGeneratorParametersV6Tests.swift` (MIT).
/// 클램프 범위와 `w17_w18_ceiling` 유도식의 원본은 ts-fsrs 의 `clipParameters` /
/// `CLAMP_PARAMETERS` 다.
///
/// 여기서 가장 중요한 단언은 **19 → 21 자동 승격이 일어나지 않는다**는 것이다.
/// 조용한 승격은 이미 스케줄된 카드의 단기 안정성 계산을 바꿔버린다 — 즉 기존
/// `review_log` 를 리플레이한 결과가 원본과 달라진다.
@Suite("FSRS-6 파라미터 정규화 참조 벡터")
struct FSRSGeneratorParametersV6ReferenceTests {

    @Test("인자 없이 만들면 v5 로 남는다")
    func noArgsStaysOnV5() {
        let parameters = FSRSDefaults().generatorParameters()
        expectOracle(parameters.w.count, 19, oracle: "generatorParameters() › w.count")
        expectOracle(
            FSRSAlgorithmVersion.detect(parameters.w), .v5,
            oracle: "generatorParameters() › version"
        )
    }

    @Test("v6 기본값은 그대로 통과한다")
    func v6DefaultPassesThrough() {
        let parameters = FSRSDefaults().generatorParameters(props: FSRSParameters(w: FSRSDefaults.defaultWv6))
        expectOracle(parameters.w.count, 21, oracle: "generatorParameters(defaultWv6) › w.count")
        expectOracle(
            FSRSAlgorithmVersion.detect(parameters.w), .v6,
            oracle: "generatorParameters(defaultWv6) › version"
        )
        expectOracle(
            parameters.w[20], 0.1542, tolerance: 1e-9,
            oracle: "ts-fsrs FSRS6_DEFAULT_DECAY"
        )
    }

    @Test("레거시 17개는 19개로 마이그레이션된다 (v4 → v5, 변경 없음)")
    func legacy17PathUnchanged() {
        let parameters = FSRSDefaults().generatorParameters(
            props: FSRSParameters(w: Array(repeating: 0.5, count: 17))
        )
        expectOracle(parameters.w.count, 19, oracle: "generatorParameters(17) › w.count")
        expectOracle(
            FSRSAlgorithmVersion.detect(parameters.w), .v5,
            oracle: "generatorParameters(17) › version"
        )
    }

    @Test("19개는 21개로 자동 승격되지 않는다 — 조용한 승격은 스케줄을 바꾼다")
    func length19DoesNotAutoMigrateTo21() {
        let v5w: [Double] = [
            0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575,
            0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655,
            0.6621,
        ]
        let parameters = FSRSDefaults().generatorParameters(props: FSRSParameters(w: v5w))
        expectOracle(parameters.w.count, 19, oracle: "generatorParameters(19) › w.count")
        expectOracle(parameters.w, v5w, oracle: "generatorParameters(19) › w (그대로)")
    }

    @Test("v6 클램프가 decay 를 [0.1, 0.8] 로 가둔다")
    func v6ClampForcesValidRanges() {
        var w = FSRSDefaults.defaultWv6
        w[20] = 5.0
        expectOracle(
            FSRSDefaults().generatorParameters(props: FSRSParameters(w: w)).w[20], 0.8, tolerance: 1e-9,
            oracle: "ts-fsrs CLAMP_PARAMETERS › decay upper"
        )

        w[20] = -1.0
        expectOracle(
            FSRSDefaults().generatorParameters(props: FSRSParameters(w: w)).w[20], 0.1, tolerance: 1e-9,
            oracle: "ts-fsrs CLAMP_PARAMETERS › decay lower"
        )
    }

    @Test("S_MIN 이 버전별로 갈린다 — v5 0.01, v6 0.001")
    func sMinIsVersionDispatched() {
        expectOracle(
            FSRS(parameters: FSRSParameters()).sMin, FSRSDefaults.S_MIN, tolerance: 1e-12,
            oracle: "swift-fsrs S_MIN (v5)"
        )
        expectOracle(
            FSRS(parameters: FSRSParameters(w: FSRSDefaults.defaultWv6)).sMin, FSRSDefaults.S_MIN_V6,
            tolerance: 1e-12,
            oracle: "swift-fsrs S_MIN_V6"
        )
    }

    @Test("w17_w18 천장은 적대적 입력에도 유한하다")
    func ceilingFiniteForOutOfRangeInputs() {
        var w = FSRSDefaults.defaultWv6
        w[11] = -1.0
        w[13] = -0.5
        let ceiling = FSRSDefaults.computeW17W18Ceiling(parameters: w, numRelearningSteps: 2)
        #expect(ceiling.isFinite, "w17_w18 천장이 NaN 이 됐다 — 클램프 테이블 전체가 오염된다")
        #expect(ceiling >= 0.01 && ceiling <= 2.0, "w17_w18 천장 \(ceiling) 이 [0.01, 2.0] 밖이다")
    }

    @Test("잘못된 학습 스텝 문자열은 조용히 졸업시키지 않고 던진다")
    func malformedLearningStepThrows() {
        let f = FSRS(
            parameters: FSRSParameters(w: FSRSDefaults.defaultWv6, learningSteps: ["1m", "bogus"])
        )
        #expect(throws: FSRSError.self) {
            _ = try f.next(card: FSRSDefaults().createEmptyCard(), now: Date(), grade: .good)
        }
    }

    @Test("v6 의 factor 는 decay 에서 유도된다 — decay 0.5 면 v5 와 같아진다")
    func factorIsDerivedFromDecayInV6() {
        let v5 = FSRS(parameters: FSRSParameters())
        expectOracle(v5.factor, 19.0 / 81.0, tolerance: 1e-12, oracle: "FSRS-6.test.ts › v5 factor 19/81")

        var w = FSRSDefaults.defaultWv6
        w[20] = 0.5
        let equivalent = FSRS(parameters: FSRSParameters(w: w))
        expectOracle(
            equivalent.factor, 19.0 / 81.0, tolerance: 1e-7,
            oracle: "FSRS-6.test.ts › v6 factor(decay=0.5) == 19/81"
        )
        expectOracle(equivalent.decay, -0.5, tolerance: 1e-12, oracle: "FSRS-6.test.ts › v6 decay(w20=0.5)")
    }

    // MARK: - 스텝 파서 (swift-fsrs FSRSStepsTests)

    @Test(
        "스텝 단위 파싱",
        arguments: [("1m", 1), ("10m", 10), ("1h", 60), ("2h", 120), ("1d", 1_440), ("0m", 0)]
    )
    func stepUnitParsing(step: String, minutes: Int) throws {
        expectOracle(
            try convertStepUnitToMinutes(step), minutes,
            oracle: "ts-fsrs learning_steps › convertStepUnitToMinutes(\"\(step)\")"
        )
    }

    @Test("망가진 스텝 단위는 던진다", arguments: ["5x", "", "m", "-1m", "abc"])
    func malformedStepUnitThrows(step: String) {
        #expect(throws: FSRSError.self) { _ = try convertStepUnitToMinutes(step) }
    }
}
