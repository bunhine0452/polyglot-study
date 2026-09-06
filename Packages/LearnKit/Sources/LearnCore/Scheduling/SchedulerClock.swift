import Foundation

/// 스케줄러가 "지금" 을 얻는 유일한 통로. 테스트는 고정 클록을 꽂는다.
///
/// 스케줄러가 `Date()` 를 직접 부르면 참조 벡터 테스트도, 리플레이 결정성도 성립하지 않는다.
/// 시각은 언제나 밖에서 들어온다.
public protocol SchedulerClock: Sendable {
    func now() -> EpochMillis
}

/// 실제 벽시계.
public struct SystemSchedulerClock: SchedulerClock {
    public init() {}
    public func now() -> EpochMillis {
        EpochMillis(Int64((Date().timeIntervalSince1970 * 1_000).rounded()))
    }
}

/// 테스트·리플레이용 고정 클록.
public struct FixedSchedulerClock: SchedulerClock {
    public var instant: EpochMillis
    public init(_ instant: EpochMillis) { self.instant = instant }
    public func now() -> EpochMillis { instant }
}

/// 하루 경계. 기본 롤오버는 **로컬 04:00** 이다.
///
/// 새벽 1시에 푼 복습은 "어제" 로 세는 게 학습자의 직관에 맞는다. Anki 의 `rollover` 설정과
/// 같은 개념이고, 여기서만 그 정책을 정의한다 — 큐 쿼리·통계·연속일수 전부 이 타입을 통과한다.
///
/// 주의: **롤오버는 FSRS 계산에 개입하지 않는다.** FSRS 의 `elapsed_days` 는 UTC 캘린더 일수
/// 차이로 벤더 코드가 스스로 계산하고, 그게 업스트림 참조 벡터와 일치하는 유일한 정의다.
/// 롤오버는 "오늘 볼 카드" 를 고르는 표현 계층 정책이다.
public struct DayBoundary: Hashable, Sendable, Codable {
    public static let defaultRolloverHour = 4

    /// 0...23. 이 시각 이전은 전날로 센다.
    public var rolloverHour: Int
    /// `nil` 이면 시스템 현재 시간대. 테스트는 항상 명시한다.
    public var timeZoneIdentifier: String?

    public init(rolloverHour: Int = DayBoundary.defaultRolloverHour, timeZoneIdentifier: String? = nil) {
        self.rolloverHour = min(max(rolloverHour, 0), 23)
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZoneIdentifier, let zone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = zone
        }
        return calendar
    }

    private func shifted(_ instant: EpochMillis) -> Date {
        Date(timeIntervalSince1970: Double(instant.value) / 1_000 - Double(rolloverHour) * 3_600)
    }

    /// 이 시각이 속한 학습일의 서수(1970-01-01 = 0). 값 자체보다 **비교와 차이**에 쓴다.
    /// DST 로 하루가 23시간이나 25시간이 되어도 서수는 정확히 1씩 움직인다.
    public func studyDay(containing instant: EpochMillis) -> Int {
        let calendar = self.calendar
        // 주의: `Calendar.ordinality(of: .day, in: .era,)` 를 쓰면 안 된다. macOS 26 의
        // Foundation 에서 로컬 날짜가 달라도 같은 값을 돌려주는 경우가 있다(Asia/Seoul 에서
        // 2026-01-05 와 2026-01-06 이 둘 다 739621). `startOfDay` 는 정확하므로
        // 로컬 자정끼리의 캘린더 일수 차이로 센다.
        let localMidnight = calendar.startOfDay(for: shifted(instant))
        let epochMidnight = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.dateComponents([.day], from: epochMidnight, to: localMidnight).day ?? 0
    }

    /// 이 시각이 속한 학습일의 시작(= 그 날 롤오버 시각).
    public func startOfStudyDay(containing instant: EpochMillis) -> EpochMillis {
        let calendar = self.calendar
        let localMidnight = calendar.startOfDay(for: shifted(instant))
        let start = calendar.date(byAdding: .hour, value: rolloverHour, to: localMidnight) ?? localMidnight
        return EpochMillis(Int64((start.timeIntervalSince1970 * 1_000).rounded()))
    }

    /// 두 시각이 같은 학습일인가.
    public func isSameStudyDay(_ lhs: EpochMillis, _ rhs: EpochMillis) -> Bool {
        studyDay(containing: lhs) == studyDay(containing: rhs)
    }
}
