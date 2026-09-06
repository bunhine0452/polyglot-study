public import LearnCore

/// 레슨 한 편을 이루는 6블록 시퀀스. **순서가 계약이다.**
public enum LessonBlockKind: String, Hashable, Sendable, Codable, CaseIterable {
    case concept, example, blank, task, quiz, reflection

    /// 디렉티브 이름. 파서가 이름 → 종류로 쓰고, 직렬화기가 반대로 쓴다.
    public var directiveName: String {
        switch self {
        case .concept: "Concept"
        case .example: "Example"
        case .blank: "Blank"
        case .task: "Task"
        case .quiz: "Quiz"
        case .reflection: "Reflection"
        }
    }

    /// 레슨에 나타나야 하는 순서. `allCases` 순서와 같지만, 의존하지 않도록 명시한다.
    public static let requiredSequence: [LessonBlockKind] = [
        .concept, .example, .blank, .task, .quiz, .reflection,
    ]

    public static func kind(forDirective name: String) -> LessonBlockKind? {
        requiredSequence.first { $0.directiveName == name }
    }
}

// MARK: - 6종 값 타입

/// 개념 설명. 산문만 있고 실행되는 것이 없다.
public struct ConceptBlock: Hashable, Sendable {
    public var id: String
    /// 마크다운 **소스**. `Markup` 트리가 아니다 — 트리는 `Sendable` 이 아니라서
    /// 파싱 경계를 넘지 못한다. 렌더러는 이 문자열을 다시 파싱하거나 그대로 태운다.
    public var prose: String
    public var span: SourceSpan

    public init(id: String, prose: String, span: SourceSpan = .unknown) {
        self.id = id
        self.prose = prose
        self.span = span
    }
}

/// 실행 예제. 학습자는 읽고 실행 버튼을 누른다 — 편집하지 않는다.
public struct ExampleBlock: Hashable, Sendable {
    public var id: String
    public var language: LanguageID
    public var prose: String
    /// 본문의 펜스 코드 블록 하나. 실행기에 그대로 넘어간다.
    public var code: String
    /// 펜스의 info string (`​```python` 의 `python`). 없으면 nil.
    public var codeFenceLanguage: String?
    /// 기대 stdout 사이드카. 자유 텍스트를 인자에 못 싣기 때문에 파일로 뺐다.
    public var expectedStdoutPath: PackRelativePath
    public var span: SourceSpan

    public init(
        id: String,
        language: LanguageID,
        prose: String,
        code: String,
        codeFenceLanguage: String? = nil,
        expectedStdoutPath: PackRelativePath,
        span: SourceSpan = .unknown
    ) {
        self.id = id
        self.language = language
        self.prose = prose
        self.code = code
        self.codeFenceLanguage = codeFenceLanguage
        self.expectedStdoutPath = expectedStdoutPath
        self.span = span
    }
}

/// 빈칸 채우기. 코드에 `___1___` 같은 슬롯 표식이 있고 정답은 `@Answer` 본문에 있다.
public struct BlankBlock: Hashable, Sendable {
    public struct Slot: Hashable, Sendable {
        /// 1-기반. 표식 `___N___` 의 N.
        public var index: Int
        /// 정답 문자열. `@Answer` 본문의 평문이다 — 인자에 자유 텍스트를 못 싣는
        /// 이유가 바로 이것이다(콜론·괄호·쉼표가 정답에 흔하다).
        public var answer: String
        public var span: SourceSpan

        public init(index: Int, answer: String, span: SourceSpan = .unknown) {
            self.index = index
            self.answer = answer
            self.span = span
        }
    }

    public var id: String
    public var language: LanguageID
    public var prose: String
    /// 슬롯 표식이 박힌 코드.
    public var template: String
    public var codeFenceLanguage: String?
    /// `index` 오름차순. 1..n 을 빠짐없이 덮는다.
    public var slots: [Slot]
    public var span: SourceSpan

    public init(
        id: String,
        language: LanguageID,
        prose: String,
        template: String,
        codeFenceLanguage: String? = nil,
        slots: [Slot],
        span: SourceSpan = .unknown
    ) {
        self.id = id
        self.language = language
        self.prose = prose
        self.template = template
        self.codeFenceLanguage = codeFenceLanguage
        self.slots = slots
        self.span = span
    }

    /// 표식을 정답으로 바꾼 완성 코드. 채점기와 `packtool` 이 실행에 쓴다.
    ///
    /// 한 번만 훑는다 — 치환한 정답 안에 다시 표식 모양이 나타나도 재치환하지 않는다.
    public func filledTemplate() -> String {
        let answers = Dictionary(slots.map { ($0.index, $0.answer) }, uniquingKeysWith: { a, _ in a })
        return BlankSlotMarker.rewrite(template) { answers[$0] }
    }
}

/// 슬롯 표식 문법. 코드 안에 박히므로 어떤 언어에서도 유효 토큰이 아닌 형태여야 한다.
public enum BlankSlotMarker {
    /// `___1___` — 밑줄 3 + 숫자 + 밑줄 3.
    public static func marker(_ index: Int) -> String { "___\(index)___" }

    /// 밑줄 세 개.
    static let fence = "___"

    /// 템플릿에서 표식 번호를 나타난 순서대로 뽑는다.
    public static func indices(in template: String) -> [Int] {
        var found: [Int] = []
        _ = rewrite(template) { index in
            found.append(index)
            return nil
        }
        return found
    }

    /// 표식을 한 번만 훑으며 `replacement` 가 값을 주면 치환한다. nil 이면 원문을 남긴다.
    ///
    /// 스캐너를 하나로 모아둔 이유는 "번호 추출"과 "정답 채우기"가 같은 문법을 서로
    /// 다르게 해석하면 `packtool` 이 통과시킨 코드가 앱에서 다르게 채워지기 때문이다.
    static func rewrite(_ template: String, replacement: (Int) -> String?) -> String {
        var result = ""
        var remainder = Substring(template)
        while let open = remainder.firstRange(of: fence) {
            let afterOpen = remainder[open.upperBound...]
            if let close = afterOpen.firstRange(of: fence) {
                let digits = afterOpen[afterOpen.startIndex..<close.lowerBound]
                if !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }),
                    let index = Int(digits)
                {
                    result += remainder[remainder.startIndex..<open.lowerBound]
                    result += replacement(index) ?? String(remainder[open.lowerBound..<close.upperBound])
                    remainder = afterOpen[close.upperBound...]
                    continue
                }
            }
            result += remainder[remainder.startIndex..<open.upperBound]
            remainder = remainder[open.upperBound...]
        }
        result += remainder
        return result
    }
}

/// 테스트 과제. 학습자가 편집하고 숨은 테스트로 채점된다.
public struct TaskBlock: Hashable, Sendable {
    public struct Hint: Hashable, Sendable {
        /// 1-기반 표시 순서.
        public var order: Int
        public var prose: String

        public init(order: Int, prose: String) {
            self.order = order
            self.prose = prose
        }
    }

    public var id: String
    public var language: LanguageID
    public var prose: String
    /// `starters/…` — 학습자에게 주어지는 시작 코드.
    public var starterPath: PackRelativePath
    /// `tests/…` — 채점기가 돌리는 숨은 테스트.
    public var testsPath: PackRelativePath
    /// `solutions/…` — 정답. 배포 팩에서는 벗겨진다.
    public var solutionPath: PackRelativePath
    public var hints: [Hint]
    public var span: SourceSpan

    public init(
        id: String,
        language: LanguageID,
        prose: String,
        starterPath: PackRelativePath,
        testsPath: PackRelativePath,
        solutionPath: PackRelativePath,
        hints: [Hint] = [],
        span: SourceSpan = .unknown
    ) {
        self.id = id
        self.language = language
        self.prose = prose
        self.starterPath = starterPath
        self.testsPath = testsPath
        self.solutionPath = solutionPath
        self.hints = hints
        self.span = span
    }
}

/// 객관식 퀴즈. 정답 키는 선택지 id 를 가리키는 **식별자**다.
public struct QuizBlock: Hashable, Sendable {
    public struct Choice: Hashable, Sendable {
        public var id: String
        public var prose: String
        public var span: SourceSpan

        public init(id: String, prose: String, span: SourceSpan = .unknown) {
            self.id = id
            self.prose = prose
            self.span = span
        }
    }

    public var id: String
    /// `@Question` 본문.
    public var question: String
    /// 2개 이상. 문서에 적힌 순서 그대로.
    public var choices: [Choice]
    /// `choices` 중 하나의 id.
    public var answerID: String
    /// `@Explanation` 본문. 없을 수 있다.
    public var explanation: String?
    public var span: SourceSpan

    public init(
        id: String,
        question: String,
        choices: [Choice],
        answerID: String,
        explanation: String? = nil,
        span: SourceSpan = .unknown
    ) {
        self.id = id
        self.question = question
        self.choices = choices
        self.answerID = answerID
        self.explanation = explanation
        self.span = span
    }

    public var answer: Choice? { choices.first { $0.id == answerID } }
}

/// 회고. 채점하지 않는 열린 질문들.
public struct ReflectionBlock: Hashable, Sendable {
    public struct Prompt: Hashable, Sendable {
        public var id: String
        public var prose: String
        public var span: SourceSpan

        public init(id: String, prose: String, span: SourceSpan = .unknown) {
            self.id = id
            self.prose = prose
            self.span = span
        }
    }

    public var id: String
    /// 1개 이상.
    public var prompts: [Prompt]
    public var span: SourceSpan

    public init(id: String, prompts: [Prompt], span: SourceSpan = .unknown) {
        self.id = id
        self.prompts = prompts
        self.span = span
    }
}

// MARK: - 합

/// 파싱된 블록 하나. 파서가 밖으로 내보내는 **유일한** 타입이고, 전부 값 타입이다.
public enum LessonBlock: Hashable, Sendable {
    case concept(ConceptBlock)
    case example(ExampleBlock)
    case blank(BlankBlock)
    case task(TaskBlock)
    case quiz(QuizBlock)
    case reflection(ReflectionBlock)

    public var kind: LessonBlockKind {
        switch self {
        case .concept: .concept
        case .example: .example
        case .blank: .blank
        case .task: .task
        case .quiz: .quiz
        case .reflection: .reflection
        }
    }

    public var id: String {
        switch self {
        case .concept(let block): block.id
        case .example(let block): block.id
        case .blank(let block): block.id
        case .task(let block): block.id
        case .quiz(let block): block.id
        case .reflection(let block): block.id
        }
    }

    public var span: SourceSpan {
        switch self {
        case .concept(let block): block.span
        case .example(let block): block.span
        case .blank(let block): block.span
        case .task(let block): block.span
        case .quiz(let block): block.span
        case .reflection(let block): block.span
        }
    }

    /// 이 블록이 실행기를 태우는가. `packtool` 의 실행 게이트가 고르는 기준.
    public var language: LanguageID? {
        switch self {
        case .example(let block): block.language
        case .blank(let block): block.language
        case .task(let block): block.language
        case .concept, .quiz, .reflection: nil
        }
    }
}

/// 6블록이 순서대로 갖춰진 레슨 하나. 파서가 검증을 통과시킨 뒤에만 만들어진다.
public struct LessonDocument: Hashable, Sendable {
    public var stableID: LessonID
    public var language: LanguageID
    /// 정확히 6개, ``LessonBlockKind/requiredSequence`` 순서.
    public var blocks: [LessonBlock]
    /// 팩 상대 경로. 진단 메시지의 접두사로 쓴다.
    public var path: PackRelativePath?

    public init(
        stableID: LessonID,
        language: LanguageID,
        blocks: [LessonBlock],
        path: PackRelativePath? = nil
    ) {
        self.stableID = stableID
        self.language = language
        self.blocks = blocks
        self.path = path
    }

    public var concept: ConceptBlock? {
        for case .concept(let block) in blocks { return block }
        return nil
    }
    public var example: ExampleBlock? {
        for case .example(let block) in blocks { return block }
        return nil
    }
    public var blank: BlankBlock? {
        for case .blank(let block) in blocks { return block }
        return nil
    }
    public var task: TaskBlock? {
        for case .task(let block) in blocks { return block }
        return nil
    }
    public var quiz: QuizBlock? {
        for case .quiz(let block) in blocks { return block }
        return nil
    }
    public var reflection: ReflectionBlock? {
        for case .reflection(let block) in blocks { return block }
        return nil
    }

    /// 이 레슨이 참조하는 사이드카 파일 전부. 매니페스트 `files` 대조에 쓴다.
    public var referencedFiles: [PackRelativePath] {
        var paths: [PackRelativePath] = []
        if let example { paths.append(example.expectedStdoutPath) }
        if let task {
            paths.append(task.starterPath)
            paths.append(task.testsPath)
            paths.append(task.solutionPath)
        }
        return paths
    }
}
