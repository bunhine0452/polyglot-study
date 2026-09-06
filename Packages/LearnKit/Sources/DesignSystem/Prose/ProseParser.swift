internal import Foundation

/// 마크다운 소스에서 **블록 구조만** 뽑는 줄 단위 스캐너.
///
/// 인라인은 손대지 않는다 — 문단·제목·목록 항목의 본문은 마크다운 소스 그대로
/// ``ProseBlock`` 에 실려 나가고, `AttributedString` 이 그걸 받는다.
///
/// swift-markdown 을 쓰지 않는 이유: `Markup` 은 `Sendable` 이 아니고
/// (`HANDOFF.md`), ContentKit 이 이미 그 경계에서 산문을 **문자열**로 옮겨 뒀다.
/// DesignSystem 이 다시 그 트리를 들이면 경계가 두 겹이 된다.
public enum ProseParser {
    /// 목록·인용의 중첩 상한. 넘으면 남은 줄을 문단 하나로 접는다 —
    /// 들여쓰기만 수천 칸 있는 입력이 스택을 태우지 못하게 하는 안전장치다.
    public static let maximumNestingDepth = 6

    public static func parse(_ source: String) -> [ProseBlock] {
        parse(lines: normalizedLines(source), depth: 0)
    }

    /// `"\r\n"` 은 Swift 에서 **Character 하나**라 `split(separator: "\n")` 이 CRLF 를
    /// 뭉친다(실측). 그래서 먼저 정규화한다.
    ///
    /// - Note: 예전에는 여기서 방출기가 붙인 매달린 들여쓰기를 한 단씩 벗기는
    ///   `strippingEmittedIndent(_:)` 를 함께 돌렸다. `ContentKit.Body.prose` 가
    ///   디렉티브 본문을 붙어 있는 채로 `MarkupFormatter` 에 넘기는 바람에 모든 줄이
    ///   (디렉티브 깊이 × 4)칸 밀려 나왔기 때문이다. 그 왕복 결함을 근원에서 고쳤으므로
    ///   (`ContentKit/Lesson/DirectiveBody.swift` 의 `detachedFromParent`,
    ///   `ContentKitTests/ProseRoundTripTests` 가 다섯 증상을 고정한다) 벗기기는
    ///   지웠다. 남겨 둘 이유도 없었다 — 그 규칙은 손으로 쓴 4칸 들여쓰기 코드블록을
    ///   문단으로 오해할 수 있는 **추측**이었고, 이제 그 입력은 오지 않는다.
    static func normalizedLines(_ source: String) -> [String] {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    // MARK: - 주 루프

    static func parse(lines: [String], depth: Int) -> [ProseBlock] {
        guard depth <= maximumNestingDepth else {
            let text = lines.joined(separator: " ").trimmed
            return text.isEmpty ? [] : [.paragraph(text)]
        }

        var blocks: [ProseBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.trimmed.isEmpty {
                index += 1
                continue
            }
            if let fence = CodeFence(opening: line) {
                let (code, next) = codeBlock(from: lines, at: index, fence: fence)
                blocks.append(.code(code))
                index = next
                continue
            }
            if let parsed = heading(line) {
                blocks.append(parsed)
                index += 1
                continue
            }
            if isThematicBreak(line) {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }
            if quoteContent(line) != nil {
                var body: [String] = []
                while index < lines.count, let content = quoteContent(lines[index]) {
                    body.append(content)
                    index += 1
                }
                blocks.append(.blockquote(parse(lines: body, depth: depth + 1)))
                continue
            }
            if let marker = ListMarker(line) {
                let (parsed, next) = list(from: lines, at: index, first: marker, depth: depth)
                blocks.append(.list(parsed))
                index = next
                continue
            }
            let (text, next) = paragraph(from: lines, at: index)
            if !text.isEmpty { blocks.append(.paragraph(text)) }
            index = next
        }
        return blocks
    }

    // MARK: - 블록별 스캐너

    static func codeBlock(from lines: [String], at start: Int, fence: CodeFence)
        -> (ProseCode, Int)
    {
        var body: [String] = []
        var index = start + 1
        while index < lines.count, !fence.closes(lines[index]) {
            body.append(fence.stripIndent(from: lines[index]))
            index += 1
        }
        if index < lines.count { index += 1 }  // 닫는 펜스
        return (ProseCode(language: fence.language, text: body.joined(separator: "\n")), index)
    }

    static func heading(_ line: String) -> ProseBlock? {
        let indent = line.leadingSpaces
        guard indent < 4 else { return nil }
        let rest = line.dropFirst(indent)
        let hashes = rest.prefix(while: { $0 == "#" }).count
        guard hashes >= 1, hashes <= 6 else { return nil }
        let after = rest.dropFirst(hashes)
        guard after.isEmpty || after.first == " " else { return nil }
        return .heading(level: hashes, text: strippingClosingHashes(String(after).trimmed))
    }

    /// `## 제목 ##` 의 닫는 `#` 열. 공백이 앞설 때만 벗긴다 — `C#` 을 잘라내면 안 된다.
    private static func strippingClosingHashes(_ text: String) -> String {
        let trailing = text.reversed().prefix(while: { $0 == "#" }).count
        guard trailing > 0, trailing < text.count else { return text }
        let head = text.dropLast(trailing)
        guard head.last == " " else { return text }
        return String(head).trimmed
    }

    static func isThematicBreak(_ line: String) -> Bool {
        let trimmed = line.trimmed
        guard let first = trimmed.first, first == "-" || first == "*" || first == "_" else {
            return false
        }
        let stripped = trimmed.filter { $0 != " " && $0 != "\t" }
        return stripped.count >= 3 && stripped.allSatisfy { $0 == first }
    }

    static func quoteContent(_ line: String) -> String? {
        let indent = line.leadingSpaces
        guard indent < 4 else { return nil }
        var rest = line.dropFirst(indent)
        guard rest.first == ">" else { return nil }
        rest = rest.dropFirst()
        if rest.first == " " { rest = rest.dropFirst() }
        return String(rest)
    }

    static func list(from lines: [String], at start: Int, first: ListMarker, depth: Int)
        -> (ProseList, Int)
    {
        var items: [[ProseBlock]] = []
        var index = start
        while index < lines.count, let marker = ListMarker(lines[index]),
            marker.isOrdered == first.isOrdered
        {
            var body: [String] = [marker.content]
            index += 1
            while index < lines.count {
                let line = lines[index]
                if line.trimmed.isEmpty {
                    // 빈 줄 다음이 여전히 항목 안이면 느슨한 목록이라 계속 간다.
                    let following = index + 1
                    guard following < lines.count,
                        lines[following].leadingSpaces >= marker.contentIndent
                    else { break }
                    body.append("")
                    index += 1
                    continue
                }
                if line.leadingSpaces >= marker.contentIndent {
                    body.append(String(line.dropFirst(marker.contentIndent)))
                    index += 1
                    continue
                }
                if ListMarker(line) != nil || isBlockStart(line) { break }
                body.append(line.trimmed)  // 게으른 이어짐
                index += 1
            }
            items.append(parse(lines: body, depth: depth + 1))
        }
        return (ProseList(isOrdered: first.isOrdered, start: first.number, items: items), index)
    }

    /// 문단. **소프트 개행은 공백으로 접는다** — 소스가 90열에서 접혀 있으므로 개행을
    /// 그대로 두면 화면에서도 그 자리에서 끊긴다. 두 칸으로 끝나거나 역슬래시로
    /// 끝나는 줄만 강제 개행으로 살린다.
    static func paragraph(from lines: [String], at start: Int) -> (String, Int) {
        var pieces: [String] = []
        var index = start
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmed
            if trimmed.isEmpty { break }
            if index > start, isBlockStart(line) || ListMarker(line) != nil { break }
            let hardBreak = line.hasSuffix("  ") || trimmed.hasSuffix("\\")
            let text = trimmed.hasSuffix("\\") ? String(trimmed.dropLast()) : trimmed
            pieces.append(hardBreak ? text + "\n" : text)
            index += 1
        }
        var result = ""
        for piece in pieces {
            if !result.isEmpty, !result.hasSuffix("\n") { result += " " }
            result += piece
        }
        return (result, max(index, start + 1))
    }

    static func isBlockStart(_ line: String) -> Bool {
        CodeFence(opening: line) != nil || heading(line) != nil || isThematicBreak(line)
            || quoteContent(line) != nil
    }
}

// MARK: - 펜스

/// 펜스 코드 블록의 여는 줄.
struct CodeFence {
    let marker: Character
    let length: Int
    let indent: Int
    let language: String?

    init?(opening line: String) {
        let indent = line.leadingSpaces
        guard indent < 4 else { return nil }
        let rest = line.dropFirst(indent)
        guard let first = rest.first, first == "`" || first == "~" else { return nil }
        let run = rest.prefix(while: { $0 == first }).count
        guard run >= 3 else { return nil }
        let info = String(rest.dropFirst(run)).trimmed
        // 백틱 펜스의 info string 에는 백틱이 올 수 없다 — 인라인 코드와 구별되는 지점.
        if first == "`", info.contains("`") { return nil }
        self.marker = first
        self.length = run
        self.indent = indent
        self.language = info.split(separator: " ").first.map(String.init)
    }

    func closes(_ line: String) -> Bool {
        let trimmed = line.trimmed
        return trimmed.count >= length && trimmed.allSatisfy { $0 == marker }
    }

    /// 여는 펜스만큼 들여쓴 본문은 그 들여쓰기를 벗긴다.
    func stripIndent(from line: String) -> String {
        guard indent > 0, line.leadingSpaces >= indent else { return line }
        return String(line.dropFirst(indent))
    }
}

// MARK: - 목록 마커

/// 목록 항목의 여는 마커. `- `, `* `, `+ `, `1. `, `1) `.
struct ListMarker {
    let isOrdered: Bool
    let number: Int
    /// 항목 본문이 시작하는 열. 이어지는 줄이 이만큼 들여쓰였으면 같은 항목이다.
    let contentIndent: Int
    let content: String

    init?(_ line: String) {
        let indent = line.leadingSpaces
        guard indent < 4 else { return nil }
        var rest = line.dropFirst(indent)
        let isOrdered: Bool
        let number: Int
        let width: Int

        if let first = rest.first, first == "-" || first == "*" || first == "+" {
            isOrdered = false
            number = 1
            width = 1
            rest = rest.dropFirst()
        } else {
            let digits = rest.prefix { $0.isASCII && $0.isNumber }
            guard !digits.isEmpty, digits.count <= 9,
                let delimiter = rest.dropFirst(digits.count).first,
                delimiter == "." || delimiter == ")"
            else { return nil }
            isOrdered = true
            number = Int(digits) ?? 1
            width = digits.count + 1
            rest = rest.dropFirst(width)
        }

        if rest.isEmpty {
            self.isOrdered = isOrdered
            self.number = number
            self.contentIndent = indent + width + 1
            self.content = ""
            return
        }
        guard rest.first == " " else { return nil }
        self.isOrdered = isOrdered
        self.number = number
        self.contentIndent = indent + width + 1
        self.content = String(rest.dropFirst())
    }
}

// MARK: - 줄 유틸

extension StringProtocol {
    /// 탭은 4칸으로 센다.
    var leadingSpaces: Int {
        var count = 0
        for character in self {
            if character == " " {
                count += 1
            } else if character == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }

    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
