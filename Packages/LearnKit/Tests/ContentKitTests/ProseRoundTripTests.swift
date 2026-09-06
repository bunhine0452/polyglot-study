import Foundation
import LearnCore
import Testing

@testable import ContentKit

/// `Body.prose` 왕복 고정. **디렉티브 본문에 적은 마크다운이 그대로 나와야 한다.**
///
/// 여기서 지키는 계약은 렌더러 하나만의 것이 아니다. 같은 문자열을 `packtool` 리포트와
/// 튜터 RAG 가 받으므로, 들여쓰기 한 단이 새어 들어가면 CommonMark 로 다시 읽는 쪽에서
/// 구조 자체가 달라진다(평평한 목록 → 중첩 목록, 인용 → 인용 속 코드블록).
///
/// 아래 다섯 케이스는 전부 **실측된 회귀**다. 원인은 두 가지였고 둘 다
/// `Sources/ContentKit/Lesson/DirectiveBody.swift` 에서 막는다 —
/// 포맷 전 `detachedFromParent`, 그리고 `orderedListNumerals: .incrementing`.
@Suite("산문 왕복 — 방출기가 구조를 바꾸지 않는다")
struct ProseRoundTripTests {
    /// `@Concept` 본문에 산문을 넣고 파싱해 꺼낸다. 깊이 1 디렉티브다.
    static func conceptProse(_ body: String) throws -> String {
        let concept = """
            @Concept(id: intro) {
            \(body)
            }
            """
        let blocks = try LessonParser.parse(
            source: ReferenceLesson.replacing(.concept, with: concept))
        let document = LessonDocument(
            stableID: LessonID("round-trip"), language: .swift, blocks: blocks)
        return try #require(document.concept).prose
    }

    /// `@Task` 안의 `@Hint` 본문. 깊이 2 디렉티브라 예전에는 8칸이 붙었다.
    static func hintProse(_ body: String) throws -> String {
        let task = """
            @Task(id: do-it, language: swift, starter: starters/a.swift, \
            tests: tests/a.swift, solution: solutions/a.swift) {
            바깥 산문.

            @Hint {
            \(body)
            }
            }
            """
        let blocks = try LessonParser.parse(source: ReferenceLesson.replacing(.task, with: task))
        let document = LessonDocument(
            stableID: LessonID("round-trip"), language: .swift, blocks: blocks)
        return try #require(document.task).hints[0].prose
    }

    // MARK: - 증상 1 — 평평한 목록이 중첩 목록이 되던 것

    @Test("평평한 목록이 평평하게 나온다 — 둘째 항목에 4칸이 붙지 않는다")
    func flatListStaysFlat() throws {
        let prose = try Self.conceptProse("- 첫째\n- 둘째\n- 셋째")
        #expect(prose == "- 첫째\n- 둘째\n- 셋째")
        // 회귀의 정확한 모양을 못으로 박아 둔다.
        #expect(!prose.contains("\n    - "))
    }

    @Test("진짜 중첩 목록은 중첩으로 남는다 — 상대 구조가 뭉개지지 않는다")
    func realNestingSurvives() throws {
        let prose = try Self.conceptProse("- 바깥\n  - 안쪽")
        // 방출기는 중첩 한 단을 2칸으로 낸다(불릿 폭). 중요한 것은 0 이 아니라는 것.
        let lines = prose.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[0] == "- 바깥")
        #expect(lines[1].hasPrefix(" "), "중첩이 평평해졌다: \(prose.debugDescription)")
        #expect(lines[1].trimmingCharacters(in: .whitespaces) == "- 안쪽")
    }

    // MARK: - 증상 2 — 순서 목록 번호가 전부 1로 재작성되던 것

    @Test("순서 목록의 번호가 원문대로 증가한다")
    func orderedListKeepsNumbering() throws {
        let prose = try Self.conceptProse("1. 하나\n2. 둘\n3. 셋")
        #expect(prose == "1. 하나\n2. 둘\n3. 셋")
    }

    // MARK: - 증상 3 — 인용 안이 들여쓰기 코드블록이 되던 것

    @Test("인용은 '> ' 한 칸만 붙는다 — 인용 안이 코드블록이 되지 않는다")
    func blockquoteKeepsSingleSpace() throws {
        let prose = try Self.conceptProse("> 인용")
        #expect(prose == "> 인용")
        // `>` 뒤에 4칸 이상이면 CommonMark 는 인용 안을 들여쓰기 코드블록으로 읽는다.
        #expect(!prose.contains(">    "))
    }

    // MARK: - 증상 4 — 코드 펜스 본문과 닫는 펜스가 밀리던 것

    @Test("코드 펜스의 본문도 닫는 펜스도 열 0 에 있다")
    func codeFenceIsNotIndented() throws {
        let prose = try Self.conceptProse("```swift\nlet a = 1\nlet b = 2\n```")
        #expect(prose == "```swift\nlet a = 1\nlet b = 2\n```")
        for line in prose.split(separator: "\n", omittingEmptySubsequences: false) {
            #expect(!line.hasPrefix(" "), "밀린 줄: \(line.debugDescription)")
        }
    }

    @Test("코드 안의 진짜 들여쓰기는 남는다")
    func codeFenceKeepsItsOwnIndent() throws {
        let prose = try Self.conceptProse("```python\ndef f():\n    return 1\n```")
        #expect(prose == "```python\ndef f():\n    return 1\n```")
    }

    // MARK: - 증상 5 — 깊이 2 디렉티브에 8칸이 붙던 것

    @Test("깊이 2 디렉티브 본문에도 들여쓰기가 새지 않는다")
    func depthTwoDirectiveHasNoIndent() throws {
        let prose = try Self.hintProse("힌트 첫 줄.\n\n- 목록 첫째\n- 목록 둘째\n\n> 인용 안쪽")
        #expect(prose == "힌트 첫 줄.\n\n- 목록 첫째\n- 목록 둘째\n\n> 인용 안쪽")
        #expect(!prose.contains("        "))
    }

    @Test("`@Quiz` 의 `@Choice`·`@Question`, `@Reflection` 의 `@Prompt` 도 같다")
    func depthTwoSiblingsAreClean() throws {
        let quiz = """
            @Quiz(id: check-it, answer: yes) {
            @Question {
            어느 쪽인가?

            - 왼쪽
            - 오른쪽
            }

            @Choice(id: yes) {
            첫 줄.

            > 인용
            }

            @Choice(id: no) {
            0 이 나온다.
            }
            }
            """
        let reflection = """
            @Reflection(id: think-it) {
            @Prompt(id: design) {
            첫 줄.

            1. 하나
            2. 둘
            }
            }
            """
        let parsed = try LessonParser.parse(
            source: ReferenceLesson.joined([
                ReferenceLesson.concept, ReferenceLesson.example, ReferenceLesson.blank,
                ReferenceLesson.task, quiz, reflection,
            ]))
        let document = LessonDocument(
            stableID: LessonID("round-trip"), language: .swift, blocks: parsed)

        #expect(try #require(document.quiz).question == "어느 쪽인가?\n\n- 왼쪽\n- 오른쪽")
        #expect(try #require(document.quiz).choices[0].prose == "첫 줄.\n\n> 인용")
        #expect(try #require(document.reflection).prompts[0].prose == "첫 줄.\n\n1. 하나\n2. 둘")
    }

    // MARK: - 왕복 자체

    @Test("한 번 나온 산문을 다시 넣으면 같은 문자열이 나온다 — 고정점이다")
    func proseIsAFixedPoint() throws {
        let source = """
            문단 하나.

            - 첫째
            - 둘째

            1. 하나
            2. 둘

            > 인용

            ```swift
            let a = 1
            ```
            """
        let once = try Self.conceptProse(source)
        #expect(once == source)
        #expect(try Self.conceptProse(once) == once)
    }
}
