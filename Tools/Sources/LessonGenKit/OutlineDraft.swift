public import AnthropicKit

/// 모델이 내놓는 것. ``TrackOutline`` 과 **일부러 다른 타입이다.**
///
/// 모델에게는 슬러그·제목·목표 같은 *데이터*만 시키고, `stableID` 조립과 순번 매김과
/// 선수 레슨 해석은 Swift 가 한다. `{#lessongen-lesson}` 이 "모델에게 마크다운을 시키지
/// 않는다" 와 같은 규율이다 — 산출물의 형태는 코드가 책임진다.
public struct OutlineDraft: Codable, Hashable, Sendable {
    public var trackTitle: String
    public var trackSummary: String
    public var lessons: [LessonDraft]

    public init(trackTitle: String, trackSummary: String, lessons: [LessonDraft]) {
        self.trackTitle = trackTitle
        self.trackSummary = trackSummary
        self.lessons = lessons
    }
}

public struct LessonDraft: Codable, Hashable, Sendable {
    /// 소문자 kebab. 언어 접두사는 붙이지 않는다 — Swift 가 붙인다.
    public var slug: String
    public var title: String
    public var summary: String
    public var objectives: [String]
    /// 앞선 레슨의 `slug`.
    public var prerequisiteSlugs: [String]
    public var concepts: [String]
    public var estimatedMinutes: Int

    public init(
        slug: String,
        title: String,
        summary: String,
        objectives: [String],
        prerequisiteSlugs: [String],
        concepts: [String],
        estimatedMinutes: Int
    ) {
        self.slug = slug
        self.title = title
        self.summary = summary
        self.objectives = objectives
        self.prerequisiteSlugs = prerequisiteSlugs
        self.concepts = concepts
        self.estimatedMinutes = estimatedMinutes
    }
}

extension OutlineDraft {
    /// 구조화 출력에 실을 JSON Schema.
    ///
    /// 모든 객체에 `additionalProperties: false` 와 `required` 가 있어야 API 가 받는다.
    public static var jsonSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["trackTitle", "trackSummary", "lessons"],
            "properties": [
                "trackTitle": [
                    "type": "string",
                    "description": "트랙 제목. 한국어.",
                ],
                "trackSummary": [
                    "type": "string",
                    "description": "트랙이 무엇을 가르치는지 두세 문장. 한국어.",
                ],
                "lessons": [
                    "type": "array",
                    "minItems": 1,
                    "items": lessonSchema,
                ],
            ],
        ]
    }

    public static var lessonSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "slug", "title", "summary", "objectives",
                "prerequisiteSlugs", "concepts", "estimatedMinutes",
            ],
            "properties": [
                "slug": [
                    "type": "string",
                    "description": "소문자 영문 kebab-case 식별자. 언어 접두사는 붙이지 않는다. 예: list-comprehension",
                    "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$",
                ],
                "title": ["type": "string", "description": "레슨 제목. 한국어."],
                "summary": ["type": "string", "description": "레슨 한 문단 요약. 한국어."],
                "objectives": [
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 4,
                    "items": [
                        "type": "string",
                        "description": "'...할 수 있다' 로 끝나는 학습목표. 한국어.",
                    ],
                ],
                "prerequisiteSlugs": [
                    "type": "array",
                    "description": "이 레슨보다 앞에 나오는 레슨의 slug 만. 앞 레슨이 없으면 빈 배열.",
                    "items": ["type": "string"],
                ],
                "concepts": [
                    "type": "array",
                    "minItems": 1,
                    "items": ["type": "string", "description": "개념 키워드. 영문 식별자 또는 한국어 용어."],
                ],
                "estimatedMinutes": [
                    "type": "integer",
                    "minimum": 5,
                    "maximum": 90,
                ],
            ],
        ]
    }
}
