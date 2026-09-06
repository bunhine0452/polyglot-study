import Foundation
import Testing

@testable import LSPKit

@Suite("LSP 완성 항목 → 후보")
struct LSPCompletionMappingTests {
    /// 실측으로 받은 항목 하나를 그대로 옮겨 적은 것. sourcekit-lsp 가 `greeting.` 에
    /// 대해 첫 번째로 준 항목이다.
    static let realItem = LSPCompletionItem(
        label: "split(separator: Collection, maxSplits: Int, omittingEmptySubsequences: Bool)",
        kind: 2,
        detail: "[Substring]",
        documentation: .markup(
            kind: "markdown",
            value: "Returns the longest possible subsequences of the collection, in order,"
        ),
        sortText: "4998.78379906-split(separator: Collection, maxSplits: Int, omittingEmptySubsequences: Bool)",
        filterText: "split(separator:maxSplits:omittingEmptySubsequences:)",
        insertText: "split(separator: , maxSplits: , omittingEmptySubsequences: )",
        insertTextFormat: 1,
        textEdit: LSPTextEdit(newText: "split(separator: , maxSplits: , omittingEmptySubsequences: )"),
        deprecated: false
    )

    /// **가장 중요한 규칙.** `label` 은 사람이 읽는 시그니처고 실제로 넣어야 하는 것은
    /// `textEdit.newText` 다. 뒤바뀌면 `String` 같은 타입 이름이 코드에 박힌다.
    @Test("삽입 문자열은 textEdit → insertText → label 순으로 고른다")
    func insertTextPrefersTextEdit() {
        #expect(
            LSPCompletionMapping.map(Self.realItem).insertText
                == "split(separator: , maxSplits: , omittingEmptySubsequences: )"
        )

        let withoutEdit = LSPCompletionItem(label: "count", insertText: "count()")
        #expect(LSPCompletionMapping.map(withoutEdit).insertText == "count()")

        let bare = LSPCompletionItem(label: "isEmpty")
        #expect(LSPCompletionMapping.map(bare).insertText == "isEmpty")
    }

    @Test("실측 항목의 모든 칸이 제자리로 간다")
    func realItemMapsEveryField() {
        let candidate = LSPCompletionMapping.map(Self.realItem)
        #expect(candidate.label.hasPrefix("split(separator: Collection"))
        #expect(candidate.detail == "[Substring]")
        #expect(candidate.kind == .method)
        #expect(candidate.isDeprecated == false)
        #expect(candidate.filterText == "split(separator:maxSplits:omittingEmptySubsequences:)")
        #expect(candidate.documentation?.hasPrefix("Returns the longest") == true)
    }

    @Test("문서화는 평문이든 마크업이든 본문만 남는다")
    func documentationUnwrapsBothShapes() {
        let plain = LSPCompletionItem(label: "a", documentation: .plain("설명"))
        #expect(LSPCompletionMapping.map(plain).documentation == "설명")

        let markup = LSPCompletionItem(label: "b", documentation: .markup(kind: "markdown", value: "**굵게**"))
        #expect(LSPCompletionMapping.map(markup).documentation == "**굵게**")
    }

    @Test("kind 숫자가 이름으로 바뀐다 — 1..25 전부")
    func kindNumbersBecomeNames() {
        #expect(CompletionCandidate.Kind.from(raw: 1) == .text)
        #expect(CompletionCandidate.Kind.from(raw: 2) == .method)
        #expect(CompletionCandidate.Kind.from(raw: 3) == .function)
        #expect(CompletionCandidate.Kind.from(raw: 7) == .class)
        #expect(CompletionCandidate.Kind.from(raw: 14) == .keyword)
        #expect(CompletionCandidate.Kind.from(raw: 22) == .struct)
        #expect(CompletionCandidate.Kind.from(raw: 25) == .typeParameter)
        // 없는 것과 범위 밖은 unknown 이다. 새 스펙 번호가 생겨도 깨지지 않는다.
        #expect(CompletionCandidate.Kind.from(raw: nil) == .unknown)
        #expect(CompletionCandidate.Kind.from(raw: 99) == .unknown)
    }

    // MARK: - 정렬과 상한

    /// sourcekit-lsp 의 `sortText` 는 알파벳순이 아니라 관련도 점수가 앞에 붙은 문자열이다.
    /// 우리가 label 로 다시 정렬하면 서버가 아는 문맥이 통째로 버려진다.
    @Test("sortText 오름차순이다 — label 알파벳순이 아니다")
    func sortsBySortTextNotLabel() {
        let response = LSPCompletionResponse(isIncomplete: true, items: [
            LSPCompletionItem(label: "zebra", sortText: "1000.0-zebra"),
            LSPCompletionItem(label: "apple", sortText: "9000.0-apple"),
            LSPCompletionItem(label: "mango", sortText: "5000.0-mango"),
        ])
        let candidates = LSPCompletionMapping.candidates(from: response)
        #expect(candidates.map(\.label) == ["zebra", "mango", "apple"])
    }

    @Test("sortText 가 없으면 label 로 정렬한다")
    func fallsBackToLabelOrdering() {
        let response = LSPCompletionResponse(isIncomplete: false, items: [
            LSPCompletionItem(label: "c"),
            LSPCompletionItem(label: "a"),
            LSPCompletionItem(label: "b"),
        ])
        #expect(LSPCompletionMapping.candidates(from: response).map(\.label) == ["a", "b", "c"])
    }

    @Test("정렬 키가 같으면 서버가 준 순서를 지킨다 — 결과가 흔들리지 않는다")
    func equalKeysKeepServerOrder() {
        let items = (0..<20).map { LSPCompletionItem(label: "item\($0)", sortText: "same") }
        let response = LSPCompletionResponse(isIncomplete: false, items: items)
        let first = LSPCompletionMapping.candidates(from: response).map(\.label)
        let second = LSPCompletionMapping.candidates(from: response).map(\.label)
        #expect(first == second)
        #expect(first == items.map(\.label))
    }

    /// 실측: 점 하나에 200개가 온다. 전부 그리면 완성 창이 스크롤 덩어리가 된다.
    @Test("상한을 넘는 후보는 잘린다 — 서버는 200개를 보낸다")
    func limitTrimsTheList() {
        let items = (0..<200).map {
            LSPCompletionItem(label: "item\($0)", sortText: String(format: "%04d", $0))
        }
        let response = LSPCompletionResponse(isIncomplete: true, items: items)
        let candidates = LSPCompletionMapping.candidates(from: response, limit: 25)
        #expect(candidates.count == 25)
        // 상위 25개는 **정렬 후** 앞쪽이어야 한다. 자르고 정렬하면 순서가 뒤집힌다.
        #expect(candidates.first?.label == "item0")
        #expect(candidates.last?.label == "item24")
    }

    // MARK: - 응답 모양 둘

    @Test("결과가 CompletionList 여도 배열이어도 읽는다")
    func decodesBothResponseShapes() throws {
        let list = Data(#"{"isIncomplete":true,"items":[{"label":"a"},{"label":"b"}]}"#.utf8)
        let decodedList = try JSONDecoder().decode(LSPCompletionResponse.self, from: list)
        #expect(decodedList.isIncomplete)
        #expect(decodedList.items.count == 2)

        let array = Data(#"[{"label":"a"}]"#.utf8)
        let decodedArray = try JSONDecoder().decode(LSPCompletionResponse.self, from: array)
        #expect(!decodedArray.isIncomplete)
        #expect(decodedArray.items.count == 1)
    }

    @Test("결과가 null 이면 빈 목록이다 — 완성이 없는 자리")
    func nullResultIsAnEmptyList() throws {
        let decoded = try JSONDecoder().decode(LSPCompletionResponse.self, from: Data("null".utf8))
        #expect(decoded.items.isEmpty)
    }

    @Test("textEdit 이 InsertReplaceEdit 모양이어도 newText 를 꺼낸다")
    func insertReplaceEditIsUnderstood() throws {
        let json = Data(#"""
            {"label":"a","textEdit":{"newText":"apply()",
             "insert":{"start":{"line":1,"character":2},"end":{"line":1,"character":2}},
             "replace":{"start":{"line":1,"character":0},"end":{"line":1,"character":2}}}}
            """#.utf8)
        let item = try JSONDecoder().decode(LSPCompletionItem.self, from: json)
        #expect(LSPCompletionMapping.map(item).insertText == "apply()")
        #expect(item.textEdit?.range?.start.character == 2)
    }

    @Test("서버가 보내는 실제 응답 JSON 을 통째로 읽는다")
    func decodesRealServerPayload() throws {
        // 실측 응답에서 첫 항목만 떼어 온 것.
        let json = Data(#"""
            {"isIncomplete":true,"items":[{
              "textEdit":{"range":{"start":{"character":15,"line":3},"end":{"character":15,"line":3}},
                          "newText":"split(separator: , maxSplits: , omittingEmptySubsequences: )"},
              "deprecated":false,"insertTextFormat":1,
              "sortText":"4998.78379906-split(separator: Collection)",
              "insertText":"split(separator: , maxSplits: , omittingEmptySubsequences: )",
              "documentation":{"kind":"markdown","value":"Returns the longest possible subsequences."},
              "kind":2,"filterText":"split(separator:maxSplits:omittingEmptySubsequences:)",
              "label":"split(separator: Collection, maxSplits: Int, omittingEmptySubsequences: Bool)",
              "detail":"[Substring]","data":{"sessionId":0,"itemId":106}}]}
            """#.utf8)
        let response = try JSONDecoder().decode(LSPCompletionResponse.self, from: json)
        let candidate = try #require(LSPCompletionMapping.candidates(from: response).first)
        #expect(candidate.kind == .method)
        #expect(candidate.detail == "[Substring]")
        #expect(candidate.insertText == "split(separator: , maxSplits: , omittingEmptySubsequences: )")
        #expect(candidate.documentation == "Returns the longest possible subsequences.")
    }
}
