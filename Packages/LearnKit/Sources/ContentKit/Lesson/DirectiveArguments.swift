internal import Markdown

/// 디렉티브 인자를 **이름으로** 조회하는 래퍼.
///
/// swift-markdown 에는 이런 것이 없다. 업스트림 테스트 파일 안에 `fileprivate` 서브스크립트가
/// 하나 있을 뿐이라 임포트해서 쓸 수 없다. 그리고 그 헬퍼는 우리에게 필요한 일 —
/// 필수 인자 누락·중복·미지 인자를 **위치와 함께** 거부하는 일 — 을 하지 않는다.
///
/// 사용 규약: 필요한 인자를 전부 읽은 뒤 반드시 ``finish(allowing:)`` 를 불러 남은 인자를
/// 미지 인자로 거부한다. 그러지 않으면 오타 난 인자가 조용히 무시된다.
struct DirectiveArguments {
    let directiveName: String
    /// 디렉티브 이름의 위치. 인자별 위치를 못 얻을 때의 대체값.
    let directivePosition: SourcePosition

    private var remaining: [String: Entry]

    private struct Entry {
        var value: String
        var position: SourcePosition
    }

    init(_ directive: BlockDirective) throws(LessonParseError) {
        let name = directive.name
        let position = SourcePosition.at(directive.nameLocation)
        self.directiveName = name
        self.directivePosition = position

        var parseErrors: [DirectiveArgumentText.ParseError] = []
        let parsed = directive.argumentText.parseNameValueArguments(parseErrors: &parseErrors)

        if let first = parseErrors.first {
            throw LessonParseError(
                .argumentSyntax(directive: name, detail: DirectiveArguments.describe(first)),
                at: DirectiveArguments.position(of: first, fallback: position))
        }

        var table: [String: Entry] = [:]
        for argument in parsed {
            let argumentPosition = SourcePosition(argument.nameRange?.lowerBound) ?? position
            guard !argument.name.isEmpty else {
                throw LessonParseError(
                    .positionalArgument(directive: name),
                    at: SourcePosition(argument.valueRange?.lowerBound) ?? position)
            }
            guard table[argument.name] == nil else {
                throw LessonParseError(
                    .duplicateArgument(directive: name, argument: argument.name),
                    at: argumentPosition)
            }
            table[argument.name] = Entry(value: argument.value, position: argumentPosition)
        }

        // 파싱 결과로 원문을 되짚어 본다. **이게 없으면 조용히 잘린 값이 통과한다.**
        //
        // 실측: `@X(id: a:b)` 는 에러 없이 `id = "a"` 로 파싱되고 `:b` 는 사라진다.
        // 라이브러리 렉서는 값에서 `:` `,` `)` `{` 공백을 만나면 거기서 끊을 뿐 아무것도
        // 보고하지 않기 때문이다. 따옴표를 씌워도 값에 따옴표를 쓸 수 없는 것은 같다.
        // 그래서 파싱된 인자를 정규형으로 되짚어 원문(공백 제거)과 대조한다.
        let rawText = directive.argumentText.segments
            .map { String($0.trimmedText) }.joined(separator: " ")
        let rawCompact = rawText.filter { !$0.isWhitespace }
        let reconstructed = parsed.map { "\($0.name):\($0.value)" }.joined(separator: ",")
        guard rawCompact == reconstructed else {
            throw LessonParseError(
                .argumentSyntax(
                    directive: name,
                    detail: """
                        `\(rawText)` 를 `이름: 값` 목록으로 온전히 읽지 못했다 — 값에는 \
                        `:` `,` `)` `{` `"` 와 공백을 쓸 수 없고 따옴표로도 감쌀 수 없다. \
                        자유 텍스트는 본문 하위 디렉티브나 사이드카 파일로 빼라
                        """),
                at: position)
        }

        self.remaining = table
    }

    // MARK: - 조회

    /// 식별자 인자. 없으면 던진다.
    mutating func identifier(_ name: String) throws(LessonParseError) -> String {
        let entry = try take(name)
        guard DirectiveArguments.isIdentifier(entry.value) else {
            throw LessonParseError(
                .invalidArgumentValue(
                    directive: directiveName, argument: name, value: entry.value,
                    expected: .identifier),
                at: entry.position)
        }
        return entry.value
    }

    /// 열거 토큰 인자. 허용 목록 밖이면 던진다.
    mutating func token(_ name: String, allowing allowed: [String]) throws(LessonParseError) -> String {
        let entry = try take(name)
        guard DirectiveArguments.isToken(entry.value) else {
            throw LessonParseError(
                .invalidArgumentValue(
                    directive: directiveName, argument: name, value: entry.value, expected: .token),
                at: entry.position)
        }
        guard allowed.contains(entry.value) else {
            throw LessonParseError(
                .unknownArgumentToken(
                    directive: directiveName, argument: name, value: entry.value, allowed: allowed),
                at: entry.position)
        }
        return entry.value
    }

    /// 팩 상대 경로 인자. `under` 를 주면 그 디렉터리 아래인지도 본다.
    mutating func path(_ name: String, under directory: String? = nil) throws(LessonParseError)
        -> PackRelativePath
    {
        let entry = try take(name)
        let path: PackRelativePath
        do {
            path = try PackRelativePath(validating: entry.value)
        } catch {
            throw LessonParseError(
                .unsafeArgumentPath(
                    directive: directiveName, argument: name, value: entry.value, reason: error),
                at: entry.position)
        }
        if let directory, path.topLevelDirectory != directory {
            throw LessonParseError(
                .pathOutsideDirectory(
                    directive: directiveName, argument: name, value: entry.value,
                    expected: directory),
                at: entry.position)
        }
        return path
    }

    mutating func integer(_ name: String) throws(LessonParseError) -> Int {
        let entry = try take(name)
        guard DirectiveArguments.isInteger(entry.value), let value = Int(entry.value) else {
            throw LessonParseError(
                .invalidArgumentValue(
                    directive: directiveName, argument: name, value: entry.value,
                    expected: .integer),
                at: entry.position)
        }
        return value
    }

    /// 선택 인자. 없으면 nil, 있으면 식별자로 검사한다.
    mutating func optionalIdentifier(_ name: String) throws(LessonParseError) -> String? {
        guard remaining[name] != nil else { return nil }
        return try identifier(name)
    }

    /// 남은 인자를 미지 인자로 거부한다. `allowing` 은 이 디렉티브가 **읽지 않고도**
    /// 허용하는 이름 (지금은 없다 — 목록을 남겨둔 것은 후방 호환용 확장 지점이다).
    func finish(allowing allowed: [String] = []) throws(LessonParseError) {
        let unexpected = remaining.filter { !allowed.contains($0.key) }
        guard let first = unexpected.min(by: { $0.value.position < $1.value.position }) else {
            return
        }
        throw LessonParseError(
            .unknownArgument(directive: directiveName, argument: first.key),
            at: first.value.position)
    }

    private mutating func take(_ name: String) throws(LessonParseError) -> Entry {
        guard let entry = remaining.removeValue(forKey: name) else {
            throw LessonParseError(
                .missingArgument(directive: directiveName, argument: name), at: directivePosition)
        }
        return entry
    }

    // MARK: - 값 문법

    static func isIdentifier(_ value: String) -> Bool {
        guard (1...64).contains(value.count) else { return false }
        guard let first = value.first, first.isASCII, first.isLetter else { return false }
        return value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-")
        }
    }

    static func isToken(_ value: String) -> Bool {
        guard (1...32).contains(value.count) else { return false }
        guard let first = value.first, first.isASCII, first.isLetter, first.isLowercase else {
            return false
        }
        return value.allSatisfy {
            $0.isASCII && (($0.isLetter && $0.isLowercase) || $0.isNumber || $0 == "-")
        }
    }

    static func isInteger(_ value: String) -> Bool {
        guard (1...9).contains(value.count) else { return false }
        if value.count > 1 && value.first == "0" { return false }
        return value.allSatisfy { $0.isASCII && $0.isNumber }
    }

    // MARK: - 라이브러리 오류 번역

    private static func describe(_ error: DirectiveArgumentText.ParseError) -> String {
        switch error {
        case .duplicateArgument(let name, _, _):
            "인자 `\(name)` 이 중복이다"
        case .missingExpectedCharacter(let character, _):
            "`\(character)` 가 있어야 한다 — 인자 사이는 쉼표로 구분하고 값에는 `:` `,` `)` `{` `\"` 를 쓸 수 없다"
        case .unexpectedCharacter(let character, _):
            "예상치 못한 문자 `\(character)`"
        }
    }

    private static func position(
        of error: DirectiveArgumentText.ParseError, fallback: SourcePosition
    ) -> SourcePosition {
        let location: SourceLocation? =
            switch error {
            case .duplicateArgument(_, _, let duplicate): duplicate
            case .missingExpectedCharacter(_, let location): location
            case .unexpectedCharacter(_, let location): location
            }
        return SourcePosition(location) ?? fallback
    }
}

extension SourcePosition {
    /// swift-markdown 의 위치를 우리 타입으로. **여기가 유일한 변환 지점**이다 —
    /// `SourceLocation` 이 이 경계 밖으로 새면 `LessonBlock` 이 Markdown 을 끌고 다니게 된다.
    init?(_ location: SourceLocation?) {
        guard let location else { return nil }
        self.init(line: location.line, column: location.column)
    }

    /// 위치를 못 얻으면 ``SourcePosition/unknown``.
    static func at(_ location: SourceLocation?) -> SourcePosition {
        SourcePosition(location) ?? .unknown
    }
}

extension SourceSpan {
    /// 마크업 노드가 차지한 구간.
    static func span(of markup: any Markup) -> SourceSpan {
        guard let range = markup.range else { return .unknown }
        return SourceSpan(
            start: .at(range.lowerBound), end: .at(range.upperBound))
    }
}
