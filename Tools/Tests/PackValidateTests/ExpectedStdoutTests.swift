import Foundation
import Testing

@testable import PackValidate

@Suite("기대 출력 정규화")
struct ExpectedStdoutTests {
    @Test("CRLF 와 단독 CR 은 LF 로 접힌다")
    func newlinesAreUnified() {
        #expect(ExpectedStdout.normalize("a\r\nb\r\n") == Data("a\nb\n".utf8))
        #expect(ExpectedStdout.normalize("a\rb\r") == Data("a\nb\n".utf8))
        #expect(ExpectedStdout.normalize("a\r\n\r\nb") == Data("a\n\nb\n".utf8))
    }

    @Test("후행 개행은 정확히 하나가 된다")
    func trailingNewlineIsNormalized() {
        #expect(ExpectedStdout.normalize("a") == Data("a\n".utf8))
        #expect(ExpectedStdout.normalize("a\n") == Data("a\n".utf8))
        #expect(ExpectedStdout.normalize("a\n\n\n") == Data("a\n".utf8))
        #expect(ExpectedStdout.normalize("") == Data())
        #expect(ExpectedStdout.normalize("\n\n") == Data())
    }

    @Test("선행 BOM 은 버린다")
    func bomIsDropped() {
        var withBOM = Data([0xEF, 0xBB, 0xBF])
        withBOM.append(Data("a\n".utf8))
        #expect(ExpectedStdout.normalize(withBOM) == Data("a\n".utf8))
    }

    @Test("줄 끝 공백은 접지 않는다 — 다른 프로그램이다")
    func trailingSpacesMatter() {
        #expect(!ExpectedStdout.matches(expected: Data("a \n".utf8), actual: Data("a\n".utf8)))
    }

    @Test("줄 사이 빈 줄도 접지 않는다")
    func interiorBlankLinesMatter() {
        #expect(!ExpectedStdout.matches(expected: Data("a\n\nb\n".utf8), actual: Data("a\nb\n".utf8)))
    }

    @Test("정규화 결과를 줄로 쪼갠다")
    func lines() {
        #expect(ExpectedStdout.lines(ExpectedStdout.normalize("a\nb\n")) == ["a", "b"])
        #expect(ExpectedStdout.lines(ExpectedStdout.normalize("")).isEmpty)
    }
}

@Suite("줄 단위 diff")
struct LineDiffTests {
    @Test("바뀐 줄을 - 와 + 로 보여준다")
    func showsChangedLines() {
        let diff = LineDiff.render(
            expected: ["a", "b", "c"], actual: ["a", "B", "c"],
            expectedLabel: "expected/x.txt", actualLabel: "러너 stdout")
        #expect(diff.contains("--- 기대: expected/x.txt"))
        #expect(diff.contains("+++ 실제: 러너 stdout"))
        #expect(diff.contains("- b"))
        #expect(diff.contains("+ B"))
        #expect(diff.contains("  a"))
    }

    @Test("줄이 더 있거나 없어도 잡는다")
    func handlesLengthDifference() {
        let missing = LineDiff.render(
            expected: ["a", "b"], actual: ["a"], expectedLabel: "e", actualLabel: "a")
        #expect(missing.contains("- b"))
        let extra = LineDiff.render(
            expected: ["a"], actual: ["a", "b"], expectedLabel: "e", actualLabel: "a")
        #expect(extra.contains("+ b"))
    }

    @Test("같으면 차이가 없다고 말한다")
    func identicalInputs() {
        let diff = LineDiff.render(
            expected: ["a"], actual: ["a"], expectedLabel: "e", actualLabel: "a")
        #expect(diff.contains("줄 단위 차이가 없다"))
    }

    @Test("아주 긴 출력은 첫 불일치만 보고한다")
    func fallsBackForHugeOutput() {
        let expected = (0..<(LineDiff.maxLinesForFullDiff + 10)).map { "line \($0)" }
        var actual = expected
        actual[7] = "달라진 줄"
        let diff = LineDiff.render(
            expected: expected, actual: actual, expectedLabel: "e", actualLabel: "a")
        #expect(diff.contains("8행에서 처음 갈린다"))
        #expect(diff.contains("+ 달라진 줄"))
    }
}
