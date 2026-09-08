import Foundation
import LSPKit
import Testing

@testable import EditorFeature

@Suite("`{#lsp-completion}` · 완성 창을 움직이는 순수 계산")
struct SwiftCompletionSupportTests {
    static let source = "import Foundation\n\nlet greeting = \"hello\"\nprint(greeting.)\n"

    /// UTF-16 오프셋. `CursorPosition.range.location` 이 주는 것과 같은 좌표계다.
    static func offset(after fragment: String, in text: String) throws -> Int {
        let range = (text as NSString).range(of: fragment)
        try #require(range.location != NSNotFound, "조각을 못 찾았다: \(fragment)")
        return range.location + range.length
    }

    // MARK: - 트리거 문자

    @Test("커서 앞 글자가 트리거 문자면 그것을 돌려준다")
    func detectsTriggerCharacterBeforeCursor() throws {
        let offset = try Self.offset(after: "print(greeting.", in: Self.source)
        #expect(
            SwiftCompletionSupport.triggerCharacter(
                before: offset, in: Self.source, triggers: [".", "("]
            ) == "."
        )
    }

    @Test("트리거 집합에 없는 글자는 트리거가 아니다")
    func nonTriggerCharacterIsIgnored() throws {
        let offset = try Self.offset(after: "print(greeting", in: Self.source)
        #expect(
            SwiftCompletionSupport.triggerCharacter(
                before: offset, in: Self.source, triggers: [".", "("]
            ) == nil
        )
    }

    /// 트리거 집합은 서버가 `initialize` 응답에서 광고한 것이다. 비면 아무것도 트리거가
    /// 아니다 — 서버가 없는 머신에서 완성 창이 열리지 않는 경로가 이것이다.
    @Test("트리거 집합이 비면 아무것도 트리거가 아니다")
    func emptyTriggerSetMatchesNothing() throws {
        let offset = try Self.offset(after: "print(greeting.", in: Self.source)
        #expect(
            SwiftCompletionSupport.triggerCharacter(before: offset, in: Self.source, triggers: []) == nil
        )
    }

    @Test("문서 처음과 끝에서 범위를 벗어나지 않는다")
    func triggerLookupStaysInBounds() {
        #expect(SwiftCompletionSupport.triggerCharacter(before: 0, in: "abc", triggers: ["a"]) == nil)
        #expect(SwiftCompletionSupport.triggerCharacter(before: 999, in: "abc", triggers: ["c"]) == nil)
        #expect(SwiftCompletionSupport.triggerCharacter(before: 3, in: "abc", triggers: ["c"]) == "c")
    }

    // MARK: - 바꿔 쓸 범위

    /// 이게 없으면 `gre` 에서 `greeting` 을 고를 때 `gregreeting` 이 된다.
    @Test("커서 앞 식별자 조각이 바꿔 쓸 범위다")
    func replacementRangeCoversTheIdentifierPrefix() {
        let text = "let x = gre"
        let range = SwiftCompletionSupport.replacementRange(cursorOffset: 11, in: text)
        #expect(range.location == 8)
        #expect(range.length == 3)
        #expect(SwiftCompletionSupport.identifierPrefix(cursorOffset: 11, in: text) == "gre")
    }

    @Test("점 바로 뒤에서는 빈 범위다 — 끼워 넣기와 같아진다")
    func rangeAfterDotIsEmpty() throws {
        let offset = try Self.offset(after: "print(greeting.", in: Self.source)
        let range = SwiftCompletionSupport.replacementRange(cursorOffset: offset, in: Self.source)
        #expect(range.length == 0)
        #expect(range.location == offset)
        #expect(SwiftCompletionSupport.identifierPrefix(cursorOffset: offset, in: Self.source) == "")
    }

    @Test("밑줄과 숫자는 식별자에 들고 점·괄호·공백은 경계다")
    func identifierScalarsAreLettersDigitsAndUnderscore() {
        // 밑줄과 숫자가 낱말에 포함된다.
        #expect(SwiftCompletionSupport.identifierPrefix(cursorOffset: 13, in: "value my_var1") == "my_var1")
        // 점이 경계다.
        #expect(SwiftCompletionSupport.identifierPrefix(cursorOffset: 5, in: "abc.d") == "d")
        // 여는 괄호가 경계다.
        #expect(SwiftCompletionSupport.identifierPrefix(cursorOffset: 9, in: "print(abc") == "abc")
        // 공백이 경계다.
        #expect(SwiftCompletionSupport.identifierPrefix(cursorOffset: 5, in: "abc  ") == "")
    }

    @Test("범위를 벗어난 오프셋에도 깨지지 않는다")
    func replacementRangeClampsOutOfBounds() {
        let text = "abc"
        #expect(SwiftCompletionSupport.replacementRange(cursorOffset: -5, in: text).location == 0)
        let clamped = SwiftCompletionSupport.replacementRange(cursorOffset: 999, in: text)
        #expect(clamped.location == 0)
        #expect(clamped.length == 3)
    }

    // MARK: - 로컬 필터

    static let candidates = [
        CompletionCandidate(label: "count", insertText: "count", filterText: "count"),
        CompletionCandidate(label: "capitalized", insertText: "capitalized", filterText: "capitalized"),
        CompletionCandidate(
            label: "split(separator: Character)", insertText: "split(separator: )",
            filterText: "split(separator:)"
        ),
        CompletionCandidate(label: "isEmpty", insertText: "isEmpty"),
    ]

    /// `completionOnCursorMove` 는 동기여야 한다 — 글자마다 서버에 묻지 않는다.
    @Test("이미 받은 후보를 접두사로 거른다")
    func filtersLocallyByPrefix() {
        let filtered = SwiftCompletionSupport.filter(Self.candidates, byPrefix: "c")
        #expect(filtered.map(\.label) == ["count", "capitalized"])
    }

    @Test("접두사가 비면 전부 남는다")
    func emptyPrefixKeepsEverything() {
        #expect(SwiftCompletionSupport.filter(Self.candidates, byPrefix: "").count == 4)
    }

    @Test("대소문자를 가리지 않는다")
    func filterIsCaseInsensitive() {
        #expect(SwiftCompletionSupport.filter(Self.candidates, byPrefix: "COU").map(\.label) == ["count"])
    }

    /// sourcekit-lsp 의 `label` 에는 타입까지 들어간다
    /// (`split(separator: Character)`). 사용자가 친 글자와 맞춰야 하는 것은
    /// `filterText`(`split(separator:)`) 다.
    @Test("거르는 기준은 label 이 아니라 filterText 다")
    func filterUsesFilterTextNotLabel() {
        let filtered = SwiftCompletionSupport.filter(Self.candidates, byPrefix: "split(s")
        #expect(filtered.map(\.label) == ["split(separator: Character)"])
    }

    @Test("filterText 가 없으면 label 로 거른다")
    func fallsBackToLabelWhenFilterTextIsMissing() {
        #expect(SwiftCompletionSupport.filter(Self.candidates, byPrefix: "isE").map(\.label) == ["isEmpty"])
    }

    @Test("맞는 게 없으면 빈 목록이다 — 그러면 편집기가 창을 닫는다")
    func noMatchesClosesTheWindow() {
        #expect(SwiftCompletionSupport.filter(Self.candidates, byPrefix: "zzz").isEmpty)
    }

    // MARK: - 아이콘

    @Test("종류마다 다른 기호가 붙고 모르는 종류도 기호가 있다")
    func everyKindHasASymbol() {
        for kind in CompletionCandidate.Kind.allCases {
            #expect(!SwiftCompletionSupport.symbolName(for: kind).isEmpty)
        }
        #expect(SwiftCompletionSupport.symbolName(for: .method) == "f.square")
        #expect(SwiftCompletionSupport.symbolName(for: .unknown) == "questionmark.square")
    }

    // MARK: - 편집기 항목으로 감싸기

    @Test("후보가 편집기 항목으로 감싸이면서 값이 그대로 넘어간다")
    func candidateWrapsIntoASuggestionEntry() {
        let candidate = CompletionCandidate(
            label: "count", detail: "Int", documentation: "글자 수",
            insertText: "count", kind: .property, isDeprecated: true
        )
        let entry = SwiftSuggestionEntry(candidate: candidate)
        #expect(entry.label == "count")
        #expect(entry.detail == "Int")
        #expect(entry.documentation == "글자 수")
        #expect(entry.deprecated)
        // 정의로 뛰는 기능이 없으므로 셋 다 nil 이어야 창이 링크를 그리지 않는다.
        #expect(entry.pathComponents == nil)
        #expect(entry.targetPosition == nil)
        #expect(entry.sourcePreview == nil)
    }
}
