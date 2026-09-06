import ContentKit
import LearnCore
import LessonGenKit
import Testing

@Suite("레슨 직렬화 — 코드가 문법을 책임진다")
struct LessonSerializerTests {
    private func paths(_ slug: String = "python-fstring") throws -> LessonPaths {
        try LessonPaths(stableID: LessonID(slug), language: .python)
    }

    @Test("구운 마크다운이 레슨 파서를 그대로 통과한다")
    func roundTrip() throws {
        let markdown = try LessonSerializer.serializeChecked(
            LessonFixtures.draft(),
            stableID: LessonID("python-fstring"),
            language: .python,
            paths: try paths())

        // packtool 의 문법 단계가 쓰는 두 관문을 그대로.
        #expect(DirectiveSourceLint.violations(in: markdown).isEmpty)
        let blocks = try LessonParser.parse(source: markdown, path: "lessons/python-fstring.md")
        #expect(blocks.map(\.kind) == LessonBlockKind.requiredSequence)
    }

    @Test("경로 인자는 stableID 에서 유도되고 모델은 손대지 않는다")
    func derivedPaths() throws {
        let markdown = try LessonSerializer.serialize(
            LessonFixtures.draft(), language: .python, paths: try paths())
        #expect(markdown.contains("expected: expected/python-fstring.txt"))
        #expect(markdown.contains("starter: starters/python-fstring.py"))
        #expect(markdown.contains("tests: tests/python-fstring.py"))
        #expect(markdown.contains("solution: solutions/python-fstring.py"))
    }

    @Test("본문은 항상 여러 줄이고 닫는 중괄호가 줄을 독차지한다")
    func braceLayout() throws {
        let markdown = try LessonSerializer.serialize(
            LessonFixtures.draft(), language: .python, paths: try paths())
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("@") {
                #expect(line.hasSuffix(" {"), "한 줄 본문은 마지막 } 까지 삼킨다: \(line)")
            }
            if line.contains("}") && line.hasPrefix("}") {
                #expect(line == "}", "닫는 중괄호가 줄을 독차지하지 않는다: \(line)")
            }
        }
    }

    @Test("인자 값은 정규형으로 되짚어도 원문과 같다 — 조용히 잘리는 값이 없다")
    func argumentsSurviveParsing() throws {
        let draft = LessonFixtures.draft(conceptID: "개념: 기본(basic)")
        let markdown = try LessonSerializer.serializeChecked(
            draft,
            stableID: LessonID("python-fstring"),
            language: .python,
            paths: try paths())
        let blocks = try LessonParser.parse(source: markdown)
        // 콜론·괄호가 든 id 는 인자에 실릴 수 없으므로 정규화된다. 조용히 잘리지 않는다.
        #expect(blocks[0].id == "basic")
    }

    @Test("산문에 홀로 선 닫는 중괄호가 있으면 거부한다 — 디렉티브가 거기서 닫힌다")
    func rejectsBraceLine() throws {
        var draft = LessonFixtures.draft()
        draft.concept.prose = "설명이다.\n\n}\n\n계속."
        #expect(throws: LessonSerializationError.self) {
            try LessonSerializer.serialize(draft, language: .python, paths: try paths())
        }
    }

    @Test("산문 줄이 @ 와 대문자로 시작하면 거부한다")
    func rejectsDirectiveLookalike() throws {
        var draft = LessonFixtures.draft()
        draft.concept.prose = "설명이다.\n\n@Hint 이 줄은 디렉티브로 읽힌다."
        #expect(throws: LessonSerializationError.self) {
            try LessonSerializer.serialize(draft, language: .python, paths: try paths())
        }
    }

    @Test("예제 산문의 코드펜스는 거부한다 — 코드 블록이 둘이 되면 파서가 던진다")
    func rejectsFenceInExampleProse() throws {
        var draft = LessonFixtures.draft()
        draft.example.prose = "이렇게:\n\n```python\nprint(1)\n```"
        #expect(throws: LessonSerializationError.self) {
            try LessonSerializer.serialize(draft, language: .python, paths: try paths())
        }
    }

    @Test("개념 산문의 코드펜스는 허용된다 — 그 자리 코드는 산문의 일부다")
    func allowsFenceInConceptProse() throws {
        var draft = LessonFixtures.draft()
        draft.concept.prose = "이렇게 쓴다.\n\n```python\nprint(1)\n```"
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: LessonID("python-fstring"), language: .python, paths: try paths())
        #expect(markdown.contains("print(1)"))
    }

    @Test("코드 안에 백틱 세 개가 있어도 펜스가 더 길어져 살아남는다")
    func fenceCollision() throws {
        var draft = LessonFixtures.draft()
        draft.example.code = "text = \"\"\"```\"\"\"\nprint(text)"
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: LessonID("python-fstring"), language: .python, paths: try paths())
        let blocks = try LessonParser.parse(source: markdown)
        guard case .example(let example) = blocks[1] else {
            Issue.record("예제 블록이 아니다")
            return
        }
        #expect(example.code.contains("```"))
    }

    @Test("모델이 코드에 씌워 보낸 바깥 펜스는 벗겨진다")
    func stripsOuterFence() throws {
        var draft = LessonFixtures.draft()
        draft.example.code = "```python\nprint(\"hi\")\n```"
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: LessonID("python-fstring"), language: .python, paths: try paths())
        let blocks = try LessonParser.parse(source: markdown)
        guard case .example(let example) = blocks[1] else {
            Issue.record("예제 블록이 아니다")
            return
        }
        #expect(example.code == "print(\"hi\")\n")
    }

    @Test("빈칸 정답은 인라인 코드로 감싸여 마크다운 해석을 타지 않는다")
    func answerSurvivesMarkdown() throws {
        var draft = LessonFixtures.draft()
        draft.blank.answers = [
            LessonContentDraft.Blank.Answer(slot: 1, text: "sum"),
            LessonContentDraft.Blank.Answer(slot: 2, text: "*total*"),
        ]
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: LessonID("python-fstring"), language: .python, paths: try paths())
        let blocks = try LessonParser.parse(source: markdown)
        guard case .blank(let blank) = blocks[2] else {
            Issue.record("빈칸 블록이 아니다")
            return
        }
        #expect(blank.slots.map(\.answer) == ["sum", "*total*"])
    }

    @Test("정답에 백틱이 있어도 살아남는다")
    func answerWithBacktick() throws {
        var draft = LessonFixtures.draft()
        draft.blank.answers = [
            LessonContentDraft.Blank.Answer(slot: 1, text: "sum"),
            LessonContentDraft.Blank.Answer(slot: 2, text: "`total`"),
        ]
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: LessonID("python-fstring"), language: .python, paths: try paths())
        let blocks = try LessonParser.parse(source: markdown)
        guard case .blank(let blank) = blocks[2] else {
            Issue.record("빈칸 블록이 아니다")
            return
        }
        #expect(blank.slots[1].answer == "`total`")
    }

    @Test("표식과 정답 슬롯이 어긋나면 거부한다")
    func blankSlotMismatch() throws {
        var draft = LessonFixtures.draft()
        draft.blank.answers = [LessonContentDraft.Blank.Answer(slot: 1, text: "sum")]
        #expect(throws: LessonSerializationError.blankSlotMismatch(markers: [1, 2], answers: [1])) {
            try LessonSerializer.serialize(draft, language: .python, paths: try paths())
        }
    }

    @Test("퀴즈 정답 키가 선택지에 없으면 거부한다")
    func quizAnswerMustBeAChoice() throws {
        var draft = LessonFixtures.draft()
        draft.quiz.answerChoiceID = "not-there"
        #expect(throws: LessonSerializationError.self) {
            try LessonSerializer.serialize(draft, language: .python, paths: try paths())
        }
    }

    @Test("선택지 id 와 정답 키는 같은 규칙으로 다듬어져 가리킴이 유지된다")
    func sanitizationKeepsAnswerLink() throws {
        var draft = LessonFixtures.draft()
        draft.quiz.choices[0].id = "repr conversion"
        draft.quiz.answerChoiceID = "repr conversion"
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: LessonID("python-fstring"), language: .python, paths: try paths())
        let blocks = try LessonParser.parse(source: markdown)
        guard case .quiz(let quiz) = blocks[4] else {
            Issue.record("퀴즈 블록이 아니다")
            return
        }
        #expect(quiz.answer != nil)
        #expect(quiz.answerID == "repr-conversion")
    }

    @Test("설명이 비면 @Explanation 을 아예 넣지 않는다 — 빈 본문은 파서가 거부한다")
    func omitsEmptyExplanation() throws {
        var draft = LessonFixtures.draft()
        draft.quiz.explanation = "   "
        let markdown = try LessonSerializer.serializeChecked(
            draft, stableID: LessonID("python-fstring"), language: .python, paths: try paths())
        #expect(!markdown.contains("@Explanation"))
    }

    @Test("여섯 블록 id 가 겹치면 거부한다")
    func duplicateBlockIDs() throws {
        let draft = LessonFixtures.draft(conceptID: "same", exampleID: "same")
        #expect(throws: LessonSerializationError.duplicateBlockID("same")) {
            try LessonSerializer.serialize(draft, language: .python, paths: try paths())
        }
    }

    @Test("CRLF 는 LF 로 눕고 줄 끝 공백은 사라진다")
    func normalizesLineEndings() throws {
        var draft = LessonFixtures.draft()
        draft.concept.prose = "첫 줄   \r\n\r\n둘째 줄\r"
        let markdown = try LessonSerializer.serialize(
            draft, language: .python, paths: try paths())
        #expect(!markdown.contains("\r"))
        #expect(!markdown.contains("   \n"))
    }

    @Test("세 언어 모두 여섯 블록으로 구워진다")
    func allLanguages() throws {
        for language in LessonLanguage.allCases {
            var draft = LessonFixtures.draft()
            draft.example.code = "print(1)"
            draft.blank.template = "x = ___1___"
            draft.blank.answers = [LessonContentDraft.Blank.Answer(slot: 1, text: "1")]
            let stableID = LessonID("\(language.rawValue)-lesson")
            let markdown = try LessonSerializer.serializeChecked(
                draft,
                stableID: stableID,
                language: language,
                paths: try LessonPaths(stableID: stableID, language: language))
            #expect(markdown.contains("language: \(language.rawValue)"))
            #expect(markdown.contains(".\(language.fileExtension)"))
        }
    }
}

@Suite("팩 stableID 변환")
struct PackLessonIDTests {
    @Test("개요의 점을 하이픈으로 바꿔 매니페스트가 받는 슬러그로 만든다")
    func conversion() {
        #expect(
            PackLessonID.fromOutline(LessonID("python.hello-stdout")).rawValue
                == "python-hello-stdout")
    }

    @Test("개요 형식 그대로는 매니페스트 슬러그가 아니다 — 변환이 필요한 이유")
    func outlineFormIsNotASlug() {
        #expect(!PackLessonID.isPackSlug("python.hello-stdout"))
        #expect(PackLessonID.isPackSlug("python-hello-stdout"))
    }

    @Test("변환은 순번을 담지 않는다 — 레슨을 끼워 넣어도 뒤쪽 id 가 흔들리지 않는다")
    func noOrdinalInID() {
        let id = PackLessonID.fromOutline(LessonID("python.list-comprehension"))
        #expect(!id.rawValue.contains("0001"))
    }
}
