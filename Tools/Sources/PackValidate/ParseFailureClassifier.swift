internal import ContentKit
internal import PackReport

/// `LessonParseError` 를 리포트 계약의 (단계, 종류) 로 옮긴다.
///
/// 파서는 문법과 의미를 한 번에 본다 — `@Quiz` 의 정답 키가 선택지에 없으면 파싱
/// 단계에서 던진다. 하지만 `lessongen repair` 가 프롬프트를 고르는 기준은 "어느 코드가
/// 던졌는가" 가 아니라 **모델이 무엇을 고쳐야 하는가**다. 정답 키 불일치는 문법이 아니라
/// 내용의 문제이므로 `.semantic` / `.inconsistentAnswer` 로 접는다.
enum ParseFailureClassifier {
    static func classify(
        _ error: LessonParseError
    ) -> (stage: PackValidationReport.Stage, kind: PackValidationReport.Failure.Kind) {
        switch error.reason {
        // 블록 구성·순서. 언어 변형의 짝이 안 맞는 것도 여기다 — 어느 언어에 어떤 블록이
        // 빠졌는가는 구조의 문제이지 내용의 문제가 아니다({#block-language-variants}).
        case .blockOutOfOrder, .missingBlock, .duplicateBlock, .duplicateBlockID,
            .unexpectedTopLevelContent, .duplicateLanguage, .languageWithoutBlock,
            .manifestLanguageMismatch:
            (.syntax, .blockStructure)

        // 디렉티브가 가리키는 사이드카 경로가 어긋났다 — 문법이 아니라 참조의 문제다.
        case .pathOutsideDirectory, .unsafeArgumentPath:
            (.syntax, .brokenReference)

        // 퀴즈·빈칸의 내용 정합성. 모델이 고쳐야 하는 것은 문법이 아니라 답이다.
        case .blankSlotMismatch, .duplicateAnswerSlot, .emptyAnswer, .tooFewChoices,
            .duplicateChoiceID, .answerNotAChoice, .tooFewPrompts, .duplicatePromptID:
            (.semantic, .inconsistentAnswer)

        // 나머지는 전부 문법이다.
        case .unknownDirective, .headerNotSingleLine, .singleLineBody,
            .trailingTextAfterDirective, .closingBraceNotAlone, .missingArgument,
            .unknownArgument, .duplicateArgument, .positionalArgument, .invalidArgumentValue,
            .unknownArgumentToken, .argumentSyntax, .emptyBody, .missingProse,
            .missingChildDirective, .unexpectedChildDirective, .missingCodeBlock,
            .multipleCodeBlocks:
            (.syntax, .malformedDirective)
        }
    }

    /// 파싱 에러 하나를 리포트 실패 하나로. 위치는 항상 `line:column` 으로 실린다.
    static func failure(from error: LessonParseError) -> PackValidationReport.Failure {
        let (stage, kind) = classify(error)
        return PackValidationReport.Failure(
            stage: stage,
            kind: kind,
            summary: "\(error.reason)",
            // 파서에게 러너 원문에 해당하는 것은 경로 접두사가 붙은 완전한 진단이다.
            evidence: error.description,
            line: error.position.isKnown ? error.position.line : nil,
            column: error.position.isKnown ? error.position.column : nil
        )
    }
}
