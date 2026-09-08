import Foundation
import LearnCore
import Testing

@testable import ContentKit

@Suite("레슨 파서 — 6블록 시퀀스")
struct LessonParserTests {
    @Test("레퍼런스 레슨이 6블록 순서로 파싱된다")
    func referenceLessonParses() throws {
        let blocks = try LessonParser.parse(source: ReferenceLesson.full)
        #expect(blocks.map(\.kind) == LessonBlockKind.requiredSequence)
        #expect(blocks.map(\.id) == ["intro", "run-it", "fill-it", "do-it", "check-it", "think-it"])
    }

    @Test("블록마다 값이 제자리에 담긴다")
    func blockPayloads() throws {
        let blocks = try LessonParser.parse(source: ReferenceLesson.full)
        let document = LessonDocument(
            stableID: LessonID("ref"), languages: [.swift], blocks: blocks)

        let concept = try #require(document.concept)
        #expect(concept.prose.contains("옵셔널은 값이 없을 수 있음"))

        let example = try #require(document.example(for: document.primaryLanguage))
        #expect(example.language == .swift)
        #expect(example.code == "print(\"hello\")\n")
        #expect(example.codeFenceLanguage == "swift")
        #expect(example.expectedStdoutPath.rawValue == "expected/run-it.txt")
        // 코드 블록은 payload 라서 산문에서 빠진다.
        #expect(!example.prose.contains("print"))

        let blank = try #require(document.blank(for: document.primaryLanguage))
        #expect(blank.slots.map(\.index) == [1])
        #expect(blank.slots[0].answer == "??")
        #expect(blank.filledTemplate() == "let value = maybe ?? 0\n")

        let task = try #require(document.task(for: document.primaryLanguage))
        #expect(task.starterPath.rawValue == "starters/a.swift")
        #expect(task.testsPath.rawValue == "tests/a.swift")
        #expect(task.solutionPath.rawValue == "solutions/a.swift")
        #expect(task.hints.map(\.order) == [1])

        let quiz = try #require(document.quiz)
        #expect(quiz.choices.map(\.id) == ["yes", "no"])
        #expect(quiz.answerID == "yes")
        #expect(quiz.answer?.prose == "크래시한다.")
        #expect(quiz.explanation != nil)

        let reflection = try #require(document.reflection)
        #expect(reflection.prompts.map(\.id) == ["design"])
    }

    @Test("Markup 트리는 밖으로 나가지 않는다 — 블록은 전부 Sendable 값이다")
    func blocksAreSendableValues() throws {
        let blocks = try LessonParser.parse(source: ReferenceLesson.full)
        // 컴파일이 곧 단언이다. Sendable 이 아니면 이 클로저 캡처가 컴파일되지 않는다.
        let captured: @Sendable () -> Int = { blocks.count }
        #expect(captured() == 6)
    }

    // MARK: - 거부

    @Test("미지 디렉티브는 throw")
    func unknownDirectiveThrows() {
        let source = ReferenceLesson.joined([
            ReferenceLesson.concept,
            "@Sidebar(id: nope) {\n본문\n}",
            ReferenceLesson.example, ReferenceLesson.blank, ReferenceLesson.task,
            ReferenceLesson.quiz, ReferenceLesson.reflection,
        ])
        #expect(throws: LessonParseError.self) { try LessonParser.parse(source: source) }
        let error = parseError(source)
        #expect(error?.reason == .unknownDirective("Sidebar"))
        #expect(error?.position.line == 7)
    }

    @Test("순서 위반은 throw")
    func outOfOrderThrows() {
        let source = ReferenceLesson.joined([
            ReferenceLesson.concept, ReferenceLesson.blank, ReferenceLesson.example,
            ReferenceLesson.task, ReferenceLesson.quiz, ReferenceLesson.reflection,
        ])
        let error = parseError(source)
        #expect(error?.reason == .blockOutOfOrder(found: .blank, expected: .example))
    }

    @Test("블록 누락은 throw", arguments: LessonBlockKind.allCases)
    func missingBlockThrows(_ kind: LessonBlockKind) {
        let error = parseError(ReferenceLesson.dropping(kind))
        // 마지막 블록이 빠지면 `missingBlock`, 중간이 빠지면 그 자리에서 순서 위반이 먼저 걸린다.
        switch error?.reason {
        case .missingBlock, .blockOutOfOrder:
            break
        default:
            Issue.record("기대와 다른 실패: \(String(describing: error?.reason))")
        }
    }

    @Test("마지막 블록이 빠지면 missingBlock 으로 특정된다")
    func missingLastBlock() {
        let error = parseError(ReferenceLesson.dropping(.reflection))
        #expect(error?.reason == .missingBlock(.reflection))
    }

    @Test("같은 블록이 두 번이면 throw")
    func duplicateBlockThrows() {
        let source = ReferenceLesson.joined([
            ReferenceLesson.concept, ReferenceLesson.concept, ReferenceLesson.example,
            ReferenceLesson.blank, ReferenceLesson.task, ReferenceLesson.quiz,
            ReferenceLesson.reflection,
        ])
        #expect(parseError(source)?.reason == .duplicateBlock(.concept))
    }

    @Test("최상위 산문은 throw — 6블록 디렉티브만 올 수 있다")
    func topLevelProseThrows() {
        let source = "# 옵셔널\n\n" + ReferenceLesson.full
        #expect(parseError(source)?.reason == .unexpectedTopLevelContent("제목"))
    }

    @Test("경로 접두사가 다르면 throw")
    func wrongDirectoryThrows() {
        let broken = """
            @Task(id: do-it, language: swift, starter: solutions/a.swift, tests: tests/a.swift, solution: solutions/a.swift) {
            본문
            }
            """
        let error = parseError(ReferenceLesson.replacing(.task, with: broken))
        #expect(
            error?.reason
                == .pathOutsideDirectory(
                    directive: "Task", argument: "starter", value: "solutions/a.swift",
                    expected: "starters"))
    }

    @Test("모르는 언어 토큰은 throw")
    func unknownLanguageThrows() {
        // 예전에는 `rust` 가 이 자리의 예시였다. 2026-09-07 에 Rust 실행기·채점기가 생기면서
        // 실제로 지원 언어가 됐으므로, 아직 백엔드가 없는 언어로 바꾼다. 허용 목록은
        // `LessonParser.supportedLanguages` 에서 파생시켜 여기에 두 번 적지 않는다 —
        // 손으로 적으면 언어를 더할 때마다 이 줄이 낡는다.
        let broken = """
            @Example(id: run-it, language: haskell, expected: expected/run-it.txt) {
            본문

            ```haskell
            main = putStrLn "hi"
            ```
            }
            """
        let error = parseError(ReferenceLesson.replacing(.example, with: broken))
        #expect(
            error?.reason
                == .unknownArgumentToken(
                    directive: "Example", argument: "language", value: "haskell",
                    allowed: LessonParser.supportedLanguages.map(\.rawValue)))
    }

    @Test("에러 메시지에 경로와 line:column 이 붙는다")
    func errorCarriesPathAndPosition() {
        let source = ReferenceLesson.replacing(
            .concept, with: "@Concept(id: intro) {\n@Answer(slot: 1) {\nx\n}\n}")
        let error = parseError(source, path: "lessons/x.md")
        let text = error?.description ?? ""
        #expect(text.hasPrefix("lessons/x.md:"), "실제: \(text)")
        #expect(error?.position == SourcePosition(line: 2, column: 1), "실제: \(text)")
    }

    private func parseError(_ source: String, path: String? = nil) -> LessonParseError? {
        do {
            _ = try LessonParser.parse(source: source, path: path)
            return nil
        } catch {
            return error
        }
    }
}

@Suite("레슨 파서 — 블록 본문 규칙")
struct LessonBodyRuleTests {
    @Test("Example 에 코드 블록이 없으면 throw")
    func exampleNeedsCode() {
        let broken = """
            @Example(id: run-it, language: swift, expected: expected/run-it.txt) {
            코드가 없다.
            }
            """
        #expect(error(for: broken, kind: .example)?.reason == .missingCodeBlock(directive: "Example"))
    }

    @Test("Example 에 코드 블록이 둘이면 throw")
    func exampleRejectsTwoCodeBlocks() {
        let broken = """
            @Example(id: run-it, language: swift, expected: expected/run-it.txt) {
            둘이다.

            ```swift
            print(1)
            ```

            ```swift
            print(2)
            ```
            }
            """
        #expect(
            error(for: broken, kind: .example)?.reason == .multipleCodeBlocks(directive: "Example"))
    }

    @Test("빈칸 표식과 Answer 슬롯이 어긋나면 throw")
    func blankSlotMismatch() {
        let broken = """
            @Blank(id: fill-it, language: swift) {
            두 칸인데 정답이 하나다.

            ```swift
            let a = ___1___ + ___2___
            ```

            @Answer(slot: 1) {
            `1`
            }
            }
            """
        #expect(
            error(for: broken, kind: .blank)?.reason
                == .blankSlotMismatch(directive: "Blank", markers: [1, 2], answers: [1]))
    }

    @Test("Answer 슬롯 중복은 throw")
    func duplicateAnswerSlot() {
        let broken = """
            @Blank(id: fill-it, language: swift) {
            한 칸.

            ```swift
            let a = ___1___
            ```

            @Answer(slot: 1) {
            `1`
            }

            @Answer(slot: 1) {
            `2`
            }
            }
            """
        #expect(
            error(for: broken, kind: .blank)?.reason
                == .duplicateAnswerSlot(directive: "Blank", slot: 1))
    }

    @Test("선택지가 하나뿐이면 throw")
    func quizNeedsTwoChoices() {
        let broken = """
            @Quiz(id: check-it, answer: yes) {
            @Question {
            질문?
            }

            @Choice(id: yes) {
            하나뿐.
            }
            }
            """
        #expect(
            error(for: broken, kind: .quiz)?.reason == .tooFewChoices(directive: "Quiz", count: 1))
    }

    @Test("정답 키가 선택지에 없으면 throw")
    func quizAnswerMustBeAChoice() {
        let broken = """
            @Quiz(id: check-it, answer: maybe) {
            @Question {
            질문?
            }

            @Choice(id: yes) {
            예.
            }

            @Choice(id: no) {
            아니오.
            }
            }
            """
        #expect(
            error(for: broken, kind: .quiz)?.reason
                == .answerNotAChoice(directive: "Quiz", answer: "maybe", choices: ["yes", "no"]))
    }

    @Test("Quiz 안의 낯선 하위 디렉티브는 throw")
    func quizRejectsForeignChild() {
        let broken = """
            @Quiz(id: check-it, answer: yes) {
            @Question {
            질문?
            }

            @Hint {
            여기 오면 안 된다.
            }

            @Choice(id: yes) {
            예.
            }

            @Choice(id: no) {
            아니오.
            }
            }
            """
        #expect(
            error(for: broken, kind: .quiz)?.reason
                == .unexpectedChildDirective(parent: "Quiz", child: "Hint"))
    }

    @Test("Reflection 에 Prompt 가 없으면 throw")
    func reflectionNeedsPrompt() {
        let broken = """
            @Reflection(id: think-it) {
            프롬프트가 없다.
            }
            """
        #expect(
            error(for: broken, kind: .reflection)?.reason == .tooFewPrompts(directive: "Reflection"))
    }

    @Test("Concept 본문이 비면 throw")
    func conceptNeedsProse() {
        // 중괄호 없는 디렉티브는 본문이 아예 없다.
        let broken = "@Concept(id: intro)"
        #expect(error(for: broken, kind: .concept)?.reason == .missingProse(directive: "Concept"))
    }

    private func error(for replacement: String, kind: LessonBlockKind) -> LessonParseError? {
        do {
            _ = try LessonParser.parse(source: ReferenceLesson.replacing(kind, with: replacement))
            return nil
        } catch {
            return error
        }
    }
}

/// {#block-language-variants} — 알고리즘 트랙이 성립하려면 레슨 하나가 여러 언어의 풀이를
/// 담을 수 있어야 한다. 개념·퀴즈·돌아보기는 언어와 무관하므로 공용이다.
@Suite("레슨 파서 — 언어 변형")
struct LessonLanguageVariantTests {
    /// 예제·빈칸·과제를 언어마다 하나씩. 개념·퀴즈·돌아보기는 그대로 하나씩이다.
    private static func twoLanguageSource() -> String {
        func retagged(_ block: String, id: String, language: String) -> String {
            block
                .replacingOccurrences(of: "language: swift", with: "language: \(language)")
                .replacingOccurrences(of: "id: run-it", with: "id: \(id)")
                .replacingOccurrences(of: "id: fill-it", with: "id: \(id)")
                .replacingOccurrences(of: "id: do-it", with: "id: \(id)")
        }
        return ReferenceLesson.joined([
            ReferenceLesson.concept,
            ReferenceLesson.example,
            retagged(ReferenceLesson.example, id: "run-it-py", language: "python"),
            ReferenceLesson.blank,
            retagged(ReferenceLesson.blank, id: "fill-it-py", language: "python"),
            ReferenceLesson.task,
            retagged(ReferenceLesson.task, id: "do-it-py", language: "python"),
            ReferenceLesson.quiz,
            ReferenceLesson.reflection,
        ])
    }

    @Test("예제·빈칸·과제는 언어마다 반복되고 개념·퀴즈·돌아보기는 하나씩이다")
    func variantsParse() throws {
        let blocks = try LessonParser.parse(source: Self.twoLanguageSource())
        #expect(blocks.map(\.kind) == [
            .concept, .example, .example, .blank, .blank, .task, .task, .quiz, .reflection,
        ])

        let document = LessonDocument(
            stableID: LessonID("ref"),
            languages: LessonParser.orderedLanguages(in: blocks),
            blocks: blocks)
        // 선언 순서가 그대로 언어 목록이 된다 — 화면의 선택 순서다.
        #expect(document.languages == [.swift, .python])
        #expect(document.primaryLanguage == .swift)
        #expect(document.examples.count == 2)
        #expect(document.task(for: .python)?.id == "do-it-py")
        #expect(document.blank(for: .swift)?.id == "fill-it")
    }

    @Test("고른 언어로 보면 다시 6블록이다 — 공용 블록은 어느 언어에서나 보인다")
    func blocksForOneLanguage() throws {
        let blocks = try LessonParser.parse(source: Self.twoLanguageSource())
        let document = LessonDocument(
            stableID: LessonID("ref"),
            languages: LessonParser.orderedLanguages(in: blocks),
            blocks: blocks)

        for language in document.languages {
            let view = document.blocks(for: language)
            #expect(view.map(\.kind) == LessonBlockKind.requiredSequence)
            #expect(view.compactMap(\.language).allSatisfy { $0 == language })
            #expect(document.concept != nil)
        }
    }

    @Test("언어가 하나인 레슨은 규칙이 그대로다 — 기존 팩이 손대지 않고 통과한다")
    func singleLanguageUnchanged() throws {
        let blocks = try LessonParser.parse(source: ReferenceLesson.full)
        let document = LessonDocument(
            stableID: LessonID("ref"),
            languages: LessonParser.orderedLanguages(in: blocks),
            blocks: blocks)
        #expect(document.languages == [.swift])
        #expect(document.blocks(for: .swift) == blocks)
    }

    @Test("같은 언어로 같은 블록을 두 번 쓰면 throw")
    func duplicateLanguageThrows() throws {
        let source = ReferenceLesson.joined([
            ReferenceLesson.concept,
            ReferenceLesson.example,
            // 언어는 그대로 swift 인데 id 만 다르다 — 변형이 아니라 중복이다.
            ReferenceLesson.example.replacingOccurrences(of: "id: run-it", with: "id: run-it-2"),
            ReferenceLesson.blank,
            ReferenceLesson.task,
            ReferenceLesson.quiz,
            ReferenceLesson.reflection,
        ])
        let error = try #require(parseError(source))
        #expect(error.reason == .duplicateLanguage(kind: .example, language: .swift))
    }

    @Test("한 언어에 과제가 없으면 throw — 읽기만 하고 풀 수 없는 상태를 막는다")
    func languageWithoutTaskThrows() throws {
        let source = ReferenceLesson.joined([
            ReferenceLesson.concept,
            ReferenceLesson.example,
            ReferenceLesson.example
                .replacingOccurrences(of: "language: swift", with: "language: python")
                .replacingOccurrences(of: "id: run-it", with: "id: run-it-py"),
            ReferenceLesson.blank,
            ReferenceLesson.blank
                .replacingOccurrences(of: "language: swift", with: "language: python")
                .replacingOccurrences(of: "id: fill-it", with: "id: fill-it-py"),
            // python 과제가 빠졌다.
            ReferenceLesson.task,
            ReferenceLesson.quiz,
            ReferenceLesson.reflection,
        ])
        let error = try #require(parseError(source))
        #expect(error.reason == .languageWithoutBlock(language: .python, missing: .task))
    }

    @Test("매니페스트가 선언한 언어가 본문에 없으면 throw")
    func manifestLanguageMismatchThrows() throws {
        #expect(throws: LessonParseError.self) {
            try LessonParser.parseDocument(
                source: ReferenceLesson.full,
                stableID: LessonID("ref"),
                languages: [.python])  // 본문은 swift 뿐이다
        }
    }

    private func parseError(_ source: String) -> LessonParseError? {
        do {
            _ = try LessonParser.parse(source: source)
            return nil
        } catch {
            return error
        }
    }
}
