public import ContentKit
public import LearnCore
internal import Foundation

/// 화면 하나가 그리는 레슨 한 편 — 파싱된 6블록 + 매니페스트가 아는 신원 + 사이드카 파일.
///
/// **목 데이터가 없다.** 유일한 생성 경로가 ``load(pack:lessonID:)`` 이고, 그건 디스크의
/// 콘텐츠 팩을 `LessonParser` 로 실제로 파싱한다. 화면이 못 그리는 레슨은 팩이 깨진
/// 레슨이라는 뜻이고, 그 사실이 여기서 에러로 드러나야 한다.
public nonisolated struct LessonContent: Sendable {
    public var document: LessonDocument
    /// 매니페스트의 제목. 산문에서 뽑지 않는다 — 목록 화면과 같은 문자열이어야 한다.
    public var title: String
    public var trackName: String
    /// 트랙 안에서 이 레슨의 순번(1-기반).
    public var order: Int
    /// 같은 트랙의 전체 레슨 수.
    public var totalInTrack: Int
    public var objectives: [String]
    /// `@Example` 의 기대 stdout 사이드카. 실행 결과와 대조한다.
    public var expectedOutput: String?
    /// `@Task` 의 시작 코드. 에디터 화면이 열릴 때 넘어간다.
    public var starterSource: String?

    public init(
        document: LessonDocument,
        title: String,
        trackName: String,
        order: Int,
        totalInTrack: Int,
        objectives: [String] = [],
        expectedOutput: String? = nil,
        starterSource: String? = nil,
        language: LanguageID? = nil
    ) {
        self.document = document
        self.language = language ?? document.primaryLanguage
        self.title = title
        self.trackName = trackName
        self.order = order
        self.totalInTrack = totalInTrack
        self.objectives = objectives
        self.expectedOutput = expectedOutput
        self.starterSource = starterSource
    }

    /// 학습자가 고른 풀이 언어. 기본값은 레슨이 선언한 첫 언어다({#lesson-language-picker}).
    ///
    /// 개념·퀴즈·돌아보기는 이 값과 무관하고, 예제·빈칸·과제만 갈아탄다.
    public var language: LanguageID
    /// 고른 언어로 본 6블록. 언어가 하나인 레슨에서는 `document.blocks` 와 같다.
    public var blocks: [LessonBlock] { document.blocks(for: language) }
    /// 이 레슨을 풀 수 있는 언어들 — 선택 UI 가 그리는 목록.
    public var languages: [LanguageID] { document.languages }

    /// 팩에서 레슨 하나를 읽어 화면이 쓸 형태로 조립한다.
    ///
    /// 사이드카(기대 출력·시작 코드)가 없으면 **에러를 내지 않고 nil** 로 둔다.
    /// 파일 존재 검증은 `ContentPack.validateReferences()` 의 일이고, 화면은 없는
    /// 사이드카 때문에 열리지 않으면 안 된다.
    public static func load(pack: ContentPack, lessonID: LessonID) throws(ContentPackError)
        -> LessonContent
    {
        guard let entry = pack.manifest.lesson(lessonID) else { throw .unknownLesson(lessonID) }
        let document = try pack.lesson(lessonID)
        let siblings = pack.manifest.lessons(for: entry.primaryLanguage)
        return LessonContent(
            document: document,
            title: entry.title,
            trackName: trackName(for: entry.primaryLanguage),
            order: entry.order,
            totalInTrack: max(siblings.count, entry.order),
            objectives: entry.objectives,
            expectedOutput: document.example(for: entry.primaryLanguage)
                .flatMap { try? pack.text(at: $0.expectedStdoutPath) },
            starterSource: document.task(for: entry.primaryLanguage)
                .flatMap { try? pack.text(at: $0.starterPath) },
            language: entry.primaryLanguage
        )
    }

    /// `LanguageID` → 트랙 이름. 온보딩 화면과 같은 표기를 쓴다.
    public static func trackName(for language: LanguageID) -> String {
        switch language.rawValue {
        case "python": "Python"
        case "sql": "SQL"
        case "swift": "Swift"
        case "rust": "Rust"
        case "cpp": "C++"
        case "go": "Go"
        case "java": "Java"
        case "nextjs": "Next.js"
        case "typescript": "TypeScript"
        case "assembly": "Assembly"
        default: language.rawValue
        }
    }
}
