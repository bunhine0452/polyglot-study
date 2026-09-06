/// 영속화 계층에서만 쓰는 식별자와 시각 표현.
///
/// `Identifiers.swift` 의 도메인 식별자(`CardID`·`PackID`…)는 콘텐츠가 정하는 이름이지만,
/// 여기 있는 것들은 **DB 가 발급한 rowid** 다. 둘을 같은 파일에 두면 "콘텐츠가 정하는 id" 와
/// "DB 가 정하는 id" 의 구분이 흐려진다.

/// UTC epoch 기준 밀리초.
///
/// 시각을 `Date` 가 아니라 정수로 고정하는 이유는 셋이다 — SQLite 가 날짜 타입을 갖지 않고,
/// 정수 비교라 인덱스가 그대로 먹고, `review_log` 를 다른 언어로 리플레이해도 값이 흔들리지 않는다.
/// 하루 경계(롤오버)는 저장이 아니라 **읽는 쪽**의 관심사다 — `LearnScheduling` 이 계산한다.
public typealias EpochMilliseconds = Int64

/// `review_log` 행 식별자.
///
/// 테이블이 `INTEGER PRIMARY KEY AUTOINCREMENT` 라 값이 **절대 재사용되지 않는다**.
/// `card_state.derived_from_log_id` 가 "어디까지 반영했는가" 의 워터마크로 이 단조성에 기댄다.
public struct ReviewLogID: RawRepresentable, Hashable, Sendable, Codable, Comparable {
    public let rawValue: Int64
    public init(rawValue: Int64) { self.rawValue = rawValue }
    public init(_ rawValue: Int64) { self.rawValue = rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct SubmissionID: RawRepresentable, Hashable, Sendable, Codable, Comparable {
    public let rawValue: Int64
    public init(rawValue: Int64) { self.rawValue = rawValue }
    public init(_ rawValue: Int64) { self.rawValue = rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct MistakeNoteID: RawRepresentable, Hashable, Sendable, Codable, Comparable {
    public let rawValue: Int64
    public init(rawValue: Int64) { self.rawValue = rawValue }
    public init(_ rawValue: Int64) { self.rawValue = rawValue }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 스케줄러 파라미터 세트 식별자. 사람이 읽는 문자열이다 (`"fsrs6-default"`).
///
/// 리뷰 한 건이 **어떤 w 로** 스케줄됐는지 소급 설명하려면 이 값이 로그에 박혀 있어야 한다.
public struct ParameterSetID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

extension ParameterSetID {
    /// 마이그레이션 001 이 심는 기본 세트. 활성 세트는 언제나 정확히 하나이며 최초값이 이것이다.
    public static let fsrs6Default = ParameterSetID("fsrs6-default")
}

/// 영속화 계층의 상한값. 실행 계층(`LanguageKit.ResourceLimits`)의 상한과 **다르다**.
public enum PersistenceLimits {
    /// 저장 시 `stdout` / `stderr` 상한 — 64 KiB.
    ///
    /// - Important: 실행 상한인 `ResourceLimits.outputBytes` 는 1 MiB 로 이 값의 16배다.
    ///   두 값이 다른 것은 실수가 아니다. 실행 중에는 사용자가 화면에서 1MB 를 다 보지만,
    ///   DB 에는 "무엇이 틀렸는지 알아볼 만큼" 만 남긴다. 제출은 레슨·블록당 20건씩 쌓이므로
    ///   1MB 를 그대로 넣으면 실패한 블록 하나가 20MB 를 먹는다.
    public static let submissionOutputBytes = 64 * 1024

    /// 실패 제출 보존 개수 — `(pack_id, lesson_id, block_index)` 하나당.
    /// 통과 제출은 개수가 적고 "정답 히스토리" 로서 값이 있으므로 자르지 않는다.
    public static let failedSubmissionRetention = 20

    /// UTF-8 바이트 기준으로 자른다. **문자(Character) 경계에서만** 자르므로 결합 문자나
    /// 이모지가 반쪽으로 깨지지 않는다 — 잘린 문자열은 원본의 올바른 접두사다.
    ///
    /// 잘림 표시를 덧붙이지 않는 이유: 마커를 붙이면 결과가 `maxBytes` 를 넘거나 접두사 성질이
    /// 깨진다. "잘렸다" 는 사실은 원본 길이를 아는 UI 가 판단할 문제다.
    public static func truncateForStorage(
        _ text: String,
        maxBytes: Int = submissionOutputBytes
    ) -> String {
        guard maxBytes > 0 else { return "" }
        guard text.utf8.count > maxBytes else { return text }

        var end = text.startIndex
        var used = 0
        var index = text.startIndex
        while index < text.endIndex {
            let width = text[index].utf8.count
            if used + width > maxBytes { break }
            used += width
            index = text.index(after: index)
            end = index
        }
        return String(text[text.startIndex..<end])
    }
}
