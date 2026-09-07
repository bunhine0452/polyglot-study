public import LearnCore

/// 트랙 하나의 **커리큘럼 사실** — 이름과 계획된 레슨 총수, 그리고 지금 콘텐츠가 있는지.
///
/// 진도가 아니다. 진도는 `LessonProgressStore` 에서만 오고, 여기 있는 값은 팩이 설치되기
/// 전에도 참인 것들뿐이다. 준비 중인 7트랙이 "26 레슨 · 콘텐츠 준비 중" 을 보여줄 수 있는
/// 이유가 이것 — 총수는 계획이고, 완료 수는 데이터다.
public struct TrackDescriptor: Identifiable, Hashable, Sendable {
    public let languageID: LanguageID
    /// 화면에 보여줄 트랙 이름. `OnboardingModel.trackName(for:)` 와 같은 표기다.
    public let name: String
    /// 이 트랙의 레슨 총수. **진도 칸 수가 정확히 이 값이어야 한다** (`{#screen-dashboard}`).
    public let lessonTotal: Int
    /// MVP 범위 — 콘텐츠가 있는 트랙. 나머지는 흐리게 그린다.
    public let hasContent: Bool

    public var id: String { languageID.rawValue }

    public init(languageID: LanguageID, name: String, lessonTotal: Int, hasContent: Bool) {
        self.languageID = languageID
        self.name = name
        self.lessonTotal = lessonTotal
        self.hasContent = hasContent
    }
}

/// 10개 트랙의 커리큘럼 목록.
///
/// 순서는 `OnboardingModel.displayOrder` 와 같다 — 두 화면이 같은 10개를 다른 순서로
/// 나열하면 사용자가 같은 표를 두 번 읽어야 한다. 대시보드는 여기에 **활동 순서**를
/// 한 겹 더 얹는다(`DashboardModel.rows` 참고).
///
/// - Note: `LanguageID` 에 상수가 있는 것은 **실행기와 채점기가 있는 언어**뿐이다
///   (`LearnCore.Identifiers`: python·sql·swift·cpp·rust). 나머지는 여기서 rawValue 로
///   만든다 — 상수를 먼저 만들면 "태울 수 있다" 는 착각을 부른다. 철자는
///   `OnboardingModel.trackName(for:)` 의 `switch` 와 정확히 같아야 한다.
///   `hasContent` 는 팩이 실릴 때까지 false 다. 앱은 콘텐츠가 있는 트랙의 이 값과
///   레슨 총수를 팩에서 다시 읽는다(`Composition.catalog`).
public enum TrackCatalog {
    public static let all: [TrackDescriptor] = [
        TrackDescriptor(languageID: .python, name: "Python", lessonTotal: 24, hasContent: true),
        TrackDescriptor(languageID: .sql, name: "SQL", lessonTotal: 22, hasContent: true),
        TrackDescriptor(languageID: .swift, name: "Swift", lessonTotal: 24, hasContent: true),
        TrackDescriptor(languageID: .rust, name: "Rust", lessonTotal: 26, hasContent: false),
        TrackDescriptor(languageID: .cpp, name: "C++", lessonTotal: 26, hasContent: false),
        TrackDescriptor(languageID: LanguageID("go"), name: "Go", lessonTotal: 20, hasContent: false),
        TrackDescriptor(languageID: LanguageID("java"), name: "Java", lessonTotal: 24, hasContent: false),
        TrackDescriptor(languageID: LanguageID("nextjs"), name: "Next.js", lessonTotal: 18, hasContent: false),
        TrackDescriptor(languageID: LanguageID("typescript"), name: "TypeScript", lessonTotal: 24, hasContent: false),
        TrackDescriptor(languageID: LanguageID("assembly"), name: "Assembly", lessonTotal: 20, hasContent: false),
    ]

    /// 콘텐츠가 있는 트랙 — MVP 3종.
    public static var active: [TrackDescriptor] { all.filter(\.hasContent) }

    public static func descriptor(for languageID: LanguageID) -> TrackDescriptor? {
        all.first { $0.languageID == languageID }
    }
}

/// 6블록 시퀀스의 한국어 이름. `LearnCore.LessonBlockSequence` 가 개수(6)를 정하고
/// 여기서 이름을 붙인다.
///
/// - Note: 이름의 정본은 `ContentKit.LessonBlockKind` 다(concept·example·blank·task·quiz·
///   reflection). 대시보드는 `ContentKit` 에 의존하지 않으므로(타깃 의존은
///   LearnCore·LearnPersistence·DesignSystem 뿐) 한국어 표기만 여기서 다시 적는다.
///   순서와 개수는 `LessonBlockSequence` 에 묶여 있어 어긋나면 테스트가 깨진다.
public enum LessonBlockNames {
    public static let all = ["개념", "실행 예제", "빈칸", "테스트 과제", "퀴즈", "회고"]

    /// 0-기반 인덱스의 블록 이름. 범위 밖이면 `nil`.
    public static func name(at index: Int) -> String? {
        all.indices.contains(index) ? all[index] : nil
    }
}
