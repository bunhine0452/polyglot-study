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

    /// 언어마다 한 번씩 반복될 수 있는 종류인가 — {#block-language-variants}.
    ///
    /// 실행기를 태우는 셋만 참이다. 개념·퀴즈·돌아보기는 언어와 무관한 내용이라 공용이다.
    public var allowsLanguageVariants: Bool {
        switch self {
        case .example, .blank, .task: true
        case .concept, .quiz, .reflection: false
        }
    }
}

// MARK: - 6종 값 타입

/// 개념에 붙는 시각화 하나 — {#visualize-directive}.
///
/// **왜 개념의 일부인가**: 시각화는 개념을 *보여주는* 것이지 별도의 학습 단계가 아니다.
/// 블록으로 독립시키려면 레슨의 블록 수가 6에서 7로 늘어야 하는데, 그 값은 전역이다
/// (`LearnCore.LessonBlockSequence.count`, DB 의 `CHECK (current_block_index BETWEEN 0 AND 5)`).
/// 7로 올리면 **기존 122편이 전부 "블록 4 / 7" 로 보이고 영원히 완료되지 않는다.**
/// 레슨마다 블록 수가 다를 수 있게 만드는 것은 진도·대시보드 칸·마이그레이션을 함께
/// 건드리는 별개의 일이라, 그때까지는 개념 안에 둔다.
///
/// 언어와 무관하다 — 이진 탐색이 어떻게 도는지는 Rust 로 풀든 Python 으로 풀든 같다.
public struct LessonVisualization: Hashable, Sendable {
    /// `visuals/<id>.json` 의 `id` 필드와 같아야 한다. 검증은 `packtool` 이 한다.
    public var id: String
    /// `visuals/…` 사이드카. 프레임 배열이 여기 들어 있다.
    public var framesPath: PackRelativePath

    public init(id: String, framesPath: PackRelativePath) {
        self.id = id
        self.framesPath = framesPath
    }
}

/// 개념 설명. 산문만 있고 실행되는 것이 없다.
public struct ConceptBlock: Hashable, Sendable {
    public var id: String
    /// 마크다운 **소스**. `Markup` 트리가 아니다 — 트리는 `Sendable` 이 아니라서
    /// 파싱 경계를 넘지 못한다. 렌더러는 이 문자열을 다시 파싱하거나 그대로 태운다.
    public var prose: String
    /// 있으면 개념 화면이 재생기를 함께 그린다. 대부분의 레슨에는 없다.
    public var visualization: LessonVisualization?
    public var span: SourceSpan

    public init(
        id: String,
        prose: String,
        visualization: LessonVisualization? = nil,
        span: SourceSpan = .unknown
    ) {
        self.id = id
        self.prose = prose
        self.visualization = visualization
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
    /// 이 레슨을 풀 수 있는 언어들 — **선언 순서 그대로**. 비어 있지 않다.
    ///
    /// 첫 번째가 기본 선택이다. 파서가 "선언한 언어마다 예제·빈칸·과제가 모두 있음" 을
    /// 이미 보장했으므로, 이 목록의 어느 언어를 골라도 6블록이 완성된다.
    public var languages: [LanguageID]
    /// ``LessonBlockKind/requiredSequence`` 순서. 예제·빈칸·과제는 언어 수만큼 반복된다.
    public var blocks: [LessonBlock]
    /// 팩 상대 경로. 진단 메시지의 접두사로 쓴다.
    public var path: PackRelativePath?

    public init(
        stableID: LessonID,
        languages: [LanguageID],
        blocks: [LessonBlock],
        path: PackRelativePath? = nil
    ) {
        self.stableID = stableID
        self.languages = languages
        self.blocks = blocks
        self.path = path
    }

    /// 언어를 고르지 않은 자리의 기본값.
    public var primaryLanguage: LanguageID { languages[0] }

    // MARK: 공용 블록 — 언어와 무관하다

    public var concept: ConceptBlock? {
        for case .concept(let block) in blocks { return block }
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

    // MARK: 언어별 블록

    /// 전부. 실행 게이트처럼 **모든 언어를 돌려야 하는** 쪽이 쓴다.
    public var examples: [ExampleBlock] {
        blocks.compactMap { if case .example(let b) = $0 { b } else { nil } }
    }
    public var blanks: [BlankBlock] {
        blocks.compactMap { if case .blank(let b) = $0 { b } else { nil } }
    }
    public var tasks: [TaskBlock] {
        blocks.compactMap { if case .task(let b) = $0 { b } else { nil } }
    }

    public func example(for language: LanguageID) -> ExampleBlock? {
        examples.first { $0.language == language }
    }
    public func blank(for language: LanguageID) -> BlankBlock? {
        blanks.first { $0.language == language }
    }
    public func task(for language: LanguageID) -> TaskBlock? {
        tasks.first { $0.language == language }
    }

    /// 이 언어로 학습할 때 화면이 그리는 6블록 — 순서는 `requiredSequence` 그대로다.
    ///
    /// 언어가 하나인 레슨에서는 `blocks` 와 같다. 여럿이면 고른 언어의 것만 남는다.
    public func blocks(for language: LanguageID) -> [LessonBlock] {
        blocks.filter { block in
            guard let blockLanguage = block.language else { return true }
            return blockLanguage == language
        }
    }

    /// 이 레슨이 참조하는 사이드카 파일 전부. 매니페스트 `files` 대조에 쓴다.
    ///
    /// **모든 언어의 것을 센다.** 팩에는 언어별 시작 코드·테스트·정답이 전부 들어 있어야
    /// 하므로, 고른 언어의 것만 세면 나머지가 미등록 파일로 남는다.
    public var referencedFiles: [PackRelativePath] {
        var paths: [PackRelativePath] = []
        // 시각화 사이드카도 매니페스트에 등록돼 있어야 한다 — 안 그러면 설치가 미등록
        // 파일로 거부하거나, 반대로 팩에서 빠진 채 나가 재생기가 빈 화면을 그린다.
        if let visualization = concept?.visualization { paths.append(visualization.framesPath) }
        for example in examples { paths.append(example.expectedStdoutPath) }
        for task in tasks {
            paths.append(task.starterPath)
            paths.append(task.testsPath)
            paths.append(task.solutionPath)
        }
        return paths
    }
}
