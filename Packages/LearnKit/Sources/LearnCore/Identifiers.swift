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
    public static let cpp = LanguageID("cpp")
    public static let rust = LanguageID("rust")
}

/// 레슨 하나를 **팩까지 포함해** 가리키는 참조.
///
/// `LessonID` 만으로는 레슨을 열 수 없다. 진도의 PK 가 `(pack_id, lesson_id)` 인 것과
/// 같은 이유다 — 트랙마다 팩이 다르면(`polyglot-python`·`polyglot-sql`·`polyglot-swift`)
/// 어느 팩에서 읽을지가 정해지지 않는다. 대시보드가 "다음 레슨" 을 가리킬 때, 조립
/// 루트가 그 레슨을 열 때 이 쌍이 함께 건너간다.
public struct LessonRef: Hashable, Sendable, Codable {
    public let packID: PackID
    public let lessonID: LessonID

    public init(packID: PackID, lessonID: LessonID) {
        self.packID = packID
        self.lessonID = lessonID
    }
}
