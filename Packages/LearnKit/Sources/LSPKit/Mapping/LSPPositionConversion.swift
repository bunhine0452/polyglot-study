internal import Foundation

/// 편집기 좌표 ↔ LSP 좌표.
///
/// 세 가지 표현이 돌아다닌다. 이 파일이 그 사이의 유일한 통로다.
///
/// | 표현 | 줄 | 열 |
/// | --- | --- | --- |
/// | LSP `Position` | 0-기반 | 그 줄의 **UTF-16 코드 단위** 오프셋, 0-기반 |
/// | 편집기 커서 | 1-기반 | 1-기반 **문자** 칼럼 |
/// | `NSRange.location` | — | 문서 전체의 **UTF-16 오프셋** |
///
/// 셋을 눈대중으로 오가면 ASCII 에서는 전부 맞고 이모지·한글 조합형이 섞이는 순간
/// 조용히 어긋난다. 그래서 프로세스도 편집기도 없이 테스트한다.
public enum LSPPositionConversion {
    /// 문서 전체의 UTF-16 오프셋 → LSP 위치.
    ///
    /// `CodeEditSourceEditor` 의 `CursorPosition.range.location` 이 이 값이다. 줄·열보다
    /// 이쪽이 정확하다 — 편집기가 세는 "열" 의 정의를 우리가 다시 가정하지 않아도 된다.
    public static func position(utf16Offset offset: Int, in text: String) -> LSPPosition {
        guard offset > 0 else { return LSPPosition(line: 0, character: 0) }
        var line = 0
        var characterOffset = 0
        var consumed = 0

        for character in text {
            if consumed >= offset { break }
            let width = character.utf16.count
            // `"\r\n"` 은 Swift 에서 Character **하나**이고 UTF-16 으로는 둘이다.
            // 줄바꿈으로 세되 폭은 2 로 세야 오프셋이 어긋나지 않는다.
            //
            // `character.isNewline` 을 쓰지 않는다. 그건 홀로 선 `\r`·U+2028·U+2029
            // 까지 줄바꿈으로 세는데, 줄을 꺼내는 ``line(_:of:)`` 는
            // `components(separatedBy: "\n")` 이라 그것들을 세지 않는다. 둘이 다르면
            // 줄 번호는 늘었는데 그 줄을 꺼내지 못해 칼럼이 조용히 근사값으로 떨어진다.
            // **두 함수는 같은 줄바꿈 정의를 써야 한다.**
            if character == "\n" || character == "\r\n" {
                line += 1
                characterOffset = 0
            } else {
                characterOffset += width
            }
            consumed += width
        }
        return LSPPosition(line: line, character: characterOffset)
    }

    /// 1-기반 (줄, 문자 칼럼) → LSP 위치.
    ///
    /// 편집기가 UTF-16 오프셋을 주지 못할 때의 경로다. 줄이 문서 범위를 벗어나면
    /// 열은 0 으로 접는다 — 없는 줄의 칼럼을 지어내지 않는다.
    public static func position(line: Int, column: Int, in text: String) -> LSPPosition {
        let zeroBasedLine = max(0, line - 1)
        guard let lineText = self.line(zeroBasedLine, of: text) else {
            return LSPPosition(line: zeroBasedLine, character: 0)
        }
        return LSPPosition(
            line: zeroBasedLine,
            character: utf16Offset(displayColumn: column, in: lineText)
        )
    }

    /// 1-기반 문자 칼럼 → 그 줄의 0-기반 UTF-16 오프셋. `displayColumn` 의 역함수다.
    public static func utf16Offset(displayColumn column: Int, in line: String) -> Int {
        guard column > 1 else { return 0 }
        var remaining = column - 1
        var offset = 0
        for character in line {
            if remaining == 0 { break }
            offset += character.utf16.count
            remaining -= 1
        }
        return offset
    }

    /// 0-기반 줄 번호로 본문에서 그 줄을 꺼낸다. 캐리지 리턴은 떼어 낸다.
    public static func line(_ index: Int, of text: String) -> String? {
        guard index >= 0 else { return nil }
        // `components(separatedBy:)` 다. `split(separator: "\n")` 은 `"\r\n"` 이
        // Character 하나라 CRLF 본문을 뭉친다.
        let lines = text.components(separatedBy: "\n")
        guard index < lines.count else { return nil }
        var line = lines[index]
        if line.hasSuffix("\r") { line.removeLast() }
        return line
    }
}
