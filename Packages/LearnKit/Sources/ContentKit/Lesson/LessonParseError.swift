/// 레슨 파싱이 실패한 이유 하나. **항상 `line:column` 을 들고 있다.**
///
/// swift-markdown 은 잘못된 디렉티브를 대부분 조용히 삼킨다 — 중괄호 없는 디렉티브
/// 뒤 텍스트는 버려지고, 인자에 못 쓰는 문자는 값을 잘라먹는다. 조용한 실패는
/// 생성 파이프라인에서 최악이므로, 파서는 의심스러운 모든 것을 위치와 함께 거부한다.
public struct LessonParseError: Error, Hashable, Sendable, CustomStringConvertible {
    public var reason: Reason
    public var position: SourcePosition
    /// 팩 상대 경로. 메시지 접두사로 쓰인다.
    public var path: String?

    public init(_ reason: Reason, at position: SourcePosition, path: String? = nil) {
        self.reason = reason
        self.position = position
        self.path = path
    }

    /// 경로를 채워 넣은 사본. 파일 단위 로더가 마지막에 붙인다.
    public func annotated(path: String) -> LessonParseError {
        LessonParseError(reason, at: position, path: self.path ?? path)
    }

    public var description: String {
        let prefix = path.map { "\($0):" } ?? ""
        return "\(prefix)\(position): \(reason)"
    }

    public enum Reason: Hashable, Sendable, CustomStringConvertible {
        // MARK: 문서 구조
        /// 스펙에 없는 디렉티브.
        case unknownDirective(String)
        /// 최상위에 디렉티브가 아닌 것이 있다.
        case unexpectedTopLevelContent(String)
        /// 블록 순서가 어긋났다.
        case blockOutOfOrder(found: LessonBlockKind, expected: LessonBlockKind)
        /// 필수 블록이 없다.
        case missingBlock(LessonBlockKind)
        /// 같은 블록이 두 번.
        case duplicateBlock(LessonBlockKind)
        /// 블록 id 가 레슨 안에서 중복.
        case duplicateBlockID(String)

        // MARK: 소스 문법 (렉시컬 사전 검사)
        /// 디렉티브 헤더가 한 줄에 끝나지 않는다.
        case headerNotSingleLine(directive: String)
        /// 한 줄 중괄호 본문. `@X { y }` 는 마지막 중괄호까지 삼키므로 금지한다.
        case singleLineBody(directive: String)
        /// 중괄호 없는 디렉티브 뒤 같은 줄의 텍스트. 파서가 조용히 버린다.
        case trailingTextAfterDirective(directive: String, text: String)
        /// 닫는 중괄호가 한 줄을 독차지하지 않는다.
        case closingBraceNotAlone(String)

        // MARK: 인자
        case missingArgument(directive: String, argument: String)
        case unknownArgument(directive: String, argument: String)
        case duplicateArgument(directive: String, argument: String)
        /// 이름 없는 인자. 라이브러리는 첫 인자에 한해 허용하지만 스펙은 금지한다.
        case positionalArgument(directive: String)
        /// 값이 허용 문자 집합·형태를 벗어났다.
        case invalidArgumentValue(
            directive: String, argument: String, value: String, expected: DirectiveValueKind)
        /// 열거 토큰이 허용 목록에 없다.
        case unknownArgumentToken(
            directive: String, argument: String, value: String, allowed: [String])
        /// 경로 인자가 요구된 디렉터리 밖을 가리킨다.
        case pathOutsideDirectory(
            directive: String, argument: String, value: String, expected: String)
        case unsafeArgumentPath(
            directive: String, argument: String, value: String, reason: PackPathError)
        /// swift-markdown 의 인자 렉서가 낸 오류.
        case argumentSyntax(directive: String, detail: String)

        // MARK: 본문
        case emptyBody(directive: String)
        case missingProse(directive: String)
        case missingChildDirective(parent: String, child: String)
        case unexpectedChildDirective(parent: String, child: String)
        case missingCodeBlock(directive: String)
        case multipleCodeBlocks(directive: String)
        /// 빈칸 표식과 `@Answer` 슬롯이 일치하지 않는다.
        case blankSlotMismatch(directive: String, markers: [Int], answers: [Int])
        case duplicateAnswerSlot(directive: String, slot: Int)
        case emptyAnswer(directive: String, slot: Int)
        case tooFewChoices(directive: String, count: Int)
        case duplicateChoiceID(directive: String, choice: String)
        /// 정답 키가 선택지에 없다.
        case answerNotAChoice(directive: String, answer: String, choices: [String])
        case tooFewPrompts(directive: String)
        case duplicatePromptID(directive: String, prompt: String)

        public var description: String {
            switch self {
            case .unknownDirective(let name):
                "스펙에 없는 디렉티브 `@\(name)`"
            case .unexpectedTopLevelContent(let kind):
                "레슨 최상위에는 6블록 디렉티브만 올 수 있다 (\(kind) 발견)"
            case .blockOutOfOrder(let found, let expected):
                "블록 순서가 어긋났다 — \(expected.directiveName) 자리에 \(found.directiveName)"
            case .missingBlock(let kind):
                "필수 블록 `@\(kind.directiveName)` 가 없다"
            case .duplicateBlock(let kind):
                "블록 `@\(kind.directiveName)` 가 두 번 나온다"
            case .duplicateBlockID(let id):
                "블록 id `\(id)` 가 레슨 안에서 중복이다"
            case .headerNotSingleLine(let directive):
                "`@\(directive)` 의 인자 목록은 한 줄에 끝나야 한다 — 닫는 `)` 가 같은 줄에 없다"
            case .singleLineBody(let directive):
                """
                `@\(directive)` 의 중괄호 본문은 여러 줄이어야 한다 — 한 줄 본문 \
                `@\(directive) { … }` 은 줄 끝의 `}` 까지 본문으로 삼켜 조용히 망가진다
                """
            case .trailingTextAfterDirective(let directive, let text):
                """
                `@\(directive)` 뒤 같은 줄의 텍스트는 파서가 조용히 버린다: `\(text)` — \
                본문이면 `{` 로 열고 다음 줄에 써라
                """
            case .closingBraceNotAlone(let line):
                "닫는 `}` 는 한 줄을 독차지해야 한다: `\(line)`"
            case .missingArgument(let directive, let argument):
                "`@\(directive)` 에 필수 인자 `\(argument)` 가 없다"
            case .unknownArgument(let directive, let argument):
                "`@\(directive)` 가 모르는 인자 `\(argument)`"
            case .duplicateArgument(let directive, let argument):
                "`@\(directive)` 의 인자 `\(argument)` 가 중복이다"
            case .positionalArgument(let directive):
                "`@\(directive)` 에 이름 없는 인자가 있다 — 모든 인자는 `이름: 값` 이어야 한다"
            case .invalidArgumentValue(let directive, let argument, let value, let expected):
                """
                `@\(directive)` 의 `\(argument)` 값이 \(expected.humanDescription) 가 아니다: \
                `\(value)`
                """
            case .unknownArgumentToken(let directive, let argument, let value, let allowed):
                """
                `@\(directive)` 의 `\(argument)` 값 `\(value)` 는 허용 토큰이 아니다 \
                (\(allowed.joined(separator: " | ")))
                """
            case .pathOutsideDirectory(let directive, let argument, let value, let expected):
                "`@\(directive)` 의 `\(argument)` 는 `\(expected)/` 아래여야 한다: `\(value)`"
            case .unsafeArgumentPath(let directive, let argument, let value, let reason):
                "`@\(directive)` 의 `\(argument)` 경로가 안전하지 않다 (`\(value)`): \(reason)"
            case .argumentSyntax(let directive, let detail):
                "`@\(directive)` 의 인자 문법 오류: \(detail)"
            case .emptyBody(let directive):
                "`@\(directive)` 의 본문이 비어 있다"
            case .missingProse(let directive):
                "`@\(directive)` 에 설명 문단이 없다"
            case .missingChildDirective(let parent, let child):
                "`@\(parent)` 안에 `@\(child)` 가 없다"
            case .unexpectedChildDirective(let parent, let child):
                "`@\(parent)` 안에 올 수 없는 `@\(child)`"
            case .missingCodeBlock(let directive):
                "`@\(directive)` 에 펜스 코드 블록이 없다"
            case .multipleCodeBlocks(let directive):
                "`@\(directive)` 에 펜스 코드 블록이 둘 이상이다 — 하나만 둬라"
            case .blankSlotMismatch(let directive, let markers, let answers):
                """
                `@\(directive)` 의 빈칸 표식과 정답이 맞지 않는다 — \
                표식 \(markers.map(String.init).joined(separator: ",")), \
                정답 \(answers.map(String.init).joined(separator: ","))
                """
            case .duplicateAnswerSlot(let directive, let slot):
                "`@\(directive)` 의 `@Answer(slot: \(slot))` 가 중복이다"
            case .emptyAnswer(let directive, let slot):
                "`@\(directive)` 의 `@Answer(slot: \(slot))` 본문이 비어 있다"
            case .tooFewChoices(let directive, let count):
                "`@\(directive)` 의 선택지가 \(count)개다 — 2개 이상이어야 한다"
            case .duplicateChoiceID(let directive, let choice):
                "`@\(directive)` 의 선택지 id `\(choice)` 가 중복이다"
            case .answerNotAChoice(let directive, let answer, let choices):
                """
                `@\(directive)` 의 정답 `\(answer)` 가 선택지에 없다 \
                (\(choices.joined(separator: " | ")))
                """
            case .tooFewPrompts(let directive):
                "`@\(directive)` 에 `@Prompt` 가 하나도 없다"
            case .duplicatePromptID(let directive, let prompt):
                "`@\(directive)` 의 `@Prompt` id `\(prompt)` 가 중복이다"
            }
        }
    }
}

/// 디렉티브 인자 값이 가질 수 있는 형태. **자유 텍스트는 없다.**
///
/// swift-markdown 의 인자 렉서는 값에서 `:` `,` `)` `{` `공백` 을 만나면 거기서 끊고,
/// 따옴표를 씌워도 마찬가지다(따옴표 안의 콜론은 살지만 값에 따옴표를 못 쓰는 것은 같다).
/// 역슬래시는 언이스케이프되지 않고 값에 그대로 남는다. 그래서 인자는 처음부터
/// 식별자·열거 토큰·경로·정수 넷으로 못박고, 자유 텍스트는 전부 본문이나 사이드카로 보낸다.
public enum DirectiveValueKind: String, Hashable, Sendable {
    /// `[A-Za-z][A-Za-z0-9_-]*`, 64자 이하.
    case identifier
    /// 소문자 열거 토큰. `[a-z][a-z0-9-]*`, 32자 이하.
    case token
    /// 팩 상대 경로.
    case path
    /// 부호 없는 10진 정수.
    case integer

    public var humanDescription: String {
        switch self {
        case .identifier: "식별자(영문자로 시작, 영숫자·`_`·`-`)"
        case .token: "열거 토큰(소문자·숫자·`-`)"
        case .path: "팩 상대 경로"
        case .integer: "정수"
        }
    }
}
