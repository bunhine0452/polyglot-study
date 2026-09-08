import ContentKit
import DesignSystem
import Foundation
import LearnCore
import Testing

@testable import LessonFeature

/// 샘플 팩의 **실제 산문**이 렌더러를 통과했을 때 무엇이 되는지 고정한다.
///
/// 파서 단위 테스트는 합성 입력을 쓴다. 여기서는 반대로 — 콘텐츠 파이프라인이 실제로
/// 내놓는 문자열(디렉티브 본문을 `MarkupFormatter` 로 되돌린 마크다운)이 입력이다.
/// 그 둘이 맞물리는지는 이 테스트만 볼 수 있다.
@Suite("레슨 산문 · 샘플 팩 실제 렌더")
struct LessonProseTests {
    @Test("Swift 개념 블록이 문단·목록·문단으로 파싱된다")
    func swiftConceptStructure() throws {
        let concept = try #require(SampleLesson.content(SampleLesson.swift).document.concept)
        let blocks = ProseParser.parse(concept.prose)
        #expect(blocks.map(\.kindName) == ["paragraph", "paragraph", "list", "paragraph"])

        guard case .list(let list) = blocks[2] else {
            Issue.record("세 번째가 목록이 아니다")
            return
        }
        #expect(!list.isOrdered)
        #expect(list.items.count == 3)
    }

    @Test("소스에서 접혀 있던 줄이 화면에서 한 문단으로 이어진다")
    func softWrappedLinesJoin() throws {
        let concept = try #require(SampleLesson.content(SampleLesson.swift).document.concept)
        let blocks = ProseParser.parse(concept.prose)
        guard case .paragraph(let first) = blocks[0] else {
            Issue.record("첫 블록이 문단이 아니다")
            return
        }
        // 원문은 두 줄이지만 문단 하나이므로 개행이 남으면 안 된다.
        #expect(!first.contains("\n"))
        #expect(first.contains("Optional<Wrapped>"))
        #expect(first.contains("`String?`"))
    }

    @Test("모든 레슨의 모든 산문이 블록을 하나 이상 낸다 — 빈 카드가 없다")
    func everyProseRenders() throws {
        for id in SampleLesson.all {
            let content = try SampleLesson.content(id)
            for block in content.blocks {
                for (label, prose) in Self.proseFields(of: block) {
                    #expect(
                        !ProseParser.parse(prose).isEmpty,
                        "\(id.rawValue) / \(label) 이 빈 화면이 된다"
                    )
                }
            }
        }
    }

    @Test("예제·빈칸의 코드는 산문에 섞여 있지 않다 — 전용 뷰로만 간다")
    func codeStaysOutOfProse() throws {
        for id in SampleLesson.all {
            let content = try SampleLesson.content(id)
            let example = try #require(content.document.example(for: content.document.primaryLanguage))
            let blank = try #require(content.document.blank(for: content.document.primaryLanguage))
            #expect(!ProseParser.parse(example.prose).contains { $0.kindName == "code" })
            #expect(!ProseParser.parse(blank.prose).contains { $0.kindName == "code" })
            // 반대로 코드 자체는 payload 로 따로 실려 있어야 한다.
            #expect(!example.code.isEmpty)
            #expect(blank.template.contains("___1___"))
        }
    }

    @Test("개념 블록의 코드 펜스는 산문에 포함된다 — 파서가 그걸 코드로 인식한다")
    func conceptCodeFencesAreRecognized() {
        let prose = "설명이다.\n\n```python\nprint(1)\n```\n\n마무리."
        #expect(
            ProseParser.parse(prose).map(\.kindName) == ["paragraph", "code", "paragraph"]
        )
    }

    @Test("접힌 행의 요약이 실제 첫 문장이다")
    func summariesAreRealSentences() throws {
        let model = try SampleLesson.model()
        #expect(model.steps[0].summary.hasPrefix("Swift 의 Optional<Wrapped>"))
        #expect(model.steps[4].summary.contains("COUNT") == false)
        #expect(model.steps[5].summary.isEmpty == false)
    }

    /// 블록 하나가 들고 있는 산문 필드 전부. 화면이 그리는 것과 같은 목록이어야 한다.
    static func proseFields(of block: LessonBlock) -> [(String, String)] {
        switch block {
        case .concept(let concept): [("concept", concept.prose)]
        case .example(let example): [("example", example.prose)]
        case .blank(let blank): [("blank", blank.prose)]
        case .task(let task):
            [("task", task.prose)] + task.hints.map { ("hint \($0.order)", $0.prose) }
        case .quiz(let quiz):
            [("question", quiz.question)]
                + quiz.choices.map { ("choice \($0.id)", $0.prose) }
                + (quiz.explanation.map { [("explanation", $0)] } ?? [])
        case .reflection(let reflection):
            reflection.prompts.map { ("prompt \($0.id)", $0.prose) }
        }
    }
}
