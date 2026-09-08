internal import CodeEditSourceEditor
// `TextView.replaceCharacters(in:with:)` 는 이 모듈이 붙인 확장이다.
// `MemberImportVisibility` 아래에서는 직접 import 해야 멤버가 보인다.
internal import CodeEditTextView
internal import Foundation
internal import LearnCore
internal import LSPKit
internal import Observation

/// 에디터 화면의 Swift 언어 지원 — 완성과 실시간 진단.
///
/// **Swift 트랙 전용이다.** 다른 언어에는 붙지 않는다.
///
/// 세 역할을 겸한다:
///   1. `SwiftLanguageService`(언어 서버)의 수명 관리
///   2. `CodeSuggestionDelegate` — 편집기가 완성을 물어 오는 자리
///   3. `publishDiagnostics` 를 화면이 읽을 수 있는 값으로 옮겨 놓기
///
/// ## 서버가 없는 머신
///
/// `start()` 는 던지지 않는다. `status` 가 `.unavailable` 이 되고, 그러면 완성은
/// 빈 목록, 실시간 진단은 없음이다. **편집·실행·swiftc 진단은 그대로 동작한다** —
/// 언어 서버는 있으면 좋은 것이지 이 화면의 전제가 아니다.
@Observable
final class SwiftLanguageSupport: CodeSuggestionDelegate {
    enum Status: Equatable {
        case idle
        case starting
        case ready
        /// 서버를 못 띄웠다. 이유를 들고 있는다 — 조용히 꺼져 있으면 왜 완성이 안 뜨는지
        /// 아무도 모른다.
        case unavailable(String)
    }

    private(set) var status: Status = .idle
    /// 서버가 광고한 트리거 문자. 편집기 설정에 그대로 넘어간다.
    private(set) var triggerCharacters: Set<String> = []
    /// 마지막으로 받은 진단과 그것이 계산된 스냅샷.
    private(set) var diagnostics: [Diagnostic] = []
    private(set) var diagnosticsSnapshot: String = ""

    /// 테스트가 실제 서버 없이 이 타입을 끼울 수 있게 하는 통로.
    /// `nil` 이면 진짜 `sourcekit-lsp` 를 띄운다.
    typealias ServiceFactory = @Sendable () async throws -> SwiftLanguageService

    private let fileName: String
    private let serviceFactory: ServiceFactory?
    private var service: SwiftLanguageService?
    private var diagnosticsTask: Task<Void, Never>?

    /// 팝업 상태. **열림/닫힘·선택 이동·확정이 이 값 하나로 정의된다**(`{#completion-popup}`,
    /// `CompletionPopupState`) — 뷰·서버 없이 그 타입만 테스트한다.
    /// `completionOnCursorMove` 가 이것을 로컬로 거른다.
    private var popupState: CompletionPopupState = .closed

    /// 편집 전순서. **이 객체는 `MainActor` 격리라 이 증가는 동기 구간이다** —
    /// 여기서 매긴 순서가 문서 갱신의 유일한 진실이다.
    ///
    /// 키 입력마다 `Task { await ... }` 가 새로 뜨고(뷰의 `onChange`), 그 태스크들이
    /// 언어 서비스 액터에 도착하는 순서는 보장되지 않는다. 순번을 함께 보내면
    /// 서비스가 늦게 온 낡은 편집을 버릴 수 있다.
    private var editSequence = 0

    /// `start()` 세대. `stop()` 이 올린다.
    ///
    /// `start()` 는 서버를 찾고 띄우느라 몇 초를 `await` 한다(cold 시 `xcrun` 세 번 +
    /// 프로세스 기동). 그 사이에 화면이 닫혀 `stop()` 이 돌면, 그때 `service` 는 아직
    /// nil 이라 거둘 것이 없고 — 세대 검사가 없으면 `start()` 가 이어서 **프로세스를
    /// 띄우고 아무도 가리키지 않는 채로 남긴다.** 그게 잔존 프로세스다.
    private var startGeneration = 0

    /// 다음 편집 순번. 동기 함수라 호출 순서가 곧 순번 순서다.
    private func nextEditSequence() -> Int {
        editSequence += 1
        return editSequence
    }

    init(fileName: String, serviceFactory: ServiceFactory? = nil) {
        self.fileName = fileName
        self.serviceFactory = serviceFactory
    }

    // MARK: - 수명

    func start(text: String) async {
        guard case .idle = status else { return }
        status = .starting
        let generation = startGeneration
        do {
            // `??` 로 붙이면 우변이 autoclosure 라 `await` 를 넣을 수 없다.
            let service: SwiftLanguageService
            if let serviceFactory {
                service = try await serviceFactory()
            } else {
                service = try await SwiftLanguageService.makeDefault()
            }
            // 만드는 동안 `stop()` 이 돌았다면 이 서버는 주인이 없다. 즉시 거둔다.
            guard generation == startGeneration else {
                await service.shutdown()
                return
            }
            // **핸들을 먼저 붙잡는다.** 아래 `start()` 가 던지면 프로세스는 이미 떠
            // 있는데 이 객체가 그것을 가리키지 못한다 — 그게 곧 잔존 프로세스다.
            self.service = service
            let result = try await service.start()
            guard generation == startGeneration else {
                self.service = nil
                await service.shutdown()
                return
            }
            triggerCharacters = Set(result.capabilities.completionProvider?.triggerCharacters ?? [])
            await service.openDocument(
                fileName: fileName, text: text, editSequence: nextEditSequence()
            )
            observeDiagnostics(from: service)
            status = .ready
        } catch {
            // `service`(로컬)가 아니라 저장된 핸들을 본다. 위에서 붙잡기 전에 던졌다면
            // 프로세스도 아직 없다.
            let orphan = self.service
            self.service = nil
            await orphan?.shutdown()
            // 거두는 동안 새 `start()` 가 시작됐다면 그쪽 상태를 덮어쓰지 않는다.
            guard generation == startGeneration else { return }
            status = .unavailable("\(error)")
        }
    }

    func stop() async {
        // 세대를 먼저 올린다. 아직 `start()` 가 도는 중이면 그쪽이 이 값을 보고
        // 자기가 띄운 서버를 스스로 거둔다.
        startGeneration += 1
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        let service = self.service
        self.service = nil
        status = .idle
        popupState = .closed
        await service?.shutdown()
    }

    /// 편집기 본문이 바뀌었다. 서버에 알린다.
    ///
    /// 왕복이 아니라 알림이라 값이 싸다. 서버가 스스로 묶어서 처리하므로 여기서
    /// 디바운스하지 않는다 — 디바운스하면 완성 요청이 낡은 문서를 보는 창이 생긴다.
    func documentDidChange(text: String) async {
        // 순번은 **여기서** 매긴다. 이 함수는 MainActor 격리라 이 한 줄이 전순서를
        // 만들고, 그 뒤 액터 홉의 도착 순서가 뒤집혀도 서비스가 낡은 것을 버린다.
        let sequence = nextEditSequence()
        await service?.updateDocument(text: text, editSequence: sequence)
    }

    private func observeDiagnostics(from service: SwiftLanguageService) {
        diagnosticsTask = Task { [weak self] in
            for await update in service.diagnostics {
                guard !Task.isCancelled else { return }
                self?.apply(update)
            }
        }
    }

    private func apply(_ update: SwiftDiagnosticsUpdate) {
        diagnostics = update.diagnostics
        diagnosticsSnapshot = update.documentText
    }

    // MARK: - CodeSuggestionDelegate

    func completionTriggerCharacters() -> Set<String> { triggerCharacters }

    /// 편집기가 완성을 물어 온다.
    ///
    /// ## 취소가 실제로 서버까지 가는 이유
    ///
    /// 여기서 `service.completions(...)` 를 **직접 `await` 한다.** `Task { }` 로 감싸면
    /// 안 된다 — 감싸는 순간 새 태스크는 부모의 취소를 물려받지 않고, 편집기가 이
    /// 호출을 취소해도 안쪽의 LSP 요청은 살아남아 `$/cancelRequest` 가 영영 나가지
    /// 않는다.
    ///
    /// 편집기(`SuggestionViewModel`)는 새 완성이 시작될 때 앞의 요청 태스크를 취소한다.
    /// 그 취소가 이 함수 → `SwiftLanguageService.completions` → `LSPSession.request` 의
    /// `withTaskCancellationHandler` 로 그대로 흘러 서버에 `$/cancelRequest` 가 나간다.
    func completionSuggestionsRequested(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) async -> (windowPosition: CursorPosition, items: [CodeSuggestionEntry])? {
        guard status == .ready, let service else { return nil }
        let offset = cursorPosition.range.location
        guard offset != NSNotFound, offset >= 0 else { return nil }

        let text = textView.text
        // 서버가 최신 본문을 보고 계산하도록 먼저 알린다. 알림이라 왕복이 없고,
        // 본문이 그대로면 `updateDocument` 가 아무것도 보내지 않는다.
        let sequence = nextEditSequence()
        await service.updateDocument(text: text, editSequence: sequence)

        let trigger = SwiftCompletionSupport.triggerCharacter(
            before: offset, in: text, triggers: triggerCharacters
        )
        do {
            let candidates = try await service.completions(utf16Offset: offset, triggerCharacter: trigger)
            // 취소는 여기까지 오지 않는다(위에서 던진다). 그래도 한 번 더 본다 —
            // 취소된 요청의 결과로 창을 여는 것보다 안 여는 편이 낫다.
            guard !Task.isCancelled else { return nil }
            // `.open(items:)` 이 "비었으면 닫힌다" 를 강제한다 — 서버가 빈 배열을 주면
            // `popupState.isOpen` 이 거짓이 되고, 여기서 nil 을 돌려줘 CESE 가 창을 아예
            // 열지 않는다. `{#completion-popup}` 의 "후보가 없으면 팝업이 뜨지 않습니다"
            // 요건 — candidates 를 그대로 실어 보내던 예전 코드는 서버가 빈 목록을 줄 때
            // "No Completions" 빈 팝업을 띄웠다.
            popupState = .open(items: candidates)
            guard popupState.isOpen else { return nil }
            return (cursorPosition, popupState.items.map(SwiftSuggestionEntry.init))
        } catch {
            return nil
        }
    }

    /// 커서가 움직였다. **동기여야 한다** — 여기서 왕복하면 타이핑이 끊긴다.
    /// 이미 받아 둔 후보를 커서 앞 글자로 거르기만 한다.
    func completionOnCursorMove(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) -> [CodeSuggestionEntry]? {
        guard popupState.isOpen else { return nil }
        let offset = cursorPosition.range.location
        guard offset != NSNotFound, offset >= 0 else { return nil }
        let prefix = SwiftCompletionSupport.identifierPrefix(cursorOffset: offset, in: textView.text)
        popupState = popupState.filtered(byPrefix: prefix)
        guard popupState.isOpen else { return nil }
        return popupState.items.map(SwiftSuggestionEntry.init)
    }

    func completionWindowDidClose() {
        popupState = .closed
    }

    /// 후보를 확정한다. **커서 앞의 식별자 조각을 갈아 끼운다** — 그냥 끼워 넣으면
    /// `gre` 에서 `greeting` 을 고를 때 `gregreeting` 이 된다.
    func completionWindowApplyCompletion(
        item: CodeSuggestionEntry,
        textView: TextViewController,
        cursorPosition: CursorPosition?
    ) {
        guard let entry = item as? SwiftSuggestionEntry else { return }
        guard let offset = cursorPosition?.range.location, offset != NSNotFound, offset >= 0 else {
            return
        }
        let range = SwiftCompletionSupport.replacementRange(
            cursorOffset: offset, in: textView.text
        )
        let insertion = entry.candidate.insertText
        textView.textView.replaceCharacters(in: range, with: insertion)
        textView.setCursorPositions([
            CursorPosition(range: NSRange(location: range.location + (insertion as NSString).length, length: 0))
        ])
        popupState = .closed
    }
}
