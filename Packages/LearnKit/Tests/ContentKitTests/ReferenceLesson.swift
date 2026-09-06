import Foundation

@testable import ContentKit

/// 파서 테스트가 공유하는 6블록 레퍼런스 레슨.
///
/// 블록마다 소스를 갈아끼울 수 있게 나눠 둔다 — "이 블록만 망가진 레슨"을 만드는 것이
/// 파서 테스트의 대부분이고, 매번 전문을 다시 쓰면 무엇이 달라졌는지 보이지 않는다.
enum ReferenceLesson {
    static let concept = """
        @Concept(id: intro) {
        옵셔널은 값이 없을 수 있음을 타입에 적어 둔 것이다.

        `String` 과 `String?` 은 서로 다른 타입이다.
        }
        """

    static let example = """
        @Example(id: run-it, language: swift, expected: expected/run-it.txt) {
        아래를 실행해 결과를 확인한다.

        ```swift
        print("hello")
        ```
        }
        """

    static let blank = """
        @Blank(id: fill-it, language: swift) {
        한 칸을 채워라.

        ```swift
        let value = maybe ___1___ 0
        ```

        @Answer(slot: 1) {
        `??`
        }
        }
        """

    static let task = """
        @Task(id: do-it, language: swift, starter: starters/a.swift, tests: tests/a.swift, solution: solutions/a.swift) {
        `safeDivide` 를 완성해라.

        @Hint {
        `guard` 로 먼저 걸러라.
        }
        }
        """

    static let quiz = """
        @Quiz(id: check-it, answer: yes) {
        @Question {
        옵셔널을 강제 언래핑하면 nil 일 때 어떻게 되는가?
        }

        @Choice(id: yes) {
        크래시한다.
        }

        @Choice(id: no) {
        0 이 나온다.
        }

        @Explanation {
        강제 언래핑은 컴파일러와 한 약속이고, 틀리면 런타임에 트랩이 걸린다.
        }
        }
        """

    static let reflection = """
        @Reflection(id: think-it) {
        @Prompt(id: design) {
        실패를 옵셔널로 돌려줄지 던질지 어떻게 정하겠는가?
        }
        }
        """

    /// 여섯 블록을 순서대로 이어 붙인 완전한 레슨.
    static var full: String { joined([concept, example, blank, task, quiz, reflection]) }

    static func joined(_ blocks: [String]) -> String {
        blocks.joined(separator: "\n\n") + "\n"
    }

    /// 블록 하나만 갈아끼운 레슨.
    static func replacing(_ kind: LessonBlockKind, with replacement: String) -> String {
        var blocks = [concept, example, blank, task, quiz, reflection]
        guard let index = LessonBlockKind.requiredSequence.firstIndex(of: kind) else {
            return full
        }
        blocks[index] = replacement
        return joined(blocks)
    }

    /// 블록 하나를 뺀 레슨.
    static func dropping(_ kind: LessonBlockKind) -> String {
        var blocks = [concept, example, blank, task, quiz, reflection]
        guard let index = LessonBlockKind.requiredSequence.firstIndex(of: kind) else {
            return full
        }
        blocks.remove(at: index)
        return joined(blocks)
    }
}
