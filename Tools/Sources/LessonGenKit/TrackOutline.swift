public import LearnCore

/// 트랙 개요 — `tracks/<lang>.outline.json` 의 내용.
///
/// 레슨 본문 이전 단계다. 여기서 확정되는 것은 **무엇을 어떤 순서로 가르치는가**
/// 하나뿐이고, 사람이 리뷰해 커밋한 뒤에야 `lessongen lesson` 이 이 파일을 읽는다.
///
/// 팩 포맷(`{#pack-format-spec}`)은 아직 없다. 그래서 이 스키마는 자체 정의이고,
/// 팩 매니페스트를 **참조하지 않는다**. 다만 식별자만은 `LearnCore` 의 것을 쓴다 —
/// 나중에 맞물릴 지점이 거기이기 때문이다.
public struct TrackOutline: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var language: LanguageID
    public var trackTitle: String
    public var trackSummary: String
    /// 이 개요를 뽑은 모델 ID. 시각은 **일부러 넣지 않는다** — 넣으면 같은 입력으로
    /// 두 번 구운 파일의 바이트가 달라지고 리뷰 diff 가 매번 더러워진다.
    public var generatorModel: String
    public var lessons: [LessonOutline]

    public init(
        schemaVersion: Int = TrackOutline.currentSchemaVersion,
        language: LanguageID,
        trackTitle: String,
        trackSummary: String,
        generatorModel: String,
        lessons: [LessonOutline]
    ) {
        self.schemaVersion = schemaVersion
        self.language = language
        self.trackTitle = trackTitle
        self.trackSummary = trackSummary
        self.generatorModel = generatorModel
        self.lessons = lessons
    }
}

/// 레슨 한 칸.
public struct LessonOutline: Codable, Hashable, Sendable {
    /// 진도의 앵커. `<language>.<slug>` 형태이고 **절대 바뀌지 않는다.**
    ///
    /// 순번을 ID 에 넣지 않는 이유가 이것이다 — 레슨 하나를 중간에 끼워 넣을 때마다
    /// 뒤쪽 ID 가 전부 개명되면 학습 진도가 통째로 고아가 된다. 순서는 ``ordinal`` 에
    /// 따로 둔다.
    public var stableID: LessonID
    /// 1부터 세는 트랙 내 순번. 이것은 바뀌어도 된다.
    public var ordinal: Int
    public var title: String
    public var summary: String
    /// 학습목표. 레슨을 마쳤을 때 학습자가 할 수 있게 되는 것.
    public var objectives: [String]
    /// 선수 레슨. **같은 트랙 안에서 자기보다 앞선 레슨만** 가리킬 수 있다 —
    /// 그래야 순환이 구조적으로 불가능하고 기계로 검증된다.
    public var prerequisites: [LessonID]
    /// 이 레슨이 다루는 개념 키워드.
    public var concepts: [String]
    public var estimatedMinutes: Int

    public init(
        stableID: LessonID,
        ordinal: Int,
        title: String,
        summary: String,
        objectives: [String],
        prerequisites: [LessonID],
        concepts: [String],
        estimatedMinutes: Int
    ) {
        self.stableID = stableID
        self.ordinal = ordinal
        self.title = title
        self.summary = summary
        self.objectives = objectives
        self.prerequisites = prerequisites
        self.concepts = concepts
        self.estimatedMinutes = estimatedMinutes
    }
}
