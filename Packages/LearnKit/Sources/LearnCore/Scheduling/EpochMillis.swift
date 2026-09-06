/// UTC epoch milliseconds. **모든 스케줄링 시각의 유일한 표현**이다.
///
/// `Date` 가 아니라 정수를 진실의 원천으로 삼는 이유는 리플레이 때문이다. `review_log` 는
/// append-only 이고 `card_state` 는 언제든 버리고 재구축하는 캐시인데, 재구축이 원본 스케줄과
/// 바이트 단위로 일치하려면 로그에 적힌 시각을 **손실 없이** 다시 읽어들일 수 있어야 한다.
/// `Date` 는 `Double` 초라서 저장·복원 과정에서 서브밀리초가 흔들리고, 그 흔들림이 FSRS 퍼즈
/// 시드에 그대로 들어간다 (`LearnScheduling` 의 `Vendor/FSRS/Scheduler/AbstractScheduler.swift`
/// 에서 시드는 `reviewTime.timeIntervalSince1970` 을 문자열로 찍어 만든다). 밀리초 정수는
/// 그 경로를 원천 봉쇄한다.
///
/// 이 타입은 `Foundation` 을 노출하지 않는다 — `Date` 로의 변환은 벤더 FSRS 를 호출하는
/// `LearnScheduling` 경계 안에만 존재한다.
///
/// 인코딩은 단일 정수다 — SQLite `INTEGER` 컬럼과 JSONL 픽스처 양쪽에 1:1 로 대응한다.
public struct EpochMillis: Hashable, Sendable, Comparable, CustomStringConvertible {
    public var value: Int64

    public init(_ value: Int64) { self.value = value }

    public static func < (lhs: EpochMillis, rhs: EpochMillis) -> Bool { lhs.value < rhs.value }

    public var description: String { "\(value)ms" }

    // MARK: - 산술

    public func adding(milliseconds: Int64) -> EpochMillis { EpochMillis(value + milliseconds) }
    public func adding(seconds: Int) -> EpochMillis { adding(milliseconds: Int64(seconds) * 1_000) }
    public func adding(minutes: Int) -> EpochMillis { adding(milliseconds: Int64(minutes) * 60_000) }
    public func adding(days: Int) -> EpochMillis { adding(milliseconds: Int64(days) * 86_400_000) }

    /// `self - other` 를 분 단위로 내림한 값. 음수도 그대로 돌려준다.
    public func minutes(since other: EpochMillis) -> Int {
        let delta = value - other.value
        return Int((delta >= 0 ? delta : delta - 59_999) / 60_000)
    }

    /// `self - other` 를 밀리초로.
    public func milliseconds(since other: EpochMillis) -> Int64 { value - other.value }
}

extension EpochMillis: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
