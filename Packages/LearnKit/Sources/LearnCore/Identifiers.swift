/// 도메인 식별자. 전부 문자열 래퍼이지만 서로 섞이지 않도록 타입을 나눈다.
///
/// `LessonID` 는 콘텐츠 팩이 갱신돼도 **절대 바뀌지 않는다** — 학습 진도가
/// `(PackID, LessonID)` 로 참조되므로 여기가 흔들리면 진도가 고아가 된다.
public struct LanguageID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct PackID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct LessonID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct CardID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

extension LanguageID {
    public static let python = LanguageID("python")
    public static let sql = LanguageID("sql")
    public static let swift = LanguageID("swift")
}
