public import LearnCore
internal import Markdown

/// 디렉티브 마크다운 레슨을 ``LessonBlock`` 배열로 옮긴다.
///
/// **`Markup` 트리는 이 타입 밖으로 한 발도 나가지 않는다.** `Markup` 은 `Sendable` 이
/// 아니라서 nonisolated 코어와 UI 가 값으로 들고 다닐 수 없다. 그래서 파싱 결과는 전부
/// 문자열·정수·자체 위치 타입으로 옮겨 담고, 산문은 마크다운 **소스**로 되돌려 저장한다.
public enum LessonParser {
    /// 실행 트랙으로 인정하는 언어. 팩의 `languages` 와는 별개로, 파서가 아는 언어만
    /// 디렉티브 인자에 쓸 수 있다.
    ///
    /// **여기에 언어를 더하기 전에 `RunnerKit` 에 실행기와 채점기가 있어야 한다.**
    /// 이 목록은 "레슨을 쓸 수 있다" 는 뜻인데, 실행 게이트를 세울 수 없으면 검증되지
    /// 않은 콘텐츠가 팩에 들어간다. `packtool validate` 의 실행 단계가 언어를 모르면
    /// 과제는 통과도 실패도 아닌 채로 지나간다 — 그게 이 목록이 좁은 이유다.
    public static let supportedLanguages: [LanguageID] = [.python, .sql, .swift, .cpp, .rust]

    /// 레슨 본문을 파싱한다.
    ///
    /// - Parameters:
    ///   - source: 레슨 마크다운 전문.
    ///   - path: 팩 상대 경로. 에러 메시지 접두사로만 쓴다.
    /// - Returns: 정확히 6개, ``LessonBlockKind/requiredSequence`` 순서의 블록.
    public static func parse(source: String, path: String? = nil) throws(LessonParseError)
        -> [LessonBlock]
    {
        do throws(LessonParseError) {
            // 1단계: 소스 렉시컬 검사. 트리를 본 뒤에는 복구할 수 없는 함정들을 먼저 친다.
            try DirectiveSourceLint.check(source)

            // 2단계: 트리 순회. `.disableSmartOpts` 는 필수다 — 켜두면 산문 속 `--` 가
            // en dash 로 바뀌어 코드 예시를 설명하는 문장이 조용히 달라진다.
            let document = Document(
                parsing: source, options: [.parseBlockDirectives, .disableSmartOpts])
            var walker = TopLevelWalker()
            walker.visit(document)
            if let error = walker.error { throw error }

            // 3단계: 시퀀스 검사.
            try validateSequence(walker.blocks)
            return walker.blocks
        } catch {
            guard let path else { throw error }
            throw error.annotated(path: path)
        }
    }

    /// 매니페스트가 준 신원과 묶어 완성된 레슨으로.
    public static func parseDocument(
        source: String,
        stableID: LessonID,
        language: LanguageID,
        path: PackRelativePath? = nil
    ) throws(LessonParseError) -> LessonDocument {
        let blocks = try parse(source: source, path: path?.rawValue)
        return LessonDocument(
            stableID: stableID, language: language, blocks: blocks, path: path)
    }

    // MARK: - 시퀀스

    private static func validateSequence(_ blocks: [LessonBlock]) throws(LessonParseError) {
        var seen: Set<LessonBlockKind> = []
        var ids: Set<String> = []
        var expected = LessonBlockKind.requiredSequence[...]

        for block in blocks {
            guard seen.insert(block.kind).inserted else {
                throw LessonParseError(.duplicateBlock(block.kind), at: block.span.start)
            }
            guard ids.insert(block.id).inserted else {
                throw LessonParseError(.duplicateBlockID(block.id), at: block.span.start)
            }
            guard let next = expected.first else {
                throw LessonParseError(.duplicateBlock(block.kind), at: block.span.start)
            }
            guard next == block.kind else {
                throw LessonParseError(
                    .blockOutOfOrder(found: block.kind, expected: next), at: block.span.start)
            }
            expected = expected.dropFirst()
        }

        if let missing = expected.first {
            let position = blocks.last?.span.end ?? SourcePosition(line: 1, column: 1)
            throw LessonParseError(.missingBlock(missing), at: position)
        }
    }

    // MARK: - 최상위 순회

    /// 문서 최상위만 훑는다. 디렉티브 안으로는 내려가지 않는다 — 블록 파서가 직접 읽는다.
    private struct TopLevelWalker: MarkupWalker {
        var blocks: [LessonBlock] = []
        var error: LessonParseError?

        mutating func visitDocument(_ document: Document) {
            descendInto(document)
        }

        mutating func visitBlockDirective(_ directive: BlockDirective) {
            guard error == nil else { return }
            guard let kind = LessonBlockKind.kind(forDirective: directive.name) else {
                error = LessonParseError(
                    .unknownDirective(directive.name), at: .at(directive.nameLocation))
                return
            }
            do {
                blocks.append(try LessonParser.block(kind, from: directive))
            } catch {
                self.error = error
            }
        }

        mutating func defaultVisit(_ markup: any Markup) {
            guard error == nil else { return }
            error = LessonParseError(
                .unexpectedTopLevelContent(LessonParser.describe(markup)),
                at: .at(markup.range?.lowerBound))
        }
    }

    static func describe(_ markup: any Markup) -> String {
        switch markup {
        case is Heading: "제목"
        case is Paragraph: "문단"
        case is CodeBlock: "코드 블록"
        case is UnorderedList, is OrderedList: "목록"
        case is BlockQuote: "인용"
        case is ThematicBreak: "구분선"
        case is HTMLBlock: "HTML"
        default: String(describing: type(of: markup))
        }
    }

    // MARK: - 블록별 파싱

    static func block(_ kind: LessonBlockKind, from directive: BlockDirective)
        throws(LessonParseError) -> LessonBlock
    {
        switch kind {
        case .concept: .concept(try concept(directive))
        case .example: .example(try example(directive))
        case .blank: .blank(try blank(directive))
        case .task: .task(try task(directive))
        case .quiz: .quiz(try quiz(directive))
        case .reflection: .reflection(try reflection(directive))
        }
    }

    private static func concept(_ directive: BlockDirective) throws(LessonParseError)
        -> ConceptBlock
    {
        var arguments = try DirectiveArguments(directive)
        let id = try arguments.identifier("id")
        try arguments.finish()
        try rejectChildDirectives(in: directive, allowing: [])

        let prose = Body.prose(of: directive, includingCode: true)
        guard !prose.isEmpty else {
            throw LessonParseError(
                .missingProse(directive: directive.name), at: .at(directive.nameLocation))
        }
        return ConceptBlock(id: id, prose: prose, span: .span(of: directive))
    }

    private static func example(_ directive: BlockDirective) throws(LessonParseError)
        -> ExampleBlock
    {
        var arguments = try DirectiveArguments(directive)
        let id = try arguments.identifier("id")
        let language = try arguments.token("language", allowing: supportedLanguages.map(\.rawValue))
        let expected = try arguments.path("expected", under: PackLayout.expectedDirectory)
        try arguments.finish()
        try rejectChildDirectives(in: directive, allowing: [])

        let code = try Body.singleCodeBlock(of: directive)
        return ExampleBlock(
            id: id,
            language: LanguageID(language),
            prose: Body.prose(of: directive, includingCode: false),
            code: code.code,
            codeFenceLanguage: code.language,
            expectedStdoutPath: expected,
            span: .span(of: directive))
    }

    private static func blank(_ directive: BlockDirective) throws(LessonParseError) -> BlankBlock {
        var arguments = try DirectiveArguments(directive)
        let id = try arguments.identifier("id")
        let language = try arguments.token("language", allowing: supportedLanguages.map(\.rawValue))
        try arguments.finish()
        try rejectChildDirectives(in: directive, allowing: [DirectiveNames.answer])

        let code = try Body.singleCodeBlock(of: directive)
        let markers = BlankSlotMarker.indices(in: code.code)

        var slots: [BlankBlock.Slot] = []
        var seen: Set<Int> = []
        for child in Body.childDirectives(of: directive, named: DirectiveNames.answer) {
            var childArguments = try DirectiveArguments(child)
            let slot = try childArguments.integer("slot")
            try childArguments.finish()
            try rejectChildDirectives(in: child, allowing: [])

            guard seen.insert(slot).inserted else {
                throw LessonParseError(
                    .duplicateAnswerSlot(directive: directive.name, slot: slot),
                    at: .at(child.nameLocation))
            }
            let answer = Body.plainText(of: child)
            guard !answer.isEmpty else {
                throw LessonParseError(
                    .emptyAnswer(directive: directive.name, slot: slot),
                    at: .at(child.nameLocation))
            }
            slots.append(
                BlankBlock.Slot(index: slot, answer: answer, span: .span(of: child)))
        }

        let answered = slots.map(\.index).sorted()
        guard !markers.isEmpty, Set(markers).sorted() == answered,
            answered == Array(1...answered.count)
        else {
            throw LessonParseError(
                .blankSlotMismatch(
                    directive: directive.name, markers: markers, answers: answered),
                at: .at(directive.nameLocation))
        }

        return BlankBlock(
            id: id,
            language: LanguageID(language),
            prose: Body.prose(of: directive, includingCode: false),
            template: code.code,
            codeFenceLanguage: code.language,
            slots: slots.sorted { $0.index < $1.index },
            span: .span(of: directive))
    }

    private static func task(_ directive: BlockDirective) throws(LessonParseError) -> TaskBlock {
        var arguments = try DirectiveArguments(directive)
        let id = try arguments.identifier("id")
        let language = try arguments.token("language", allowing: supportedLanguages.map(\.rawValue))
        let starter = try arguments.path("starter", under: PackLayout.startersDirectory)
        let tests = try arguments.path("tests", under: PackLayout.testsDirectory)
        let solution = try arguments.path("solution", under: PackLayout.solutionsDirectory)
        try arguments.finish()
        try rejectChildDirectives(in: directive, allowing: [DirectiveNames.hint])

        var hints: [TaskBlock.Hint] = []
        for child in Body.childDirectives(of: directive, named: DirectiveNames.hint) {
            let childArguments = try DirectiveArguments(child)
            try childArguments.finish()
            try rejectChildDirectives(in: child, allowing: [])
            let prose = Body.prose(of: child, includingCode: true)
            guard !prose.isEmpty else {
                throw LessonParseError(
                    .emptyBody(directive: child.name), at: .at(child.nameLocation))
            }
            hints.append(TaskBlock.Hint(order: hints.count + 1, prose: prose))
        }

        let prose = Body.prose(of: directive, includingCode: true)
        guard !prose.isEmpty else {
            throw LessonParseError(
                .missingProse(directive: directive.name), at: .at(directive.nameLocation))
        }

        return TaskBlock(
            id: id,
            language: LanguageID(language),
            prose: prose,
            starterPath: starter,
            testsPath: tests,
            solutionPath: solution,
            hints: hints,
            span: .span(of: directive))
    }

    private static func quiz(_ directive: BlockDirective) throws(LessonParseError) -> QuizBlock {
        var arguments = try DirectiveArguments(directive)
        let id = try arguments.identifier("id")
        let answerID = try arguments.identifier("answer")
        try arguments.finish()
        try rejectChildDirectives(
            in: directive,
            allowing: [DirectiveNames.question, DirectiveNames.choice, DirectiveNames.explanation])

        guard let questionDirective = Body.childDirectives(
            of: directive, named: DirectiveNames.question
        ).first else {
            throw LessonParseError(
                .missingChildDirective(parent: directive.name, child: DirectiveNames.question),
                at: .at(directive.nameLocation))
        }
        let questionArguments = try DirectiveArguments(questionDirective)
        try questionArguments.finish()
        let question = Body.prose(of: questionDirective, includingCode: true)
        guard !question.isEmpty else {
            throw LessonParseError(
                .emptyBody(directive: questionDirective.name),
                at: .at(questionDirective.nameLocation))
        }

        var choices: [QuizBlock.Choice] = []
        var seen: Set<String> = []
        for child in Body.childDirectives(of: directive, named: DirectiveNames.choice) {
            var childArguments = try DirectiveArguments(child)
            let choiceID = try childArguments.identifier("id")
            try childArguments.finish()
            try rejectChildDirectives(in: child, allowing: [])
            guard seen.insert(choiceID).inserted else {
                throw LessonParseError(
                    .duplicateChoiceID(directive: directive.name, choice: choiceID),
                    at: .at(child.nameLocation))
            }
            let prose = Body.prose(of: child, includingCode: true)
            guard !prose.isEmpty else {
                throw LessonParseError(
                    .emptyBody(directive: child.name), at: .at(child.nameLocation))
            }
            choices.append(
                QuizBlock.Choice(id: choiceID, prose: prose, span: .span(of: child)))
        }

        guard choices.count >= 2 else {
            throw LessonParseError(
                .tooFewChoices(directive: directive.name, count: choices.count),
                at: .at(directive.nameLocation))
        }
        guard seen.contains(answerID) else {
            throw LessonParseError(
                .answerNotAChoice(
                    directive: directive.name, answer: answerID, choices: choices.map(\.id)),
                at: .at(directive.nameLocation))
        }

        var explanation: String?
        if let child = Body.childDirectives(of: directive, named: DirectiveNames.explanation).first {
            let childArguments = try DirectiveArguments(child)
            try childArguments.finish()
            try rejectChildDirectives(in: child, allowing: [])
            let prose = Body.prose(of: child, includingCode: true)
            guard !prose.isEmpty else {
                throw LessonParseError(
                    .emptyBody(directive: child.name), at: .at(child.nameLocation))
            }
            explanation = prose
        }

        return QuizBlock(
            id: id,
            question: question,
            choices: choices,
            answerID: answerID,
            explanation: explanation,
            span: .span(of: directive))
    }

    private static func reflection(_ directive: BlockDirective) throws(LessonParseError)
        -> ReflectionBlock
    {
        var arguments = try DirectiveArguments(directive)
        let id = try arguments.identifier("id")
        try arguments.finish()
        try rejectChildDirectives(in: directive, allowing: [DirectiveNames.prompt])

        var prompts: [ReflectionBlock.Prompt] = []
        var seen: Set<String> = []
        for child in Body.childDirectives(of: directive, named: DirectiveNames.prompt) {
            var childArguments = try DirectiveArguments(child)
            let promptID = try childArguments.identifier("id")
            try childArguments.finish()
            try rejectChildDirectives(in: child, allowing: [])
            guard seen.insert(promptID).inserted else {
                throw LessonParseError(
                    .duplicatePromptID(directive: directive.name, prompt: promptID),
                    at: .at(child.nameLocation))
            }
            let prose = Body.prose(of: child, includingCode: true)
            guard !prose.isEmpty else {
                throw LessonParseError(
                    .emptyBody(directive: child.name), at: .at(child.nameLocation))
            }
            prompts.append(
                ReflectionBlock.Prompt(id: promptID, prose: prose, span: .span(of: child)))
        }

        guard !prompts.isEmpty else {
            throw LessonParseError(
                .tooFewPrompts(directive: directive.name), at: .at(directive.nameLocation))
        }
        return ReflectionBlock(id: id, prompts: prompts, span: .span(of: directive))
    }

    // MARK: - 하위 디렉티브 화이트리스트

    private static func rejectChildDirectives(
        in directive: BlockDirective, allowing allowed: [String]
    ) throws(LessonParseError) {
        for child in directive.children {
            guard let childDirective = child as? BlockDirective else { continue }
            guard allowed.contains(childDirective.name) else {
                throw LessonParseError(
                    .unexpectedChildDirective(
                        parent: directive.name, child: childDirective.name),
                    at: .at(childDirective.nameLocation))
            }
        }
    }
}

/// 본문 하위 디렉티브 이름. 6블록 디렉티브와 달리 이들은 블록이 아니라 **부품**이다.
public enum DirectiveNames {
    public static let answer = "Answer"
    public static let hint = "Hint"
    public static let question = "Question"
    public static let choice = "Choice"
    public static let explanation = "Explanation"
    public static let prompt = "Prompt"

    /// 스펙이 아는 모든 디렉티브 이름.
    public static let all: [String] =
        LessonBlockKind.requiredSequence.map(\.directiveName)
        + [answer, hint, question, choice, explanation, prompt]
}
