import Foundation

/// FSRS 퍼즈 봉인. **케이스가 하나뿐인 것이 핵심이다.** `{#fuzz-seal}`
///
/// FSRS 의 퍼즈는 같은 날 몰린 카드를 흩뜨리려고 간격에 ±5~15% 난수를 섞는 기능이다.
/// 이 앱에서는 켤 수 없다.
///
/// 왜냐면 벤더 스케줄러의 퍼즈 시드가 이렇게 만들어지기 때문이다
/// (`Vendor/FSRS/Scheduler/AbstractScheduler.swift`):
///
/// ```swift
/// seed = "\(reviewTime.timeIntervalSince1970)_\(current.reps)_\(current.difficulty * current.stability)"
/// ```
///
/// `timeIntervalSince1970` 은 `Double` 초다. 실제 리뷰는 나노초 단위 정밀도의 `Date()` 로
/// 스케줄되지만 `review_log.reviewed_at` 은 **밀리초 정수**로 저장된다. 즉 원본 시드 문자열은
/// 로그에 남지 않는다 — 서브밀리초 자릿수가 잘려나가고, 잘린 시각으로 다시 돌린 replay 는
/// 다른 시드를, 다른 난수를, 다른 간격을 낸다. 한 번 퍼즈가 켜진 채 첫 리뷰가 기록되는
/// 순간부터 `card_state` 는 **영원히 재구축 불가능한 원본 데이터**가 된다.
/// 그러면 "card_state 는 버릴 수 있는 캐시" 라는 이 앱 영속화 설계의 전제가 통째로 무너진다.
///
/// 대안이었던 "card_id 해시로 시드 고정" 은 채택하지 않았다. 시드를 카드에 묶으면 같은
/// 카드의 모든 리뷰가 같은 난수를 쓰게 되어 퍼즈의 목적(같은 날 카드 분산)이 사라지고,
/// 벤더 트리를 수정해야 해서 업스트림 추적 비용도 늘어난다. MVP 규모(레슨 70개, 카드 수천
/// 단위)에서 하루 복습량이 몰려 문제가 될 여지도 없다.
///
/// 이 결정은 코드 밖에도 남는다 — `FSRSParameterSet.identifier` 가 봉인 상태를 해시에
/// 포함하므로 `review_log.parameter_set_id` 와 `scheduler_parameters` 행에 그대로 기록된다.
/// 나중에 누가 퍼즈를 켜면 파라미터 세트 id 가 달라지고, 기존 로그는 "퍼즈 봉인 세트로
/// 스케줄됐음" 을 계속 증언한다.
public enum FuzzSeal: String, Hashable, Sendable, Codable, CaseIterable {
    /// 퍼즈 없음. 유일한 선택지다.
    case disabled
}

/// FSRS-6 파라미터 한 세트. `scheduler_parameters` 테이블 한 행에 대응한다.
///
/// `w` 는 반드시 21개다 — 19개는 FSRS-5 이고, 벤더는 19→21 자동 승격을 **의도적으로**
/// 하지 않는다(조용한 승격은 스케줄을 바꾼다). 19개짜리를 넘기면 스케줄러 생성이 실패한다.
public struct FSRSParameterSet: Hashable, Sendable, Codable {
    /// FSRS-6 기본 w (21개).
    ///
    /// 출처는 벤더의 `FSRSDefaults.defaultWv6`, 그 원본은 ts-fsrs 의 FSRS-6 기본
    /// 파라미터다. 개인화 옵티마이저는 리뷰 1,000건 이후 2단계 — `VENDORING.md` 참고.
    public static let defaultWeightsV6: [Double] = FSRSDefaults.defaultWv6
    /// 기본 학습 스텝 `["1m", "10m"]`.
    public static let defaultLearningStepsV6: [String] = FSRSDefaults.defaultLearningSteps
    /// 기본 재학습 스텝 `["10m"]`.
    public static let defaultRelearningStepsV6: [String] = FSRSDefaults.defaultRelearningSteps

    /// 기본 FSRS-6 세트.
    public static let fsrs6Default = FSRSParameterSet()

    /// 21개.
    public var weights: [Double]
    /// 목표 기억 유지율. 기본 0.9.
    public var requestRetention: Double
    /// 최대 간격(일). 기본 36500 (=100년).
    public var maximumInterval: Double
    /// 분 단위 학습 스텝을 쓸지. 끄면 첫 리뷰부터 일 단위 장기 스케줄러로 간다.
    public var enableShortTerm: Bool
    /// 예: `["1m", "10m"]`.
    public var learningSteps: [String]
    /// 예: `["10m"]`.
    public var relearningSteps: [String]
    /// 항상 `.disabled`. 위 `FuzzSeal` 주석 참고.
    public var fuzzSeal: FuzzSeal

    public init(
        weights: [Double] = FSRSParameterSet.defaultWeightsV6,
        requestRetention: Double = 0.9,
        maximumInterval: Double = 36_500,
        enableShortTerm: Bool = true,
        learningSteps: [String] = FSRSParameterSet.defaultLearningStepsV6,
        relearningSteps: [String] = FSRSParameterSet.defaultRelearningStepsV6
    ) {
        self.weights = weights
        self.requestRetention = requestRetention
        self.maximumInterval = maximumInterval
        self.enableShortTerm = enableShortTerm
        self.learningSteps = learningSteps
        self.relearningSteps = relearningSteps
        self.fuzzSeal = .disabled
    }

    /// 내용에서 유도한 안정 식별자. `review_log.parameter_set_id` 로 쓴다.
    ///
    /// `Hasher` 는 프로세스마다 시드가 달라서 못 쓴다. 부동소수는 문자열 포매팅을 거치지 않고
    /// **비트 패턴**을 그대로 먹여 로케일·정밀도 문제를 아예 없앤다. 같은 파라미터면 어느
    /// 기계, 어느 실행에서도 같은 id 가 나온다.
    public var identifier: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325  // FNV-1a 64 offset basis
        func feed(_ bytes: some Sequence<UInt8>) {
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3  // FNV-1a 64 prime
            }
        }
        func feed(_ text: String) { feed(Array(text.utf8)); feed([0x1f]) }
        func feed(_ value: Double) { feed(withUnsafeBytes(of: value.bitPattern.littleEndian, Array.init)) }

        feed("fsrs6")
        feed("w")
        for weight in weights { feed(weight) }
        feed("retention"); feed(requestRetention)
        feed("maxIvl"); feed(maximumInterval)
        feed("shortTerm"); feed(enableShortTerm ? "1" : "0")
        feed("learn"); for step in learningSteps { feed(step) }
        feed("relearn"); for step in relearningSteps { feed(step) }
        feed("fuzz"); feed(fuzzSeal.rawValue)

        return "fsrs6-" + String(hash, radix: 16, uppercase: false)
    }

    /// 벤더 파라미터로 변환. 퍼즈는 여기서 **무조건** 꺼진다.
    func vendorParameters() -> FSRSParameters {
        FSRSParameters(
            requestRetention: requestRetention,
            maximumInterval: maximumInterval,
            w: weights,
            enableFuzz: false,  // FuzzSeal.disabled — 다른 값이 들어갈 경로가 없다
            enableShortTerm: enableShortTerm,
            learningSteps: learningSteps,
            relearningSteps: relearningSteps
        )
    }
}
