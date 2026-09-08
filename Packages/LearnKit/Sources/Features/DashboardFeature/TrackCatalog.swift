public import LearnCore

/// 트랙 하나의 **커리큘럼 사실** — 이름과 계획된 레슨 총수, 그리고 지금 콘텐츠가 있는지.
///
/// 진도가 아니다. 진도는 `LessonProgressStore` 에서만 오고, 여기 있는 값은 팩이 설치되기
/// 전에도 참인 것들뿐이다. 준비 중인 7트랙이 "26 레슨 · 콘텐츠 준비 중" 을 보여줄 수 있는
/// 이유가 이것 — 총수는 계획이고, 완료 수는 데이터다.
public struct TrackDescriptor: Identifiable, Hashable, Sendable {
    /// 트랙 목록의 키. **언어가 아니다** — 한 언어에 트랙이 여럿일 수 있다({#track-descriptor-pack-id}).
    public let trackID: TrackID
    /// 툴체인 조회와 복습 큐가 쓰는 언어. 트랙을 **식별하지 않는다**.
    ///
    /// 여러 언어로 풀 수 있는 트랙(알고리즘)에서는 이 값이 기본 언어가 된다 — 학습자가
    /// 고른 풀이 언어는 레슨 화면이 따로 들고 있다.
    public let languageID: LanguageID
    /// 이 트랙의 콘텐츠 팩. `nil` 이면 아직 팩이 없다.
    ///
    /// 진도의 PK 가 `(pack_id, lesson_id)` 이므로 진도를 트랙에 붙이려면 이 값이 필요하다.
    /// 언어로 진도를 묶으면 같은 언어의 두 트랙이 서로의 진도를 먹는다.
    public let packID: PackID?
    /// 화면에 보여줄 트랙 이름. `OnboardingModel.trackName(for:)` 와 같은 표기다.
    public let name: String
    /// 이 트랙의 레슨 총수. **진도 칸 수가 정확히 이 값이어야 한다** (`{#screen-dashboard}`).
    public let lessonTotal: Int

    /// 콘텐츠가 있는 트랙. 없으면 흐리게 그린다.
    ///
    /// 저장하지 않고 팩 유무에서 파생시킨다 — 따로 들고 있으면 "콘텐츠는 있다는데 팩이
    /// 없는" 상태를 만들 수 있고, 그러면 진도를 읽을 곳이 없다.
    public var hasContent: Bool { packID != nil }

    public var id: String { trackID.rawValue }

    public init(
        trackID: TrackID,
        languageID: LanguageID,
        packID: PackID?,
        name: String,
        lessonTotal: Int
    ) {
        self.trackID = trackID
        self.languageID = languageID
        self.packID = packID
        self.name = name
        self.lessonTotal = lessonTotal
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
    /// 언어 하나에 트랙 하나인 동안은 `trackID` 가 언어 이름과 같다 — 기존 진도·선택 상태가
    /// 그대로 이어지도록 일부러 맞춘 것이다. 알고리즘처럼 언어와 1:1 이 아닌 트랙이 붙으면
    /// 그때부터 갈라진다.
    public static let all: [TrackDescriptor] = [
        .language(.python, name: "Python", lessonTotal: 24, pack: "polyglot-python"),
        .language(.sql, name: "SQL", lessonTotal: 22, pack: "polyglot-sql"),
        .language(.swift, name: "Swift", lessonTotal: 24, pack: "polyglot-swift"),
        .language(.rust, name: "Rust", lessonTotal: 26, pack: "polyglot-rust"),
        .language(.cpp, name: "C++", lessonTotal: 26, pack: "polyglot-cpp"),
        // 언어와 1:1 이 아닌 첫 트랙 — {#track-descriptor-pack-id} 가 이걸 위해 있었다.
        // 지금은 Rust 로만 풀지만 레슨 하나가 여러 언어의 풀이를 담을 수 있고
        // ({#block-language-variants}), 그때도 트랙은 하나다.
        TrackDescriptor(
            trackID: TrackID("algorithms"),
            languageID: .rust,
            packID: PackID("polyglot-algorithms"),
            name: "알고리즘",
            lessonTotal: 32
        ),
        .language(LanguageID("go"), name: "Go", lessonTotal: 20, pack: nil),
        .language(LanguageID("java"), name: "Java", lessonTotal: 24, pack: nil),
        .language(LanguageID("nextjs"), name: "Next.js", lessonTotal: 18, pack: nil),
        .language(LanguageID("typescript"), name: "TypeScript", lessonTotal: 24, pack: nil),
        .language(LanguageID("assembly"), name: "Assembly", lessonTotal: 20, pack: nil),
    ]

    /// 콘텐츠가 있는 트랙.
    public static var active: [TrackDescriptor] { all.filter(\.hasContent) }

    public static func descriptor(for trackID: TrackID) -> TrackDescriptor? {
        all.first { $0.trackID == trackID }
    }

    /// 이 언어를 쓰는 트랙 전부. 한 언어에 트랙이 여럿일 수 있으므로 배열이다.
    public static func descriptors(using languageID: LanguageID) -> [TrackDescriptor] {
        all.filter { $0.languageID == languageID }
    }
}

extension TrackDescriptor {
    /// 언어와 1:1 인 트랙 — `trackID` 를 언어 이름에서 유도한다.
    static func language(
        _ languageID: LanguageID,
        name: String,
        lessonTotal: Int,
        pack: String?
    ) -> TrackDescriptor {
        TrackDescriptor(
            trackID: TrackID(languageID.rawValue),
            languageID: languageID,
            packID: pack.map { PackID($0) },
            name: name,
            lessonTotal: lessonTotal
        )
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
