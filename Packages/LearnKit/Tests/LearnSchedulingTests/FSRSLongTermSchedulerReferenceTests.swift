import Foundation
import Testing

@testable import LearnScheduling

/// 장기(일 단위) 스케줄러 참조 벡터. `{#fsrs-reference-vectors}` `{#vector-provenance}`
///
/// 출처: `swift-fsrs@4fbaf20` 의 `Tests/FSRSTests/FSRSLongTermSchedulerTests.swift` (MIT),
/// 그 원본은 ts-fsrs 의 long-term 스케줄러 테스트다.
///
/// `LongTermScheduler` 는 `enableShortTerm == false` 일 때 **v5·v6 공용**으로 쓰이므로
/// 벤더링 대상에 남겼다. 픽스처가 19개짜리 v5 `w` 를 쓰는 것도 업스트림 그대로다 —
/// 장기 모드는 w17/w18 을 0 으로 접기 때문에 두 버전이 같은 코드 경로를 탄다.
///
/// **이식하지 않은 케이스** — 업스트림의 `stateSwitching` 은 v5 `w` + `enableShortTerm: true`
/// 조합을 섞어 쓴다. 그 조합은 v4/v5 `BasicScheduler` 로 가는데 우리는 그 파일을 벤더링하지
/// 않았다(`{#fsrs-vendor-trim}`). 해당 경로가 조용히 다른 알고리즘으로 넘어가지 않고
/// 실패한다는 사실은 `FSRSVendorPinTests.v5ShortTermIsRejected` 가 대신 못박는다.
@Suite("FSRS 장기 스케줄러 참조 벡터")
struct FSRSLongTermSchedulerReferenceTests {

    static let w: [Double] = [
        0.4197, 1.1869, 3.0412, 15.2441, 7.1434, 0.6477, 1.0007, 0.0674, 1.6597,
        0.1712, 1.1178, 2.0225, 0.0904, 0.3025, 2.1214, 0.2498, 2.9466, 0.4891,
        0.6468,
    ]

    struct Fixture: Sendable, CustomStringConvertible {
        let name: String
        let ratings: [Rating]
        let intervalHistory: [Int]
        let stabilityHistory: [Double]
        let difficultyHistory: [Double]
        var description: String { name }
    }

    static let fixtures: [Fixture] = [
        Fixture(
            name: "test1",
            ratings: [.good, .good, .good, .good, .good, .good, .again, .again, .good, .good, .good, .good, .good],
            intervalHistory: [3, 13, 48, 155, 445, 1158, 17, 3, 11, 37, 112, 307, 773],
            stabilityHistory: [
                3.0412, 13.09130698, 48.15848988, 154.93732625, 445.05562739,
                1158.07779739, 16.63063166, 3.01732209, 11.42247264, 37.37521902,
                111.8752758, 306.5974569, 772.94031572,
            ],
            difficultyHistory: [
                4.49094334, 4.26664289, 4.05746029, 3.86237659, 3.68044154, 3.51076891,
                4.69833071, 5.55956298, 5.26323756, 4.98688448, 4.72915759, 4.4888015,
                4.26464541,
            ]
        ),
        Fixture(
            name: "test2",
            ratings: [.again, .hard, .good, .easy, .again, .hard, .good, .easy],
            intervalHistory: [1, 2, 6, 41, 4, 7, 21, 133],
            stabilityHistory: [
                0.4197, 1.0344317, 5.5356759, 41.0033667, 4.46605519, 6.67743292,
                20.88868155, 132.81849454,
            ],
            difficultyHistory: [
                7.1434, 7.03653841, 6.64066485, 5.92312772, 6.44779861, 6.45995078,
                6.10293922, 5.36588547,
            ]
        ),
        Fixture(
            name: "test3",
            ratings: [.hard, .good, .easy, .again, .hard, .good, .easy, .again],
            intervalHistory: [2, 7, 54, 5, 8, 26, 171, 8],
            stabilityHistory: [
                1.1869, 6.59167572, 53.76078737, 5.0853693, 8.09786749, 25.52991279,
                171.16195166, 8.11072373,
            ],
            difficultyHistory: [
                6.23225985, 5.89059466, 5.14583392, 5.884097, 5.99269555, 5.667177,
                4.91430736, 5.71619151,
            ]
        ),
        Fixture(
            name: "test4",
            ratings: [.good, .easy, .again, .hard, .good, .easy, .again, .hard],
            intervalHistory: [3, 33, 4, 7, 26, 193, 9, 14],
            stabilityHistory: [
                3.0412, 32.65484522, 4.22256838, 7.23250123, 25.52681848, 193.36619432,
                8.63899858, 14.31323884,
            ],
            difficultyHistory: [
                4.49094334, 3.69538259, 4.83221448, 5.12078462, 4.85403286, 4.07165035,
                5.1050878, 5.34697075,
            ]
        ),
        Fixture(
            name: "test5",
            ratings: [.easy, .again, .hard, .good, .easy, .again, .hard, .good],
            intervalHistory: [15, 3, 6, 27, 240, 10, 17, 60],
            stabilityHistory: [
                15.2441, 3.25621013, 6.32684549, 26.56339029, 239.70462771, 9.75621519,
                17.06035531, 59.59547542,
            ],
            difficultyHistory: [
                1.16304343, 2.99573557, 3.59851762, 3.43436666, 2.60045771, 4.03816348,
                4.46259158, 4.24020203,
            ]
        ),
    ]

    @Test("평가 시퀀스가 오라클과 일치한다", arguments: fixtures)
    func sequenceMatchesOracle(fixture: Fixture) throws {
        let parameters = FSRSDefaults().generatorParameters(
            props: FSRSParameters(w: Self.w, enableShortTerm: false)
        )
        let algorithm = FSRS(parameters: parameters)

        var now = utcDate(2022, 12, 29, 12, 30)
        var card = FSRSDefaults().createEmptyCard()
        var intervalHistory: [Int] = []
        var stabilityHistory: [Double] = []
        var difficultyHistory: [Double] = []

        for rating in fixture.ratings {
            let record = try algorithm.repeat(card: card, now: now)[rating]
            let next = try FSRS(parameters: parameters).next(card: card, now: now, grade: rating)
            #expect(record == next, "\(fixture.name): repeat(...)[\(rating)] 와 next(...) 가 다르다")

            card = record!.card
            intervalHistory.append(Int(card.scheduledDays))
            stabilityHistory.append(card.stability)
            difficultyHistory.append(card.difficulty)
            now = card.due
        }

        expectOracle(
            intervalHistory, fixture.intervalHistory,
            oracle: "FSRSLongTermSchedulerTests › \(fixture.name) › ivl_history"
        )
        expectOracle(
            stabilityHistory, fixture.stabilityHistory,
            oracle: "FSRSLongTermSchedulerTests › \(fixture.name) › s_history"
        )
        expectOracle(
            difficultyHistory, fixture.difficultyHistory,
            oracle: "FSRSLongTermSchedulerTests › \(fixture.name) › d_history"
        )
    }

    @Test("getRetrievability 가 방금 본 카드에 100.00% 를 준다")
    func getRetrievability() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let f = FSRS(parameters: FSRSParameters(
            w: [
                0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616,
                0.1544, 1.0824, 1.9813, 0.0953, 0.2975, 2.2042, 0.2407, 2.9466, 0.5034,
                0.6567,
            ],
            enableShortTerm: false
        ))
        let now = formatter.date(from: "2024-08-03 18:15:34")!
        let viewDate = formatter.date(from: "2024-08-03 18:25:34")!

        var card = FSRSDefaults().createEmptyCard(now: now)
        card = try f.repeat(card: card, now: now)[.again]!.card
        expectOracle(
            f.getRetrievability(card: card, now: viewDate).string, "100.00%",
            oracle: "FSRSLongTermSchedulerTests › getRetrievability › 방금 스케줄된 카드"
        )

        card = Card(
            due: formatter.date(from: "2024-08-04 18:15:34")!,
            stability: 0.4072,
            difficulty: 7.2102,
            elapsedDays: 0,
            scheduledDays: 1,
            reps: 1,
            lapses: 0,
            state: .review,
            lastReview: formatter.date(from: "2024-08-03 18:15:34")
        )
        expectOracle(
            f.getRetrievability(card: card, now: viewDate).string, "100.00%",
            oracle: "FSRSLongTermSchedulerTests › getRetrievability › 같은 날 review 카드"
        )
    }
}
