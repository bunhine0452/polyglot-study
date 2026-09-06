import Foundation
import Testing

@testable import LSPKit

@Suite("편집기 좌표 ↔ LSP 좌표")
struct LSPPositionConversionTests {
    static let source = "import Foundation\n\nlet greeting = \"hello\"\nprint(greeting.)\n"

    @Test("문서 전체 UTF-16 오프셋이 (줄, 열) 이 된다")
    func globalOffsetBecomesLineAndCharacter() {
        // `print(greeting.` 의 점 바로 뒤 = 실측 완성 요청이 쓴 자리.
        let offset = Self.source.distance(
            from: Self.source.startIndex,
            to: Self.source.range(of: "print(greeting.")!.upperBound
        )
        let position = LSPPositionConversion.position(utf16Offset: offset, in: Self.source)
        #expect(position.line == 3)
        #expect(position.character == 15)
    }

    @Test("오프셋 0 은 문서 첫 자리다")
    func zeroOffsetIsTheOrigin() {
        let position = LSPPositionConversion.position(utf16Offset: 0, in: Self.source)
        #expect(position == LSPPosition(line: 0, character: 0))
    }

    @Test("줄바꿈 직후는 다음 줄 0열이다")
    func offsetJustAfterNewlineStartsANewLine() {
        // "import Foundation\n" 은 18 UTF-16 단위.
        let position = LSPPositionConversion.position(utf16Offset: 18, in: Self.source)
        #expect(position.line == 1)
        #expect(position.character == 0)
    }

    /// `"\r\n"` 은 Swift 에서 Character **하나**이고 UTF-16 으로는 **둘**이다.
    /// 줄바꿈으로 세되 폭은 2 로 세지 않으면 CRLF 문서에서 오프셋이 줄마다 하나씩 밀린다.
    @Test("CRLF 는 Character 하나지만 UTF-16 으로 둘이다")
    func crlfCountsAsTwoUTF16UnitsButOneNewline() {
        let text = "ab\r\ncd"
        #expect(text.count == 5)
        #expect(text.utf16.count == 6)
        // 'c' 자리 = UTF-16 오프셋 4.
        let position = LSPPositionConversion.position(utf16Offset: 4, in: text)
        #expect(position.line == 1)
        #expect(position.character == 0)
        // 'd' 자리.
        #expect(LSPPositionConversion.position(utf16Offset: 5, in: text).character == 1)
    }

    @Test("이모지 뒤의 오프셋이 UTF-16 단위로 센다")
    func emojiWidthsAreCountedInUTF16() {
        let text = "let 🇰🇷 = 1"
        // 태극기 뒤 = Character 로는 5번째지만 UTF-16 오프셋 8.
        let afterFlag = LSPPositionConversion.position(utf16Offset: 8, in: text)
        #expect(afterFlag.line == 0)
        #expect(afterFlag.character == 8)
    }

    @Test("1-기반 (줄, 칼럼) 도 LSP 위치가 된다")
    func oneBasedLineColumnConverts() {
        let position = LSPPositionConversion.position(line: 4, column: 16, in: Self.source)
        #expect(position.line == 3)
        #expect(position.character == 15)
    }

    @Test("표시 칼럼 → UTF-16 오프셋은 그 역함수다")
    func displayColumnAndUTF16OffsetAreInverses() {
        let line = "let 🇰🇷 = 1"
        for column in 1...(line.count + 1) {
            let offset = LSPPositionConversion.utf16Offset(displayColumn: column, in: line)
            #expect(LSPDiagnosticMapping.displayColumn(utf16Offset: offset, in: line) == column)
        }
    }

    @Test("칼럼 1 은 오프셋 0 이다")
    func firstColumnIsOffsetZero() {
        #expect(LSPPositionConversion.utf16Offset(displayColumn: 1, in: "abc") == 0)
        #expect(LSPPositionConversion.utf16Offset(displayColumn: 0, in: "abc") == 0)
    }

    @Test("문서 범위를 벗어난 줄은 0열로 접는다 — 없는 칼럼을 지어내지 않는다")
    func outOfRangeLineClampsToZeroColumn() {
        let position = LSPPositionConversion.position(line: 999, column: 5, in: Self.source)
        #expect(position.line == 998)
        #expect(position.character == 0)
    }

    @Test("오프셋이 문서보다 길면 마지막 자리에 멈춘다")
    func offsetPastEndStopsAtTheEnd() {
        let position = LSPPositionConversion.position(utf16Offset: 9_999, in: "ab\ncd")
        #expect(position.line == 1)
        #expect(position.character == 2)
    }

    @Test("줄 뽑기는 캐리지 리턴을 떼어 낸다")
    func lineExtractionStripsCarriageReturn() {
        #expect(LSPPositionConversion.line(0, of: "ab\r\ncd") == "ab")
        #expect(LSPPositionConversion.line(1, of: "ab\r\ncd") == "cd")
        #expect(LSPPositionConversion.line(5, of: "ab\ncd") == nil)
        #expect(LSPPositionConversion.line(-1, of: "ab") == nil)
    }
}
