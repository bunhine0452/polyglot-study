public import LLMKit

/// 모델이 레슨 하나에 대해 내놓는 것. **마크다운이 아니라 데이터다.**
///
/// 이 타입이 존재하는 이유가 `{#lessongen-lesson}` 의 전부다. 모델에게 디렉티브
/// 마크다운을 시키면 두 가지가 무너진다.
///
/// 1. 문법을 바꾸려면 프롬프트를 고쳐야 한다. 디렉티브 인자 하나가 늘면 모든 프롬프트가
///    낡고, 낡았다는 사실은 생성물이 파싱에 실패할 때 알게 된다.
/// 2. swift-markdown 의 인자 문자셋 제약(`:` `,` `)` `{` `"` 공백 불가, 역슬래시 미해제)을
///    모델이 지킬 거라고 믿어야 한다. 실측상 값싼 모델은 지키지 않고, **어겨도 에러가
///    나지 않는다** — 값이 조용히 잘린다.
///
/// 그래서 모델은 *내용*만 말하고, 형태는 ``LessonSerializer`` 가 책임진다. 경로 인자는
/// 모델이 아예 만들지 않는다 — ``LessonPaths`` 가 stableID 에서 유도한다.
public struct LessonContentDraft: Codable, Hashable, Sendable {
    public var concept: Concept
    public var example: Example
    public var blank: Blank
    public var task: Task
    public var quiz: Quiz
    public var reflection: Reflection

    public init(
        concept: Concept,
        example: Example,
        blank: Blank,
        task: Task,
        quiz: Quiz,
        reflection: Reflection
    ) {
        self.concept = concept
        self.example = example
        self.blank = blank
        self.task = task
        self.quiz = quiz
        self.reflection = reflection
    }

    public struct Concept: Codable, Hashable, Sendable {
        public var id: String
        public var prose: String

        public init(id: String, prose: String) {
            self.id = id
            self.prose = prose
        }
    }

    public struct Example: Codable, Hashable, Sendable {
        public var id: String
        public var prose: String
        public var code: String
        /// 이 코드를 돌렸을 때 나오는 stdout 전문. `expected/` 사이드카가 된다.
        public var expectedStdout: String

        public init(id: String, prose: String, code: String, expectedStdout: String) {
            self.id = id
            self.prose = prose
            self.code = code
            self.expectedStdout = expectedStdout
        }
    }

    public struct Blank: Codable, Hashable, Sendable {
        public var id: String
        public var prose: String
        /// `___1___` 표식이 박힌 코드. 표식 번호는 1..n 을 빠짐없이 덮어야 한다.
        public var template: String
        public var answers: [Answer]

        public init(id: String, prose: String, template: String, answers: [Answer]) {
            self.id = id
            self.prose = prose
            self.template = template
            self.answers = answers
        }

        public struct Answer: Codable, Hashable, Sendable {
            public var slot: Int
            /// 한 줄. 표식 자리에 그대로 들어갈 조각이다.
            public var text: String

            public init(slot: Int, text: String) {
                self.slot = slot
                self.text = text
            }
        }
    }

    public struct Task: Codable, Hashable, Sendable {
        public var id: String
        public var prose: String
        /// 학습자에게 주어지는 것. **정답이 들어 있으면 안 된다.**
        public var starterCode: String
        public var testsCode: String
        public var solutionCode: String
        public var hints: [String]

        public init(
            id: String,
            prose: String,
            starterCode: String,
            testsCode: String,
            solutionCode: String,
            hints: [String]
        ) {
            self.id = id
            self.prose = prose
            self.starterCode = starterCode
            self.testsCode = testsCode
            self.solutionCode = solutionCode
            self.hints = hints
        }
    }

    public struct Quiz: Codable, Hashable, Sendable {
        public var id: String
        public var question: String
        public var choices: [Choice]
        /// 정답 선택지의 id. ``choices`` 에 실제로 있어야 한다.
        public var answerChoiceID: String
        public var explanation: String

        public init(
            id: String,
            question: String,
            choices: [Choice],
            answerChoiceID: String,
            explanation: String
        ) {
            self.id = id
            self.question = question
            self.choices = choices
            self.answerChoiceID = answerChoiceID
            self.explanation = explanation
        }

        public struct Choice: Codable, Hashable, Sendable {
            public var id: String
            public var prose: String

            public init(id: String, prose: String) {
                self.id = id
                self.prose = prose
            }
        }
    }

    public struct Reflection: Codable, Hashable, Sendable {
        public var id: String
        public var prompts: [Prompt]

        public init(id: String, prompts: [Prompt]) {
            self.id = id
            self.prompts = prompts
        }

        public struct Prompt: Codable, Hashable, Sendable {
            public var id: String
            public var prose: String

            public init(id: String, prose: String) {
                self.id = id
                self.prose = prose
            }
        }
    }
}

extension LessonContentDraft {
    /// 구조화 출력에 실을 JSON Schema.
    ///
    /// `strict` 가 통과하려면 모든 객체에 `additionalProperties: false` 와 **모든 키를
    /// 담은** `required` 가 있어야 한다. 그래서 선택 필드를 두지 않는다 — `explanation`
    /// 처럼 문법상 선택인 것도 여기서는 필수로 받고, 비면 직렬화기가 뺀다.
    public static var jsonSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["concept", "example", "blank", "task", "quiz", "reflection"],
            "properties": [
                "concept": conceptSchema,
                "example": exampleSchema,
                "blank": blankSchema,
                "task": taskSchema,
                "quiz": quizSchema,
                "reflection": reflectionSchema,
            ],
        ]
    }

    /// 블록 id 에 쓰는 패턴. 디렉티브 인자의 식별자 문법과 같다.
    static let identifierPattern = "^[A-Za-z][A-Za-z0-9_-]{0,63}$"

    static var conceptSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["id", "prose"],
            "properties": [
                "id": ["type": "string", "pattern": .string(identifierPattern)],
                "prose": [
                    "type": "string",
                    "description": "개념 설명. 한국어 마크다운 2~4문단. 코드펜스를 넣어도 된다.",
                ],
            ],
        ]
    }

    static var exampleSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["id", "prose", "code", "expectedStdout"],
            "properties": [
                "id": ["type": "string", "pattern": .string(identifierPattern)],
                "prose": [
                    "type": "string",
                    "description": "예제를 읽는 법 한두 문장. 한국어. **코드펜스를 넣지 마라** — 코드는 code 필드다.",
                ],
                "code": ["type": "string", "description": "실행할 코드 전문. 코드펜스 없이 알맹이만."],
                "expectedStdout": [
                    "type": "string",
                    "description": "이 코드를 돌렸을 때 나오는 stdout 전문. 바이트로 대조한다.",
                ],
            ],
        ]
    }

    static var blankSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["id", "prose", "template", "answers"],
            "properties": [
                "id": ["type": "string", "pattern": .string(identifierPattern)],
                "prose": [
                    "type": "string",
                    "description": "무엇을 채우는지 한두 문장. 한국어. 코드펜스를 넣지 마라.",
                ],
                "template": [
                    "type": "string",
                    "description": """
                        빈칸 표식을 박은 **코드**. 표식은 밑줄 세 개 + 번호 + 밑줄 세 개이고 \
                        1부터 빠짐없이 이어진다. 예: `total = ___1___(values)`. \
                        제목·설명 문장을 쓰는 자리가 아니다. 코드펜스 없이 알맹이만.
                        """,
                ],
                "answers": [
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 4,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["slot", "text"],
                        "properties": [
                            "slot": [
                                "type": "integer",
                                "minimum": 1,
                                "description": "template 의 표식 번호와 같은 수.",
                            ],
                            "text": [
                                "type": "string",
                                "description": "표식 자리에 그대로 끼워 넣을 코드 조각 한 줄. 예: sum",
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }

    static var taskSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["id", "prose", "starterCode", "testsCode", "solutionCode", "hints"],
            "properties": [
                "id": ["type": "string", "pattern": .string(identifierPattern)],
                "prose": [
                    "type": "string",
                    "description": "과제 지시. 한국어. 입력·출력·경계조건을 명시한다.",
                ],
                "starterCode": [
                    "type": "string",
                    "description": "학습자에게 주는 시작 코드. 시그니처와 주석만 있고 **정답 본문은 없다**. 숨은 테스트가 반드시 실패해야 한다.",
                ],
                "testsCode": ["type": "string", "description": "숨은 테스트 전문."],
                "solutionCode": ["type": "string", "description": "정답 전문. 숨은 테스트를 전부 통과한다."],
                "hints": [
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 3,
                    "items": ["type": "string", "description": "힌트 한 문단. 한국어. 정답 코드를 그대로 적지 않는다."],
                ],
            ],
        ]
    }

    static var quizSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["id", "question", "choices", "answerChoiceID", "explanation"],
            "properties": [
                "id": ["type": "string", "pattern": .string(identifierPattern)],
                "question": ["type": "string", "description": "질문 한 문장. 한국어."],
                "choices": [
                    "type": "array",
                    "minItems": 3,
                    "maxItems": 4,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["id", "prose"],
                        "properties": [
                            "id": [
                                "type": "string",
                                "pattern": .string(identifierPattern),
                                "description": "선택지 식별자. 내용을 드러내는 영문 kebab. 예: repr-conversion",
                            ],
                            "prose": ["type": "string", "description": "선택지 본문 한 문장. 한국어."],
                        ],
                    ],
                ],
                "answerChoiceID": [
                    "type": "string",
                    "pattern": .string(identifierPattern),
                    "description": "정답 선택지의 id. choices 안에 반드시 있어야 한다.",
                ],
                "explanation": [
                    "type": "string",
                    "description": "왜 그것이 정답이고 나머지가 오답인지. 한국어 한두 문단.",
                ],
            ],
        ]
    }

    static var reflectionSchema: JSONValue {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["id", "prompts"],
            "properties": [
                "id": ["type": "string", "pattern": .string(identifierPattern)],
                "prompts": [
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 3,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["id", "prose"],
                        "properties": [
                            "id": ["type": "string", "pattern": .string(identifierPattern)],
                            "prose": ["type": "string", "description": "채점하지 않는 열린 질문. 한국어."],
                        ],
                    ],
                ],
            ],
        ]
    }
}
