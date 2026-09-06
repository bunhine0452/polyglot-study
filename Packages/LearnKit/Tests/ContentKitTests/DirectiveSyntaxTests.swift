import Foundation
import LearnCore
import Testing

@testable import ContentKit

@Suite("디렉티브 소스 렉시컬 검사 — swift-markdown 이 조용히 삼키는 것들")
struct DirectiveSourceLintTests {
    @Test("한 줄 중괄호 본문은 거부된다")
    func singleLineBodyRejected() {
        let violations = DirectiveSourceLint.violations(in: "@Concept(id: a) { 한 줄 본문 }\n")
        #expect(violations.count == 1)
        #expect(violations.first?.reason == .singleLineBody(directive: "Concept"))
        #expect(violations.first?.position == SourcePosition(line: 1, column: 1))
    }

    @Test("한 줄 본문은 줄 끝의 중괄호까지 삼킨다 — 그래서 금지한다")
    func singleLineBodySwallowsClosingBrace() {
        // `@x { y } z }` 는 파서가 통째로 본문으로 먹는다. 겉보기에는 닫힌 것 같지만
        // 실제로는 `y } z` 가 본문이 된다. 렉시컬 검사가 없으면 이걸 잡을 방법이 없다.
        let violations = DirectiveSourceLint.violations(in: "@Concept(id: a) { y } z }\n")
        #expect(violations.first?.reason == .singleLineBody(directive: "Concept"))
    }

    @Test("여러 줄 본문은 통과한다")
    func multiLineBodyAccepted() {
        let source = "@Concept(id: a) {\n본문\n}\n"
        #expect(DirectiveSourceLint.violations(in: source).isEmpty)
    }

    @Test("중괄호 없는 디렉티브 뒤 같은 줄 텍스트는 거부된다")
    func trailingTextRejected() {
        let violations = DirectiveSourceLint.violations(in: "@Concept(id: a) 버려질 텍스트\n")
        #expect(
            violations.first?.reason
                == .trailingTextAfterDirective(directive: "Concept", text: "버려질 텍스트"))
    }

    @Test("인자 목록이 다음 줄로 넘어가면 거부된다")
    func multiLineArgumentsRejected() {
        let source = "@Example(id: a,\n  language: swift) {\n본문\n}\n"
        #expect(
            DirectiveSourceLint.violations(in: source).first?.reason
                == .headerNotSingleLine(directive: "Example"))
    }

    @Test("닫는 중괄호는 한 줄을 독차지해야 한다")
    func closingBraceMustBeAlone() {
        let source = "@Concept(id: a) {\n본문\n} 꼬리\n"
        #expect(
            DirectiveSourceLint.violations(in: source).first?.reason
                == .closingBraceNotAlone("} 꼬리"))
    }

    @Test("펜스 코드 블록 안의 @대문자 는 디렉티브가 아니다")
    func fencedCodeIsNotScanned() {
        let source = """
            @Concept(id: a) {
            본문

            ```swift
            @Test("x") { 이것은 코드다 }
            @State private var x = 0 여기 텍스트
            ```
            }
            """
        #expect(DirectiveSourceLint.violations(in: source).isEmpty)
    }

    @Test("소문자로 시작하는 @ 는 디렉티브가 아니다 — 파이썬 데코레이터 오탐 방지")
    func lowercaseAtIsNotADirective() {
        #expect(DirectiveSourceLint.violations(in: "@dataclass 뒤 텍스트\n").isEmpty)
    }

    @Test("위반이 여럿이면 소스 순서대로 나온다")
    func violationsAreOrdered() {
        let source = "@A(id: x) 꼬리\n\n@B(id: y) { 한 줄 }\n"
        let violations = DirectiveSourceLint.violations(in: source)
        #expect(violations.count == 2)
        #expect(violations[0].position.line == 1)
        #expect(violations[1].position.line == 3)
    }
}

@Suite("디렉티브 인자 — 이름 조회 래퍼")
struct DirectiveArgumentsTests {
    @Test("필수 인자 누락은 line:column 과 함께 거부된다")
    func missingArgument() {
        let error = parseError("@Concept {\n본문\n}\n")
        #expect(error?.reason == .missingArgument(directive: "Concept", argument: "id"))
        // 디렉티브 이름 위치 — `@` 가 있는 칸.
        #expect(error?.position == SourcePosition(line: 1, column: 1))
        #expect(error?.description.hasPrefix("1:1:") == true)
    }

    @Test("모르는 인자는 거부된다")
    func unknownArgument() {
        let error = parseError("@Concept(id: a, tone: casual) {\n본문\n}\n")
        #expect(error?.reason == .unknownArgument(directive: "Concept", argument: "tone"))
        #expect(error?.position.line == 1)
    }

    @Test("중복 인자는 거부된다")
    func duplicateArgument() {
        let error = parseError("@Concept(id: a, id: b) {\n본문\n}\n")
        switch error?.reason {
        case .duplicateArgument(let directive, let argument):
            #expect(directive == "Concept")
            #expect(argument == "id")
        case .argumentSyntax(let directive, _):
            // 라이브러리 렉서가 먼저 중복을 알아채는 경우도 같은 뜻이다.
            #expect(directive == "Concept")
        default:
            Issue.record("중복 인자가 거부되지 않았다: \(String(describing: error?.reason))")
        }
    }

    @Test("이름 없는 인자는 거부된다 — 라이브러리는 첫 인자에 한해 허용하지만 스펙은 금지")
    func positionalArgument() {
        let error = parseError("@Concept(intro) {\n본문\n}\n")
        #expect(error?.reason == .positionalArgument(directive: "Concept"))
    }

    @Test("식별자 문법에 어긋나는 값은 거부된다")
    func invalidIdentifier() {
        let error = parseError("@Concept(id: 1st) {\n본문\n}\n")
        #expect(
            error?.reason
                == .invalidArgumentValue(
                    directive: "Concept", argument: "id", value: "1st", expected: .identifier))
    }

    @Test("값에 콜론을 쓰면 인자 문법 오류로 거부된다")
    func colonInValueRejected() {
        // 렉서가 `a` 에서 값을 끊고 `:` 를 다음 인자의 구분자로 본다. 조용히 잘리는 대신
        // 문법 오류로 튀어나와야 한다.
        let error = parseError("@Concept(id: a:b) {\n본문\n}\n")
        #expect(error != nil)
        switch error?.reason {
        case .argumentSyntax, .unknownArgument, .invalidArgumentValue, .positionalArgument:
            break
        default:
            Issue.record("콜론이 통과했다: \(String(describing: error?.reason))")
        }
    }

    @Test("따옴표를 씌워도 콜론은 살아남지 못한다")
    func quotedValueStillRejected() {
        let error = parseError("@Concept(id: \"a:b\") {\n본문\n}\n")
        #expect(error != nil)
    }

    @Test("역슬래시는 언이스케이프되지 않고 값에 남는다 — 그래서 경로 인자에서 거부된다")
    func backslashStaysInValue() {
        let error = parseError(
            ReferenceLesson.replacing(
                .example,
                with: """
                    @Example(id: run, language: swift, expected: expected\\run.txt) {
                    본문

                    ```swift
                    print(1)
                    ```
                    }
                    """))
        switch error?.reason {
        case .unsafeArgumentPath(_, _, let value, let reason):
            #expect(value.contains("\\"))
            #expect(reason == .backslash(value))
        default:
            Issue.record("역슬래시가 통과했다: \(String(describing: error?.reason))")
        }
    }

    @Test("경로 인자의 상위 탈출은 거부된다")
    func parentEscapeRejected() {
        let error = parseError(
            ReferenceLesson.replacing(
                .example,
                with: """
                    @Example(id: run, language: swift, expected: ../secrets.txt) {
                    본문

                    ```swift
                    print(1)
                    ```
                    }
                    """))
        switch error?.reason {
        case .unsafeArgumentPath(_, _, _, let reason):
            #expect(reason == .parentEscape("../secrets.txt"))
        default:
            Issue.record("경로 탈출이 통과했다: \(String(describing: error?.reason))")
        }
    }

    private func parseError(_ conceptSource: String) -> LessonParseError? {
        let source =
            conceptSource.hasPrefix("@Concept")
            ? ReferenceLesson.replacing(.concept, with: conceptSource) : conceptSource
        do {
            _ = try LessonParser.parse(source: source)
            return nil
        } catch {
            return error
        }
    }
}

@Suite("빈칸 슬롯 표식")
struct BlankSlotMarkerTests {
    @Test("표식 번호를 나타난 순서대로 뽑는다")
    func extractsIndices() {
        #expect(BlankSlotMarker.indices(in: "a ___1___ b ___2___") == [1, 2])
    }

    @Test("숫자가 아닌 밑줄 구간은 표식이 아니다")
    func ignoresNonNumeric() {
        #expect(BlankSlotMarker.indices(in: "snake___case___name").isEmpty)
    }

    @Test("정답으로 채우면 표식이 사라진다")
    func fillsTemplate() {
        let block = BlankBlock(
            id: "b", language: .python, prose: "", template: "x = ___1___ + ___2___",
            slots: [
                BlankBlock.Slot(index: 1, answer: "1"),
                BlankBlock.Slot(index: 2, answer: "2"),
            ])
        #expect(block.filledTemplate() == "x = 1 + 2")
    }

    @Test("정답 안에 표식 모양이 들어 있어도 재치환하지 않는다")
    func doesNotRewriteReplacements() {
        let block = BlankBlock(
            id: "b", language: .python, prose: "", template: "x = ___1___",
            slots: [BlankBlock.Slot(index: 1, answer: "___2___")])
        #expect(block.filledTemplate() == "x = ___2___")
    }
}
