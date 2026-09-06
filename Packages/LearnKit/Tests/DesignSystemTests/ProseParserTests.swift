import Testing

@testable import DesignSystem

@Suite("산문 렌더러 · 블록 파싱")
struct ProseParserTests {
    @Test("문단 하나는 문단 하나로 나온다")
    func singleParagraph() {
        let blocks = ProseParser.parse("한 문단입니다.")
        #expect(blocks.count == 1)
        #expect(blocks.first == .paragraph("한 문단입니다."))
    }

    @Test("소프트 개행은 공백으로 접힌다 — 소스가 90열에서 접혀 있기 때문")
    func softBreaksFold() {
        let blocks = ProseParser.parse(
            """
            앞 문장이 여기서 끝난다.
            뒤 문장이 다음 줄에서 시작한다.
            """
        )
        #expect(blocks == [.paragraph("앞 문장이 여기서 끝난다. 뒤 문장이 다음 줄에서 시작한다.")])
    }

    @Test("줄 끝 두 칸과 역슬래시는 강제 개행으로 살아남는다")
    func hardBreaksSurvive() {
        #expect(ProseParser.parse("앞줄  \n뒷줄") == [.paragraph("앞줄\n뒷줄")])
        #expect(ProseParser.parse("앞줄\\\n뒷줄") == [.paragraph("앞줄\n뒷줄")])
    }

    @Test("빈 줄이 문단을 가른다")
    func blankLineSplitsParagraphs() {
        let blocks = ProseParser.parse("첫 문단.\n\n둘째 문단.")
        #expect(blocks == [.paragraph("첫 문단."), .paragraph("둘째 문단.")])
    }

    @Test("제목 여섯 단계")
    func headings() {
        for level in 1...6 {
            let hashes = String(repeating: "#", count: level)
            #expect(ProseParser.parse("\(hashes) 제목") == [.heading(level: level, text: "제목")])
        }
        // 일곱 개는 제목이 아니다.
        #expect(ProseParser.parse("####### 제목").first?.kindName == "paragraph")
        // 공백 없는 `#태그` 도 제목이 아니다.
        #expect(ProseParser.parse("#태그").first?.kindName == "paragraph")
    }

    @Test("닫는 해시는 벗기되 C# 은 자르지 않는다")
    func closingHashes() {
        #expect(ProseParser.parse("## 제목 ##") == [.heading(level: 2, text: "제목")])
        #expect(ProseParser.parse("## C#") == [.heading(level: 2, text: "C#")])
    }

    @Test("순서 없는 목록 세 항목")
    func unorderedList() throws {
        let blocks = ProseParser.parse(
            """
            - 첫째
            - 둘째
            - 셋째
            """
        )
        #expect(blocks.count == 1)
        guard case .list(let list) = try #require(blocks.first) else {
            Issue.record("목록이 아니다")
            return
        }
        #expect(!list.isOrdered)
        #expect(list.items.count == 3)
        #expect(list.items[0] == [.paragraph("첫째")])
        #expect(list.items[2] == [.paragraph("셋째")])
    }

    @Test("순서 있는 목록은 시작 번호를 기억한다")
    func orderedList() throws {
        let blocks = ProseParser.parse("3. 셋\n4. 넷")
        guard case .list(let list) = try #require(blocks.first) else {
            Issue.record("목록이 아니다")
            return
        }
        #expect(list.isOrdered)
        #expect(list.start == 3)
        #expect(list.items.count == 2)
    }

    @Test("항목 안의 이어지는 줄은 같은 항목이다")
    func lazyContinuation() throws {
        let blocks = ProseParser.parse(
            """
            - 첫 줄
              이어지는 줄
            - 둘째
            """
        )
        guard case .list(let list) = try #require(blocks.first) else {
            Issue.record("목록이 아니다")
            return
        }
        #expect(list.items.count == 2)
        #expect(list.items[0] == [.paragraph("첫 줄 이어지는 줄")])
    }

    @Test("중첩 목록은 항목 안의 목록으로 들어간다")
    func nestedList() throws {
        let blocks = ProseParser.parse(
            """
            - 바깥
              - 안쪽
            """
        )
        guard case .list(let outer) = try #require(blocks.first) else {
            Issue.record("목록이 아니다")
            return
        }
        #expect(outer.items.count == 1)
        #expect(outer.items[0].count == 2)
        #expect(outer.items[0][0] == .paragraph("바깥"))
        #expect(outer.items[0][1].kindName == "list")
    }

    @Test("중첩 상한을 넘으면 문단 하나로 접는다 — 스택을 태우지 않는다")
    func nestingIsBounded() {
        var source = "깊은 곳"
        for _ in 0..<40 { source = "- " + source }
        let blocks = ProseParser.parse(source)
        #expect(blocks.count == 1)
        #expect(depth(of: blocks) <= ProseParser.maximumNestingDepth + 2)
    }

    private func depth(of blocks: [ProseBlock]) -> Int {
        var deepest = 0
        for block in blocks {
            switch block {
            case .list(let list):
                for item in list.items { deepest = max(deepest, 1 + depth(of: item)) }
            case .blockquote(let children):
                deepest = max(deepest, 1 + depth(of: children))
            default:
                deepest = max(deepest, 1)
            }
        }
        return deepest
    }

    @Test("인용은 안쪽을 다시 블록으로 파싱한다")
    func blockquote() throws {
        let blocks = ProseParser.parse("> 인용 문단.\n> 계속.")
        guard case .blockquote(let children) = try #require(blocks.first) else {
            Issue.record("인용이 아니다")
            return
        }
        #expect(children == [.paragraph("인용 문단. 계속.")])
    }

    @Test("수평선 세 표기")
    func thematicBreak() {
        #expect(ProseParser.parse("---") == [.thematicBreak])
        #expect(ProseParser.parse("***") == [.thematicBreak])
        #expect(ProseParser.parse("_ _ _") == [.thematicBreak])
        // 두 개는 아니다.
        #expect(ProseParser.parse("--").first?.kindName == "paragraph")
    }

    @Test("펜스 코드 블록은 언어와 본문을 그대로 들고 나온다")
    func fencedCode() {
        let blocks = ProseParser.parse(
            """
            ```swift
            let x = 1
            print(x)
            ```
            """
        )
        #expect(blocks == [.code(ProseCode(language: "swift", text: "let x = 1\nprint(x)"))])
    }

    @Test("펜스 안쪽은 산문 문법으로 해석되지 않는다 — 코드가 목록이 되면 안 된다")
    func fenceProtectsContent() {
        let blocks = ProseParser.parse(
            """
            ```python
            # 주석
            - 목록처럼 생긴 줄
            > 인용처럼 생긴 줄
            ```
            """
        )
        #expect(blocks.count == 1)
        #expect(blocks.first?.kindName == "code")
    }

    @Test("닫히지 않은 펜스는 남은 줄을 전부 코드로 삼는다")
    func unterminatedFence() {
        let blocks = ProseParser.parse("```\nabc\ndef")
        #expect(blocks == [.code(ProseCode(language: nil, text: "abc\ndef"))])
    }

    @Test("CRLF 를 뭉치지 않는다 — Swift 에서 \\r\\n 은 Character 하나다")
    func crlfIsSplit() {
        let blocks = ProseParser.parse("첫 문단.\r\n\r\n둘째 문단.")
        #expect(blocks == [.paragraph("첫 문단."), .paragraph("둘째 문단.")])
    }

    @Test("빈 소스는 블록 0개")
    func emptySource() {
        #expect(ProseParser.parse("").isEmpty)
        #expect(ProseParser.parse("   \n\n  ").isEmpty)
    }

    // MARK: - 방출기 들여쓰기

    @Test("방출기가 4칸씩 민 평평한 목록이 다시 평평해진다")
    func flatListSurvivesEmitterIndent() throws {
        // `ContentKit.Body.prose` 가 실제로 내놓는 모양이다(실측):
        // 레슨 소스의 `- 첫째 / - 둘째` 가 이렇게 나온다.
        let blocks = ProseParser.parse("- 첫째\n    - 둘째\n    - 셋째")
        guard case .list(let list) = try #require(blocks.first) else {
            Issue.record("목록이 아니다")
            return
        }
        #expect(list.items.count == 3)
        #expect(list.items[0] == [.paragraph("첫째")])
        #expect(list.items[1] == [.paragraph("둘째")])
        #expect(list.items[2] == [.paragraph("셋째")])
    }

    @Test("중첩 목록은 상대 구조를 잃지 않는다 — 세 단계가 그대로")
    func nestedListSurvivesEmitterIndent() throws {
        // 같은 방출기가 3단 중첩을 0/6/8 로 민다(실측). 4칸을 벗기면 0/2/4 가 된다.
        let blocks = ProseParser.parse("- 바깥\n      - 안쪽\n        - 더 안쪽")
        guard case .list(let outer) = try #require(blocks.first) else {
            Issue.record("목록이 아니다")
            return
        }
        #expect(outer.items.count == 1)
        guard case .list(let middle) = outer.items[0].last else {
            Issue.record("중간 목록이 없다")
            return
        }
        #expect(middle.items.count == 1)
        #expect(middle.items[0].last?.kindName == "list")
    }

    @Test("펜스 안의 코드도 같은 폭만큼만 벗겨진다 — 상대 들여쓰기는 남는다")
    func fenceBodyKeepsRelativeIndent() {
        let blocks = ProseParser.parse("```python\n    def f():\n        return 1\n    ```")
        #expect(blocks == [.code(ProseCode(language: "python", text: "def f():\n    return 1"))])
    }

    @Test("첫 줄이 열 0 이 아니거나 한 줄이라도 4칸 미만이면 벗기지 않는다")
    func strippingIsNarrow() {
        // 손으로 쓴 2칸 중첩은 건드리지 않는다 — 여전히 중첩이다.
        guard case .list(let list)? = ProseParser.parse("- 바깥\n  - 안쪽").first else {
            Issue.record("목록이 아니다")
            return
        }
        #expect(list.items.count == 1)
        #expect(list.items[0].map(\.kindName) == ["paragraph", "list"])

        // 펜스 본문 중 한 줄이라도 열 0 이면 통째로 그대로 둔다.
        let code = ProseParser.parse("```python\ndef f():\n    return 1\n```")
        #expect(code == [.code(ProseCode(language: "python", text: "def f():\n    return 1"))])
    }

    @Test("깊이 2 디렉티브의 8칸도 벗겨진다")
    func twoLevelIndentIsStripped() {
        #expect(ProseParser.parse("힌트 첫 줄\n        힌트 둘째 줄") == [.paragraph("힌트 첫 줄 힌트 둘째 줄")])
    }

    @Test("탭으로 시작하는 줄을 글자 단위로 잘라먹지 않는다")
    func tabsAreNotEaten() {
        // 탭 한 개는 폭으로는 4칸이지만 공백 문자는 0개다 — 벗기지 않는다.
        #expect(ProseParser.parse("첫 줄\n\t둘째 줄") == [.paragraph("첫 줄 둘째 줄")])
    }

    @Test("섞인 문서가 순서를 지킨다")
    func mixedDocument() {
        let blocks = ProseParser.parse(
            """
            # 제목

            문단.

            - 항목

            ```
            code
            ```

            > 인용

            ---
            """
        )
        #expect(
            blocks.map(\.kindName) == [
                "heading", "paragraph", "list", "code", "blockquote", "thematicBreak",
            ]
        )
    }
}
