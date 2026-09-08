import ContentKit
public import LearnCore

/// 레슨 데이터를 디렉티브 마크다운으로 굽는다. **순수 함수다.**
///
/// `{#lessongen-lesson}` 의 핵심. 모델은 ``LessonContentDraft`` 를 주고, 문법은 전부
/// 여기서 만들어진다. 그래서 디렉티브 인자가 하나 늘어도 프롬프트는 그대로다.
///
/// ``serializeChecked(_:stableID:language:paths:)`` 는 구운 결과를 **곧바로
/// `LessonParser` 에 태운다.** `packtool` 의 문법 단계가 쓰는 바로 그 파서다. 통과하지
/// 못하면 던지므로, 디스크에 놓인 레슨은 이미 그 단계를 지난 것이다 — "첫 시도에
/// 통과" 가 희망이 아니라 구조적 사실이 되는 지점이다.
public enum LessonSerializer {
    /// 굽기만 한다. 검사는 ``serializeChecked(_:stableID:language:paths:)`` 가 한다.
    public static func serialize(
        _ draft: LessonContentDraft,
        language: LessonLanguage,
        paths: LessonPaths
    ) throws(LessonSerializationError) -> String {
        let ids = try blockIDs(of: draft)
        let blocks = [
            try conceptBlock(draft.concept, id: ids.concept),
            try exampleBlock(draft.example, id: ids.example, language: language, paths: paths),
            try blankBlock(draft.blank, id: ids.blank, language: language),
            try taskBlock(draft.task, id: ids.task, language: language, paths: paths),
            try quizBlock(draft.quiz, id: ids.quiz),
            try reflectionBlock(draft.reflection, id: ids.reflection),
        ]
        // 파일 끝 개행 하나. POSIX 텍스트 파일이고, git diff 가 "\ No newline" 을 달지 않는다.
        return blocks.joined(separator: "\n\n") + "\n"
    }

    /// 굽고, 다시 파싱하고, 값이 살아남았는지 대조한다.
    public static func serializeChecked(
        _ draft: LessonContentDraft,
        stableID: LessonID,
        language: LessonLanguage,
        paths: LessonPaths
    ) throws(LessonSerializationError) -> String {
        let markdown = try serialize(draft, language: language, paths: paths)
        let document: LessonDocument
        do {
            document = try LessonParser.parseDocument(
                source: markdown,
                stableID: stableID,
                languages: [language.id],
                path: paths.lesson)
        } catch {
            throw .unparsableOutput(error.description)
        }
        try verify(document, against: draft, language: language, paths: paths)
        return markdown
    }

    // MARK: - 블록별 조립

    private struct BlockIDs {
        var concept: String
        var example: String
        var blank: String
        var task: String
        var quiz: String
        var reflection: String
    }

    /// 여섯 블록 id 를 정규화하고 유일성을 확인한다. 파서가 레슨 안 중복 id 를 거부한다.
    private static func blockIDs(of draft: LessonContentDraft) throws(LessonSerializationError)
        -> BlockIDs
    {
        let ids = BlockIDs(
            concept: DirectiveWriter.sanitizedIdentifier(draft.concept.id, fallback: "concept"),
            example: DirectiveWriter.sanitizedIdentifier(draft.example.id, fallback: "example"),
            blank: DirectiveWriter.sanitizedIdentifier(draft.blank.id, fallback: "blank"),
            task: DirectiveWriter.sanitizedIdentifier(draft.task.id, fallback: "task"),
            quiz: DirectiveWriter.sanitizedIdentifier(draft.quiz.id, fallback: "quiz"),
            reflection: DirectiveWriter.sanitizedIdentifier(
                draft.reflection.id, fallback: "reflection"))
        var seen: Set<String> = []
        for id in [ids.concept, ids.example, ids.blank, ids.task, ids.quiz, ids.reflection] {
            guard seen.insert(id).inserted else { throw .duplicateBlockID(id) }
        }
        return ids
    }

    private static func conceptBlock(_ concept: LessonContentDraft.Concept, id: String)
        throws(LessonSerializationError) -> String
    {
        let prose = try DirectiveWriter.normalizedProse(
            concept.prose, context: "@Concept 산문", allowingCodeFences: true)
        return DirectiveWriter.block("Concept", arguments: [("id", id)], body: prose)
    }

    private static func exampleBlock(
        _ example: LessonContentDraft.Example,
        id: String,
        language: LessonLanguage,
        paths: LessonPaths
    ) throws(LessonSerializationError) -> String {
        // 예제 산문에 코드펜스가 있으면 본문의 코드 블록이 둘이 되어 파서가 거부한다.
        let prose = try DirectiveWriter.normalizedProse(
            example.prose, context: "@Example 산문", allowingCodeFences: false)
        _ = try DirectiveWriter.normalizedCode(example.code, context: "@Example 코드")
        let code = DirectiveWriter.fencedCode(example.code, info: language.fenceInfo)
        return DirectiveWriter.block(
            "Example",
            arguments: [
                ("id", id),
                ("language", language.rawValue),
                ("expected", paths.expected.rawValue),
            ],
            body: "\(prose)\n\n\(code)")
    }

    private static func blankBlock(
        _ blank: LessonContentDraft.Blank,
        id: String,
        language: LessonLanguage
    ) throws(LessonSerializationError) -> String {
        let prose = try DirectiveWriter.normalizedProse(
            blank.prose, context: "@Blank 산문", allowingCodeFences: false)
        let template = try DirectiveWriter.normalizedCode(blank.template, context: "@Blank 템플릿")

        let markers = BlankSlotMarker.indices(in: template).sorted()
        let slots = blank.answers.map(\.slot).sorted()
        guard !markers.isEmpty, markers == slots, slots == Array(1...slots.count) else {
            throw .blankSlotMismatch(markers: markers, answers: slots)
        }

        var pieces = [prose, DirectiveWriter.fencedCode(blank.template, info: language.fenceInfo)]
        for answer in blank.answers.sorted(by: { $0.slot < $1.slot }) {
            let text = try DirectiveWriter.inlineCode(
                answer.text, context: "@Answer(slot: \(answer.slot))")
            pieces.append(
                DirectiveWriter.block(
                    "Answer", arguments: [("slot", String(answer.slot))], body: text))
        }
        return DirectiveWriter.block(
            "Blank",
            arguments: [("id", id), ("language", language.rawValue)],
            body: pieces.joined(separator: "\n\n"))
    }

    private static func taskBlock(
        _ task: LessonContentDraft.Task,
        id: String,
        language: LessonLanguage,
        paths: LessonPaths
    ) throws(LessonSerializationError) -> String {
        let prose = try DirectiveWriter.normalizedProse(
            task.prose, context: "@Task 산문", allowingCodeFences: false)
        var pieces = [prose]
        for (index, hint) in task.hints.enumerated() {
            let body = try DirectiveWriter.normalizedProse(
                hint, context: "@Hint \(index + 1)", allowingCodeFences: false)
            pieces.append(DirectiveWriter.block("Hint", arguments: [], body: body))
        }
        return DirectiveWriter.block(
            "Task",
            arguments: [
                ("id", id),
                ("language", language.rawValue),
                ("starter", paths.starter.rawValue),
                ("tests", paths.tests.rawValue),
                ("solution", paths.solution.rawValue),
            ],
            body: pieces.joined(separator: "\n\n"))
    }

    private static func quizBlock(_ quiz: LessonContentDraft.Quiz, id: String)
        throws(LessonSerializationError) -> String
    {
        let question = try DirectiveWriter.normalizedProse(
            quiz.question, context: "@Question", allowingCodeFences: false)

        var choiceIDs: [String] = []
        var seen: Set<String> = []
        var choiceBlocks: [String] = []
        for (index, choice) in quiz.choices.enumerated() {
            let choiceID = DirectiveWriter.sanitizedIdentifier(
                choice.id, fallback: "choice-\(index + 1)")
            guard seen.insert(choiceID).inserted else { throw .duplicateChoiceID(choiceID) }
            choiceIDs.append(choiceID)
            let prose = try DirectiveWriter.normalizedProse(
                choice.prose, context: "@Choice(\(choiceID))", allowingCodeFences: false)
            choiceBlocks.append(
                DirectiveWriter.block("Choice", arguments: [("id", choiceID)], body: prose))
        }
        guard choiceIDs.count >= 2 else { throw .tooFewChoices(count: choiceIDs.count) }

        let answerID = DirectiveWriter.sanitizedIdentifier(
            quiz.answerChoiceID, fallback: "no-answer")
        guard seen.contains(answerID) else {
            throw .answerNotAChoice(answer: answerID, choices: choiceIDs)
        }

        var pieces = [DirectiveWriter.block("Question", arguments: [], body: question)]
        pieces.append(contentsOf: choiceBlocks)
        // `@Explanation` 은 문법상 선택이다. 비면 넣지 않는다 — 빈 본문은 파서가 거부한다.
        let explanation = DirectiveWriter.normalizeLineEndings(quiz.explanation)
            .trimmedOuterWhitespace()
        if !explanation.isEmpty {
            let body = try DirectiveWriter.normalizedProse(
                explanation, context: "@Explanation", allowingCodeFences: false)
            pieces.append(DirectiveWriter.block("Explanation", arguments: [], body: body))
        }
        return DirectiveWriter.block(
            "Quiz",
            arguments: [("id", id), ("answer", answerID)],
            body: pieces.joined(separator: "\n\n"))
    }

    private static func reflectionBlock(
        _ reflection: LessonContentDraft.Reflection,
        id: String
    ) throws(LessonSerializationError) -> String {
        var seen: Set<String> = []
        var pieces: [String] = []
        for (index, prompt) in reflection.prompts.enumerated() {
            let promptID = DirectiveWriter.sanitizedIdentifier(
                prompt.id, fallback: "prompt-\(index + 1)")
            guard seen.insert(promptID).inserted else { throw .duplicatePromptID(promptID) }
            let prose = try DirectiveWriter.normalizedProse(
                prompt.prose, context: "@Prompt(\(promptID))", allowingCodeFences: false)
            pieces.append(
                DirectiveWriter.block("Prompt", arguments: [("id", promptID)], body: prose))
        }
        guard !pieces.isEmpty else { throw .tooFewPrompts }
        return DirectiveWriter.block(
            "Reflection", arguments: [("id", id)], body: pieces.joined(separator: "\n\n"))
    }

    // MARK: - 왕복 검사

    /// 구운 것을 다시 읽어 **기계가 쓰는 값**이 그대로인지 본다.
    ///
    /// 산문은 대조하지 않는다 — `MarkupFormatter` 왕복이 목록 마커나 번호 표기를 정규형으로
    /// 바꾸므로 바이트 일치를 요구하면 거짓 실패가 난다. 대신 채점과 실행이 읽는 값 —
    /// 경로·정답·선택지 id·빈칸 슬롯 — 은 한 글자도 달라지면 안 된다.
    private static func verify(
        _ document: LessonDocument,
        against draft: LessonContentDraft,
        language: LessonLanguage,
        paths: LessonPaths
    ) throws(LessonSerializationError) {
        guard document.blocks.count == LessonBlockKind.requiredSequence.count else {
            throw .roundTripMismatch(
                field: "blocks.count",
                expected: String(LessonBlockKind.requiredSequence.count),
                found: String(document.blocks.count))
        }
        // 생성기는 언어 하나짜리 레슨을 쓴다 — 왕복 검증은 **쓰려던 그 언어**의 블록을 본다.
        guard let example = document.example(for: language.id) else {
            throw .roundTripMismatch(field: "example", expected: "존재", found: "없음")
        }
        guard example.expectedStdoutPath == paths.expected else {
            throw .roundTripMismatch(
                field: "example.expected",
                expected: paths.expected.rawValue,
                found: example.expectedStdoutPath.rawValue)
        }
        let expectedCode = try DirectiveWriter.normalizedCode(
            draft.example.code, context: "@Example 코드")
        guard example.code == expectedCode else {
            throw .roundTripMismatch(
                field: "example.code", expected: expectedCode, found: example.code)
        }
        guard example.language == language.id else {
            throw .roundTripMismatch(
                field: "example.language",
                expected: language.rawValue,
                found: example.language.rawValue)
        }

        guard let blank = document.blank(for: language.id) else {
            throw .roundTripMismatch(field: "blank", expected: "존재", found: "없음")
        }
        let expectedAnswers = draft.blank.answers.sorted { $0.slot < $1.slot }
        guard blank.slots.count == expectedAnswers.count else {
            throw .roundTripMismatch(
                field: "blank.slots.count",
                expected: String(expectedAnswers.count),
                found: String(blank.slots.count))
        }
        for (slot, answer) in zip(blank.slots, expectedAnswers) {
            let wanted = DirectiveWriter.normalizeLineEndings(answer.text).trimmedOuterWhitespace()
            guard slot.index == answer.slot, slot.answer == wanted else {
                throw .roundTripMismatch(
                    field: "blank.slot[\(answer.slot)]", expected: wanted, found: slot.answer)
            }
        }

        guard let task = document.task(for: language.id) else {
            throw .roundTripMismatch(field: "task", expected: "존재", found: "없음")
        }
        for (name, expected, found) in [
            ("task.starter", paths.starter, task.starterPath),
            ("task.tests", paths.tests, task.testsPath),
            ("task.solution", paths.solution, task.solutionPath),
        ] where expected != found {
            throw .roundTripMismatch(field: name, expected: expected.rawValue, found: found.rawValue)
        }

        guard let quiz = document.quiz else {
            throw .roundTripMismatch(field: "quiz", expected: "존재", found: "없음")
        }
        guard quiz.answer != nil else {
            throw .answerNotAChoice(answer: quiz.answerID, choices: quiz.choices.map(\.id))
        }
        guard quiz.choices.count == draft.quiz.choices.count else {
            throw .roundTripMismatch(
                field: "quiz.choices.count",
                expected: String(draft.quiz.choices.count),
                found: String(quiz.choices.count))
        }

        guard let reflection = document.reflection,
            reflection.prompts.count == draft.reflection.prompts.count
        else {
            throw .roundTripMismatch(
                field: "reflection.prompts.count",
                expected: String(draft.reflection.prompts.count),
                found: String(document.reflection?.prompts.count ?? 0))
        }
    }
}
