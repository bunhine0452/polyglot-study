import LSPKit
import Testing

@testable import EditorFeature

/// `{#completion-popup}` · 팝업의 열림/닫힘 — 뷰도 서버도 없이 값 하나로 검증한다.
///
/// 선택 이동·확정은 여기서 보지 않는다. 그 키 처리는 `Vendor/CodeEditSourceEditor` 의
/// `NSTableView` 가 소유하고, 같은 규칙을 이쪽에 한 벌 더 두면 둘이 갈라진다.
@Suite("`{#completion-popup}` · 팝업 열림/닫힘")
struct CompletionPopupStateTests {
    static let alpha = CompletionCandidate(label: "alpha", insertText: "alpha")
    static let beta = CompletionCandidate(label: "beta", insertText: "beta")
    static let album = CompletionCandidate(label: "album", insertText: "album")

    @Test("후보가 있으면 열린다")
    func opensWithCandidates() {
        let state = CompletionPopupState.open(items: [Self.alpha, Self.beta])
        #expect(state.isOpen)
        #expect(state.items.count == 2)
    }

    /// 이 타입이 있는 이유. 예전에는 서버가 빈 배열을 주면 후보 0개짜리 "No Completions"
    /// 빈 팝업이 떴다 — 최초 요청 경로가 그 배열을 그대로 창에 실어 보냈기 때문이다.
    @Test("후보가 비면 열리지 않는다 — 빈 팝업이 뜨지 않는다")
    func emptyCandidatesStayClosed() {
        #expect(!CompletionPopupState.open(items: []).isOpen)
        #expect(CompletionPopupState.open(items: []) == .closed)
    }

    @Test("닫힌 상태는 후보가 없다")
    func closedHasNoItems() {
        #expect(!CompletionPopupState.closed.isOpen)
        #expect(CompletionPopupState.closed.items.isEmpty)
    }

    @Test("커서가 움직이면 접두사로 로컬 필터한다 — 서버에 다시 묻지 않는다")
    func filtersLocallyByPrefix() {
        let state = CompletionPopupState.open(items: [Self.alpha, Self.beta, Self.album])
        let filtered = state.filtered(byPrefix: "al")
        #expect(filtered.isOpen)
        #expect(filtered.items.map(\.label).sorted() == ["album", "alpha"])
    }

    /// 두 진입점(서버 왕복·커서 이동)이 같은 생성자를 거치므로 규칙이 갈라질 수 없다.
    @Test("필터 결과가 비면 닫힌다 — 열 때와 같은 규칙이다")
    func filteringToNothingCloses() {
        let state = CompletionPopupState.open(items: [Self.alpha, Self.beta])
        #expect(!state.filtered(byPrefix: "zzz").isOpen)
    }
}
