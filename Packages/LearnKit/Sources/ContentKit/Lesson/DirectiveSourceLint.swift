/// swift-markdown 이 **조용히 삼키는** 문법을 파싱 전에 렉시컬로 잡아낸다.
///
/// 실측한 세 가지 함정:
/// 1. `@X(id: y) 뒤에 붙은 텍스트` — 중괄호가 없으면 뒤 텍스트는 사라진다. 에러도 없다.
/// 2. `@X { 한 줄 본문 }` — 줄 끝의 `}` 까지 본문으로 삼킨다. 닫힌 것처럼 보이지만 아니다.
/// 3. `@X(a: 1,` 로 시작하는 여러 줄 인자 — 파싱은 되지만 위치 계산이 줄마다 어긋난다.
///
/// 세 가지 다 트리를 본 뒤에는 되돌릴 수 없다(정보가 이미 없다). 그래서 소스를 먼저 훑는다.
public enum DirectiveSourceLint {
    /// 위반을 전부 찾아 소스 순서대로 돌려준다.
    public static func violations(in source: String) -> [LessonParseError] {
        var errors: [LessonParseError] = []
        var openFence: Fence?

        for (index, rawLine) in source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
        {
            let lineNumber = index + 1
            let line = String(rawLine)

            if let fence = openFence {
                if fence.closes(line[...]) { openFence = nil }
                continue
            }
            if let fence = Fence(opening: line[...]) {
                openFence = fence
                continue
            }

            let indent = line.prefix { $0 == " " || $0 == "\t" }
            let body = line.dropFirst(indent.count)
            if body.isEmpty { continue }

            if body.first == "}" {
                if body.trimmingTrailingWhitespace() != "}" {
                    errors.append(
                        LessonParseError(
                            .closingBraceNotAlone(String(body)),
                            at: SourcePosition(line: lineNumber, column: indent.count + 1)))
                }
                continue
            }

            guard body.first == "@", let header = DirectiveHeader(scanning: body) else { continue }
            let column = indent.count + 1

            switch header.tail {
            case .unterminatedArguments:
                errors.append(
                    LessonParseError(
                        .headerNotSingleLine(directive: header.name),
                        at: SourcePosition(line: lineNumber, column: column)))
            case .nothing, .braceOnly:
                continue
            case .braceThenText:
                errors.append(
                    LessonParseError(
                        .singleLineBody(directive: header.name),
                        at: SourcePosition(line: lineNumber, column: column)))
            case .text(let text):
                errors.append(
                    LessonParseError(
                        .trailingTextAfterDirective(directive: header.name, text: text),
                        at: SourcePosition(line: lineNumber, column: column)))
            }
        }
        return errors
    }

    /// 첫 위반에서 던진다.
    public static func check(_ source: String) throws(LessonParseError) {
        if let first = violations(in: source).first { throw first }
    }

    // MARK: - 렉서

    /// 펜스 코드 블록. 안에서는 `@dataclass` 나 `}` 같은 것이 나와도 디렉티브가 아니다.
    private struct Fence {
        let character: Character
        let length: Int

        init?(opening line: Substring) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
            let run = trimmed.prefix { $0 == first }
            guard run.count >= 3 else { return nil }
            // ``` 로 시작하는 info string 에 백틱이 들어가면 CommonMark 상 펜스가 아니다.
            if first == "`" && trimmed.dropFirst(run.count).contains("`") { return nil }
            self.character = first
            self.length = run.count
        }

        func closes(_ line: Substring) -> Bool {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            let run = trimmed.prefix { $0 == character }
            guard run.count >= length else { return false }
            return trimmed.dropFirst(run.count).allSatisfy { $0 == " " || $0 == "\t" }
        }
    }

    private struct DirectiveHeader {
        enum Tail: Equatable {
            /// 인자 목록의 `)` 가 같은 줄에 없다.
            case unterminatedArguments
            /// 헤더 뒤에 아무것도 없다 — 본문 없는 디렉티브.
            case nothing
            /// 헤더 뒤가 `{` 하나 — 여러 줄 본문의 시작.
            case braceOnly
            /// `{` 뒤에 같은 줄 내용이 더 있다 — 한 줄 본문.
            case braceThenText
            /// 중괄호 없이 텍스트가 붙었다 — 조용히 버려진다.
            case text(String)
        }

        let name: String
        let tail: Tail

        /// `@` 로 시작하는 줄을 스캔한다. 디렉티브 이름은 **대문자로 시작**해야 한다 —
        /// 그래야 산문 속의 `@user` 나 들여쓰기 코드의 `@property` 를 오탐하지 않는다.
        init?(scanning body: Substring) {
            var rest = body.dropFirst()  // '@'
            guard let first = rest.first, first.isASCII, first.isUppercase else { return nil }
            let name = rest.prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
            rest = rest.dropFirst(name.count)

            if rest.first == "(" {
                guard let close = rest.firstIndex(of: ")") else {
                    self.name = String(name)
                    self.tail = .unterminatedArguments
                    return
                }
                rest = rest[rest.index(after: close)...]
            }

            let remainder = rest.drop { $0 == " " || $0 == "\t" }.trimmingTrailingWhitespace()
            self.name = String(name)
            if remainder.isEmpty {
                self.tail = .nothing
            } else if remainder == "{" {
                self.tail = .braceOnly
            } else if remainder.hasPrefix("{") {
                self.tail = .braceThenText
            } else {
                self.tail = .text(String(remainder))
            }
        }
    }
}

extension StringProtocol {
    /// 후행 공백·탭을 뗀 슬라이스. Foundation 없이 쓴다.
    func trimmingTrailingWhitespace() -> Self.SubSequence {
        var slice = self[startIndex...]
        while let last = slice.last, last == " " || last == "\t" || last == "\r" {
            slice = slice.dropLast()
        }
        return slice
    }

    /// 앞뒤 공백·탭·개행을 뗀 `String`.
    func trimmedWhitespace() -> String {
        var slice = self[startIndex...]
        while let first = slice.first, first.isWhitespace { slice = slice.dropFirst() }
        while let last = slice.last, last.isWhitespace { slice = slice.dropLast() }
        return String(slice)
    }
}
