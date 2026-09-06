internal import AppKit

/// `NSPasteboard` 를 건드리는 유일한 지점. **여기서도 프로세스를 실행하지 않는다** —
/// 문자열을 클립보드에 넣기만 한다.
enum SystemClipboard {
    nonisolated static func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
