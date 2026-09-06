import Foundation

/// 디렉티브 마크다운을 **바이트 단위로** 굽는 자리.
///
/// 문법 규칙이 여기 한 군데에만 있다는 것이 요점이다. 프롬프트에는 "무엇을 쓸지"만 있고
/// "어떻게 적을지"는 없다 — 인자 문자셋, 중괄호 배치, 코드펜스 길이, 인라인 코드 백틱
/// 개수가 전부 코드가 계산하는 값이다.
///
/// 산문에 대해서는 **고치지 않고 거부한다.** 조용히 고치면 모델이 계속 같은 것을
/// 만들어 오고, 무엇이 왜 바뀌었는지 아무도 모른다. 거부한 이유는 그대로 프롬프트로
/// 되돌아간다 (``LessonSerializationError/promptFeedback``).
enum DirectiveWriter {
    // MARK: - 블록

    /// `@Name(a: b, c: d) {\n<본문>\n}` 한 덩어리.
    ///
    /// 인자는 반드시 한 줄에 다 들어간다 — 다음 줄로 넘기면 파서의 위치 계산이 어긋나고
    /// 렉시컬 사전 검사가 `headerNotSingleLine` 으로 거부한다.
    static func block(_ name: String, arguments: [(String, String)], body: String) -> String {
        var header = "@\(name)"
        if !arguments.isEmpty {
            header += "(" + arguments.map { "\($0.0): \($0.1)" }.joined(separator: ", ") + ")"
        }
        // 본문은 항상 여러 줄이다. 한 줄 본문 `@X { y }` 는 줄 끝의 `}` 까지 삼킨다.
        return "\(header) {\n\(body)\n}"
    }

    // MARK: - 인자 값

    /// 디렉티브 인자에 실을 수 있는 식별자로 다듬는다.
    ///
    /// 값 자체에 의미가 없는 자리(블록 id·선택지 id)라서 거부가 아니라 정규화다. 같은
    /// 입력은 항상 같은 출력이 되므로, 서로를 가리키는 두 값(선택지 id 와 정답 키)이
    /// 같이 다듬어져도 가리킴이 유지된다.
    static func sanitizedIdentifier(_ raw: String, fallback: String) -> String {
        var characters: [Character] = []
        for character in raw {
            if character.isASCII && (character.isLetter || character.isNumber) {
                characters.append(character)
            } else if character == "_" || character == "-" {
                characters.append(character)
            } else if characters.last != "-" {
                characters.append("-")
            }
        }
        while characters.last == "-" { characters.removeLast() }
        while let first = characters.first, !(first.isASCII && first.isLetter) {
            characters.removeFirst()
        }
        if characters.count > 64 {
            characters = Array(characters.prefix(64))
            while characters.last == "-" { characters.removeLast() }
        }
        return characters.isEmpty ? fallback : String(characters)
    }

    /// 인자에 쓸 수 있는 값인가. 파서의 `DirectiveArguments.isIdentifier` 와 같은 판정.
    static func isIdentifier(_ value: String) -> Bool {
        guard (1...64).contains(value.count) else { return false }
        guard let first = value.first, first.isASCII, first.isLetter else { return false }
        return value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-")
        }
    }

    // MARK: - 산문

    /// 산문을 본문에 놓을 수 있는 모양으로 정규화하고, 못 놓을 것은 거부한다.
    ///
    /// 정규화는 **의미를 바꾸지 않는 것만** 한다 — CRLF 를 LF 로, 줄 끝 공백 제거,
    /// 빈 줄 3개 이상을 2개로, 앞뒤 공백 제거. 거부는 셋이다.
    ///
    /// - 펜스 밖에서 `}` 로 시작하는 줄. 홀로 선 `}` 는 **디렉티브를 그 자리에서 닫는다** —
    ///   렉시컬 검사도 이건 위반으로 보지 않는다(문법상 적법한 닫기이기 때문에). 그래서
    ///   여기서 막지 않으면 레슨이 조용히 반토막 난다.
    /// - 펜스 밖에서 `@` + 대문자로 시작하는 줄. 파서가 디렉티브로 읽는다.
    /// - 닫히지 않은 코드펜스.
    static func normalizedProse(
        _ raw: String,
        context: String,
        allowingCodeFences: Bool
    ) throws(LessonSerializationError) -> String {
        let normalized = normalizeLineEndings(raw)
        var openFence: FenceMarker?

        for (index, line) in normalized.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
        {
            let lineNumber = index + 1
            if let fence = openFence {
                if fence.closes(line) { openFence = nil }
                continue
            }
            if let fence = FenceMarker(opening: line) {
                guard allowingCodeFences else {
                    throw .codeFenceInProse(context: context, line: lineNumber)
                }
                openFence = fence
                continue
            }
            let body = line.drop { $0 == " " || $0 == "\t" }
            guard let first = body.first else { continue }
            if first == "}" {
                throw .proseClosesDirective(context: context, line: lineNumber)
            }
            if first == "@", let second = body.dropFirst().first, second.isASCII, second.isUppercase
            {
                throw .proseLooksLikeDirective(
                    context: context, line: lineNumber, text: String(body.prefix(40)))
            }
        }
        if openFence != nil { throw .unclosedCodeFence(context: context) }

        let collapsed = collapseBlankRuns(normalized).trimmedOuterWhitespace()
        guard !collapsed.isEmpty else { throw .emptyBody(context: context) }
        return collapsed
    }

    // MARK: - 코드

    /// 코드를 펜스로 감싼다. 펜스 길이는 코드 안의 가장 긴 백틱 연속보다 하나 길다.
    ///
    /// 모델이 코드를 ```` ``` ```` 로 감싸 보내는 일이 흔해서 알맹이만 남기고 다시
    /// 감싼다 — 이중 펜스는 파서에게 "코드 블록 안의 텍스트"가 되어 실행 대상이 사라진다.
    static func fencedCode(_ raw: String, info: String) -> String {
        let code = normalizeLineEndings(strippingOuterFence(raw))
            .trimmedTrailingNewlines()
        let longestRun = code.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Int in
                var longest = 0
                var current = 0
                for character in line {
                    if character == "`" {
                        current += 1
                        longest = max(longest, current)
                    } else {
                        current = 0
                    }
                }
                return longest
            }
            .max() ?? 0
        let fence = String(repeating: "`", count: max(3, longestRun + 1))
        return "\(fence)\(info)\n\(code)\n\(fence)"
    }

    /// 코드 알맹이. 펜스 없이 저장·실행되는 형태 — 끝에 개행 하나.
    static func normalizedCode(_ raw: String, context: String) throws(LessonSerializationError)
        -> String
    {
        let code = normalizeLineEndings(strippingOuterFence(raw)).trimmedTrailingNewlines()
        guard !code.trimmedOuterWhitespace().isEmpty else { throw .emptyCode(context: context) }
        return code + "\n"
    }

    /// 인라인 코드. 백틱 개수를 알맹이보다 길게 잡고, 필요하면 공백으로 패딩한다.
    ///
    /// `@Answer` 본문이 이걸 쓴다. 정답을 평문으로 두면 `*` 나 `_` 가 강조 문법으로
    /// 먹혀 채점 문자열이 조용히 달라진다 — 인라인 코드 안에서는 아무것도 해석되지 않는다.
    static func inlineCode(_ raw: String, context: String) throws(LessonSerializationError)
        -> String
    {
        let text = normalizeLineEndings(raw).trimmedOuterWhitespace()
        guard !text.isEmpty else { throw .emptyBody(context: context) }
        guard !text.contains("\n") else { throw .multilineAnswer(context: context, text: text) }

        var longest = 0
        var current = 0
        for character in text {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        let ticks = String(repeating: "`", count: longest + 1)
        // CommonMark 는 앞뒤에 공백이 **둘 다** 있을 때만 한 쌍을 벗긴다. 백틱으로
        // 시작하거나 끝나는 값이 아니면 패딩이 오히려 값에 남으므로 붙이지 않는다.
        let needsPadding = text.hasPrefix("`") || text.hasSuffix("`")
        return needsPadding ? "\(ticks) \(text) \(ticks)" : "\(ticks)\(text)\(ticks)"
    }

    // MARK: - 문자열 손질

    static func normalizeLineEndings(_ raw: String) -> String {
        // Swift 에서 "\r\n" 은 Character 하나라 `replacingOccurrences(of: "\r\n")` 만으로는
        // 홀로 선 CR 이 남는다. 둘 다 친다.
        raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0.trimmingTrailingSpaces()) }
            .joined(separator: "\n")
    }

    /// 모델이 씌워 보낸 바깥 코드펜스를 벗긴다. 안쪽 펜스는 건드리지 않는다.
    private static func strippingOuterFence(_ raw: String) -> String {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
        var start = 0
        var end = lines.count
        while start < end, lines[start].trimmedOuterWhitespace().isEmpty { start += 1 }
        while end > start, lines[end - 1].trimmedOuterWhitespace().isEmpty { end -= 1 }
        guard start < end, let fence = FenceMarker(opening: lines[start]),
            fence.closes(lines[end - 1])
        else { return raw }
        return lines[(start + 1)..<(end - 1)].joined(separator: "\n")
    }

    private static func collapseBlankRuns(_ text: String) -> String {
        var result: [Substring] = []
        var blankRun = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmedOuterWhitespace().isEmpty {
                blankRun += 1
                if blankRun > 1 { continue }
            } else {
                blankRun = 0
            }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    /// 코드펜스 한 줄. ``DirectiveSourceLint`` 의 렉서와 같은 판정이어야 한다 —
    /// 여기서 펜스로 안 보는 줄을 저쪽이 펜스로 보면 검사가 서로 다른 것을 본다.
    private struct FenceMarker {
        let character: Character
        let length: Int

        init?(opening line: some StringProtocol) {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
            let run = trimmed.prefix { $0 == first }
            guard run.count >= 3 else { return nil }
            if first == "`" && trimmed.dropFirst(run.count).contains("`") { return nil }
            self.character = first
            self.length = run.count
        }

        func closes(_ line: some StringProtocol) -> Bool {
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            let run = trimmed.prefix { $0 == character }
            guard run.count >= length else { return false }
            return trimmed.dropFirst(run.count).allSatisfy { $0 == " " || $0 == "\t" }
        }
    }
}

extension StringProtocol {
    func trimmingTrailingSpaces() -> SubSequence {
        var slice = self[startIndex...]
        while let last = slice.last, last == " " || last == "\t" { slice = slice.dropLast() }
        return slice
    }

    func trimmedOuterWhitespace() -> String {
        var slice = self[startIndex...]
        while let first = slice.first, first.isWhitespace { slice = slice.dropFirst() }
        while let last = slice.last, last.isWhitespace { slice = slice.dropLast() }
        return String(slice)
    }

    func trimmedTrailingNewlines() -> String {
        var slice = self[startIndex...]
        while let last = slice.last, last == "\n" { slice = slice.dropLast() }
        return String(slice)
    }
}
