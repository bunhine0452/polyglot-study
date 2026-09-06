/// 직렬화가 거부한 이유.
///
/// 두 얼굴을 갖는다. ``description`` 은 사람이 읽는 한 줄이고, ``promptFeedback`` 은
/// **모델에게 그대로 되돌려 보내는 지시문**이다. 둘을 나눈 이유는 사람에게 유용한 문장과
/// 모델을 고치게 하는 문장이 다르기 때문이다 — 사람에게는 "왜 거부됐나" 가, 모델에게는
/// "다음에 무엇을 다르게 하라" 가 필요하다.
public enum LessonSerializationError: Error, Hashable, Sendable, CustomStringConvertible {
    case emptyBody(context: String)
    case emptyCode(context: String)
    /// 산문에 홀로 선 `}` 가 있다 — 디렉티브가 거기서 닫힌다.
    case proseClosesDirective(context: String, line: Int)
    /// 산문의 한 줄이 `@` + 대문자로 시작한다 — 파서가 디렉티브로 읽는다.
    case proseLooksLikeDirective(context: String, line: Int, text: String)
    /// 코드펜스가 있어서는 안 되는 산문에 있다.
    case codeFenceInProse(context: String, line: Int)
    case unclosedCodeFence(context: String)
    /// `@Answer` 본문은 한 줄이어야 한다.
    case multilineAnswer(context: String, text: String)
    /// 빈칸 표식과 정답 슬롯이 어긋난다.
    case blankSlotMismatch(markers: [Int], answers: [Int])
    case tooFewChoices(count: Int)
    case duplicateChoiceID(String)
    case answerNotAChoice(answer: String, choices: [String])
    case tooFewPrompts
    case duplicatePromptID(String)
    case duplicateBlockID(String)
    /// 구운 마크다운을 다시 파싱했더니 실패했다. **여기 오면 직렬화기의 버그다.**
    case unparsableOutput(String)
    /// 파싱은 됐는데 값이 달라졌다. 조용한 손실을 잡는 마지막 그물.
    case roundTripMismatch(field: String, expected: String, found: String)

    public var description: String {
        switch self {
        case .emptyBody(let context):
            "\(context): 본문이 비어 있습니다."
        case .emptyCode(let context):
            "\(context): 코드가 비어 있습니다."
        case .proseClosesDirective(let context, let line):
            "\(context) \(line)번째 줄이 `}` 로 시작합니다 — 디렉티브가 그 자리에서 닫힙니다."
        case .proseLooksLikeDirective(let context, let line, let text):
            "\(context) \(line)번째 줄이 디렉티브로 읽힙니다: \(text)"
        case .codeFenceInProse(let context, let line):
            "\(context) \(line)번째 줄에 코드펜스가 있습니다 — 이 자리의 코드는 별도 필드입니다."
        case .unclosedCodeFence(let context):
            "\(context): 닫히지 않은 코드펜스가 있습니다."
        case .multilineAnswer(let context, let text):
            "\(context): 정답이 여러 줄입니다: \(text.prefix(40))"
        case .blankSlotMismatch(let markers, let answers):
            "빈칸 표식 \(markers) 와 정답 슬롯 \(answers) 가 1..n 으로 맞지 않습니다."
        case .tooFewChoices(let count):
            "퀴즈 선택지가 \(count)개입니다 — 2개 이상이어야 합니다."
        case .duplicateChoiceID(let id):
            "퀴즈 선택지 id 가 중복됩니다: \(id)"
        case .answerNotAChoice(let answer, let choices):
            "퀴즈 정답 '\(answer)' 가 선택지에 없습니다: \(choices.joined(separator: ", "))"
        case .tooFewPrompts:
            "회고 질문이 하나도 없습니다."
        case .duplicatePromptID(let id):
            "회고 질문 id 가 중복됩니다: \(id)"
        case .duplicateBlockID(let id):
            "블록 id 가 중복됩니다: \(id) — 레슨 안에서 유일해야 합니다."
        case .unparsableOutput(let detail):
            "직렬화 결과를 다시 파싱하지 못했습니다 — \(detail)"
        case .roundTripMismatch(let field, let expected, let found):
            "왕복 검사 불일치 \(field): 기대 '\(expected)' / 실제 '\(found)'"
        }
    }

    /// 모델에게 되돌려 보낼 지시문. **무엇을 하지 말라가 아니라 무엇을 하라**로 쓴다.
    public var promptFeedback: String {
        switch self {
        case .emptyBody(let context):
            "\(context) 가 비어 있었다. 내용을 채워라."
        case .emptyCode(let context):
            "\(context) 의 코드가 비어 있었다. 실제로 동작하는 코드를 써라."
        case .proseClosesDirective(let context, _):
            "\(context) 의 어떤 줄이 `}` 로 시작했다. 산문은 `}` 로 시작하는 줄을 가질 수 없다 — 그 줄을 다시 써라."
        case .proseLooksLikeDirective(let context, _, let text):
            "\(context) 의 어떤 줄이 `@` 와 대문자로 시작했다(`\(text)`). 산문에서 `@` 로 시작하는 줄을 쓰지 마라."
        case .codeFenceInProse(let context, _):
            "\(context) 에 코드펜스를 넣었다. 이 자리의 코드는 별도 필드로 보내야 하고 산문에는 코드펜스를 넣지 않는다."
        case .unclosedCodeFence(let context):
            "\(context) 의 코드펜스가 닫히지 않았다. 여는 백틱과 닫는 백틱 개수를 맞춰라."
        case .multilineAnswer(let context, _):
            "\(context) 의 정답이 여러 줄이었다. 빈칸 정답은 한 줄 조각이어야 한다."
        case .blankSlotMismatch(let markers, let answers):
            """
            빈칸 표식과 정답이 맞지 않았다 — 코드 표식 \(markers), 정답 슬롯 \(answers). \
            template 에 `___1___` 부터 번호를 빠짐없이 이어 붙이고 answers 의 slot 을 그 번호와 일치시켜라.
            """
        case .tooFewChoices:
            "퀴즈 선택지가 모자랐다. 서로 다른 선택지를 3개 이상 만들어라."
        case .duplicateChoiceID(let id):
            "퀴즈 선택지 id `\(id)` 가 중복됐다. 선택지마다 내용을 드러내는 서로 다른 id 를 줘라."
        case .answerNotAChoice(let answer, let choices):
            "answerChoiceID 로 `\(answer)` 를 줬는데 선택지 id 는 \(choices.joined(separator: ", ")) 였다. 정답 id 를 선택지 중 하나와 정확히 일치시켜라."
        case .tooFewPrompts:
            "회고 질문이 없었다. 채점하지 않는 열린 질문을 2개 만들어라."
        case .duplicatePromptID(let id):
            "회고 질문 id `\(id)` 가 중복됐다. 서로 다른 id 를 줘라."
        case .duplicateBlockID(let id):
            "블록 id `\(id)` 가 중복됐다. 여섯 블록의 id 는 서로 달라야 한다."
        case .unparsableOutput(let detail), .roundTripMismatch(field: let detail, _, _):
            "생성물이 레슨 문법 검사를 통과하지 못했다(\(detail)). 같은 내용을 더 단순한 구조로 다시 써라."
        }
    }
}
