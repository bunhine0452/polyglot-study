internal import Foundation

/// 콘솔 프리젠터가 그리는 것. 실행 스트림이 흘려보낸 바이트를 **줄 단위**로 접어 둔 것이다.
///
/// 청크 경계는 줄 경계와 무관하다 — `print("ab")` 가 `"a"` + `"b\n"` 두 조각으로 올 수
/// 있다. 그래서 마지막 줄이 열려 있는지(`openStream`)를 들고 있다가 같은 스트림의
/// 다음 조각을 이어 붙인다. 안 그러면 한 줄이 세 줄로 쪼개져 보인다.
public struct ConsoleTranscript: Hashable, Sendable {
    public enum Stream: String, Hashable, Sendable, CaseIterable {
        case output
        case error
        /// 러너가 붙인 메모 — 절단 안내, 실패 원인처럼 프로그램이 낸 것이 아닌 줄.
        case note
    }

    public struct Line: Hashable, Sendable, Identifiable {
        public let id: Int
        public var stream: Stream
        public var text: String

        public init(id: Int, stream: Stream, text: String) {
            self.id = id
            self.stream = stream
            self.text = text
        }
    }

    public private(set) var lines: [Line] = []
    public var isRunning: Bool = false
    public var isTruncated: Bool = false
    public var exitCode: Int32?
    public var durationMilliseconds: Int?

    /// 마지막 줄이 개행 없이 끝난 스트림. nil 이면 줄이 닫혀 있다.
    private var openStream: Stream?
    private var nextLineID = 0

    public init(
        isRunning: Bool = false,
        isTruncated: Bool = false,
        exitCode: Int32? = nil,
        durationMilliseconds: Int? = nil
    ) {
        self.isRunning = isRunning
        self.isTruncated = isTruncated
        self.exitCode = exitCode
        self.durationMilliseconds = durationMilliseconds
    }

    public static let empty = ConsoleTranscript()

    public var isEmpty: Bool { lines.isEmpty }

    public var hasErrorOutput: Bool { lines.contains { $0.stream == .error } }

    /// 실행 스트림에서 온 조각 하나를 붙인다.
    public mutating func append(_ text: String, stream: Stream) {
        guard !text.isEmpty else { return }
        // `"\r\n"` 은 Swift 에서 Character 하나라 `split(separator: "\n")` 이 CRLF 를 뭉친다.
        let normalized =
            text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var segments = normalized.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let endsWithNewline = segments.count > 1 && segments[segments.count - 1].isEmpty
        if endsWithNewline { segments.removeLast() }

        if openStream == stream, !lines.isEmpty, let first = segments.first {
            lines[lines.count - 1].text += first
            segments.removeFirst()
        }
        for segment in segments {
            lines.append(Line(id: nextLineID, stream: stream, text: segment))
            nextLineID += 1
        }
        openStream = endsWithNewline ? nil : stream
    }

    /// 러너가 아니라 앱이 넣는 한 줄. 항상 자기 줄을 차지한다.
    public mutating func appendNote(_ text: String) {
        openStream = nil
        lines.append(Line(id: nextLineID, stream: .note, text: text))
        nextLineID += 1
    }

    public mutating func markTruncated() {
        guard !isTruncated else { return }
        isTruncated = true
        appendNote("출력이 상한을 넘어 잘렸습니다.")
    }

    /// stdout 만 이어 붙인 원문. 기대 출력과 대조할 때 쓴다.
    public var standardOutputText: String {
        lines.filter { $0.stream == .output }.map(\.text).joined(separator: "\n")
    }

    /// 오른쪽 위에 붙는 상태 한 마디. **실행 전에도 자리를 차지한다.**
    public var statusLabel: String {
        if isRunning { return "실행 중" }
        if lines.isEmpty && exitCode == nil { return "실행 전" }
        guard let exitCode else { return "완료" }
        return exitCode == 0 ? "종료 0" : "종료 \(exitCode)"
    }
}
