internal import LSPKit

/// 완성 팝업의 열림/닫힘 — `{#completion-popup}`. **뷰도 서버도 없이** 값만으로 움직인다.
///
/// 선택 이동과 확정은 여기 없다. 그 키 처리는 `Vendor/CodeEditSourceEditor` 의
/// `NSTableView` 가 이미 하고 있고, 같은 규칙을 여기 한 벌 더 적으면 둘이 갈라진다 —
/// 지금 화면이 쓰지 않는 규격은 검증되지 않은 채 낡는다.
///
/// ## "열림 == 후보가 있다" 를 타입으로 봉인하는 이유
///
/// 팝업이 열리는 진입점이 둘이다 — 서버 왕복 직후(`completionSuggestionsRequested`)와
/// 커서가 움직일 때마다 도는 로컬 필터(`completionOnCursorMove`). 두 진입점이 "후보가
/// 비면 닫는다" 규칙을 각자 구현하면 하나를 빠뜨리기 쉽다 — 실제로 이 저장소가 그랬다.
/// 서버가 빈 배열을 돌려줘도 최초 요청 경로는 그것을 그대로 CESE 창에 실어 보냈고,
/// 그러면 후보 0개짜리 "No Completions" 빈 팝업이 떴다(커서 이동 경로는 CESE 가 빈
/// 배열을 스스로 "닫아라" 로 해석해 주는 덕에 우연히 맞았을 뿐이다). 여기서는
/// `open(items:)` **하나**가 그 규칙을 강제한다 — 두 진입점이 이 생성자만 거치면
/// 규칙이 다시 갈라질 수 없다.
struct CompletionPopupState: Equatable, Sendable {
    private(set) var items: [CompletionCandidate]

    static let closed = CompletionPopupState(items: [])

    private init(items: [CompletionCandidate]) {
        self.items = items
    }

    /// 후보로 연다. **비어 있으면 열리지 않는다** — 이 타입이 있는 이유다.
    static func open(items: [CompletionCandidate]) -> CompletionPopupState {
        CompletionPopupState(items: items)
    }

    var isOpen: Bool { !items.isEmpty }

    /// 커서가 움직였을 때 로컬로 거른다(서버에 다시 묻지 않는다 — `SwiftCompletionSupport`
    /// 의 계약과 같다). 거른 결과가 비면 `.closed` 다 — 여기서도 `open(items:)` 를
    /// 거치므로 "비면 닫힌다" 규칙이 갈라지지 않는다.
    func filtered(byPrefix prefix: String) -> CompletionPopupState {
        .open(items: SwiftCompletionSupport.filter(items, byPrefix: prefix))
    }
}
