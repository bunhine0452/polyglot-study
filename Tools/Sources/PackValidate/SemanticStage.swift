internal import ContentKit
internal import LearnCore
internal import PackReport

/// 의미 단계 — 퀴즈 정답 키와 빈칸 정답이 스스로 앞뒤가 맞는가.
///
/// **파서가 이미 같은 것을 본다.** 그런데도 여기서 다시 보는 이유는 게이트의 성격
/// 때문이다. 파서는 첫 위반에서 던지므로 레슨 하나에 문제가 둘이면 하나만 보인다.
/// 더 중요한 것은 의존 방향이다 — 이 게이트가 보장하는 "정답 키가 실제 선택지에 있다"
/// 가 파서 구현의 부수 효과라면, 파서가 느슨해지는 날 게이트는 아무 말 없이 함께
/// 느슨해진다. 그래서 파싱을 통과한 **값**에 대고 독립적으로 다시 단언한다.
///
/// 모든 실패는 `line:column` 을 들고 나간다.
enum SemanticStage {
    static func run(_ lessons: [ParsedLesson], into table: inout FailureTable) {
        for lesson in lessons {
            let id = lesson.entry.stableID.rawValue
            for failure in failures(in: lesson.document) {
                table.add(failure, to: id)
            }
        }
    }

    static func failures(in document: LessonDocument) -> [PackValidationReport.Failure] {
        var found: [PackValidationReport.Failure] = []
        for block in document.blocks {
            switch block {
            case .quiz(let quiz): found += quizFailures(quiz)
            case .blank(let blank): found += blankFailures(blank)
            case .reflection(let reflection): found += reflectionFailures(reflection)
            case .concept, .example, .task: continue
            }
        }
        return found
    }

    // MARK: - 퀴즈

    private static func quizFailures(_ quiz: QuizBlock) -> [PackValidationReport.Failure] {
        var found: [PackValidationReport.Failure] = []

        if quiz.choices.count < 2 {
            found.append(
                failure(
                    block: quiz.id, at: quiz.span.start,
                    summary: "@Quiz 의 선택지가 \(quiz.choices.count)개다 — 2개 이상이어야 한다",
                    evidence: "선택지: \(quiz.choices.map(\.id).joined(separator: " | "))"))
        }
        if quiz.answer == nil {
            found.append(
                failure(
                    block: quiz.id, at: quiz.span.start,
                    summary: "@Quiz 의 정답 키 `\(quiz.answerID)` 가 선택지에 없다",
                    evidence: "선택지: \(quiz.choices.map(\.id).joined(separator: " | "))"))
        }
        var seen: Set<String> = []
        for choice in quiz.choices {
            if !seen.insert(choice.id).inserted {
                found.append(
                    failure(
                        block: quiz.id, at: choice.span.start,
                        summary: "@Quiz 의 선택지 id `\(choice.id)` 가 중복이다",
                        evidence: nil))
            }
            if isBlank(choice.prose) {
                found.append(
                    failure(
                        block: quiz.id, at: choice.span.start,
                        summary: "@Choice(id: \(choice.id)) 의 본문이 비어 있다",
                        evidence: nil))
            }
        }
        if isBlank(quiz.question) {
            found.append(
                failure(
                    block: quiz.id, at: quiz.span.start,
                    summary: "@Quiz 의 @Question 본문이 비어 있다", evidence: nil))
        }
        return found
    }

    // MARK: - 빈칸

    private static func blankFailures(_ blank: BlankBlock) -> [PackValidationReport.Failure] {
        var found: [PackValidationReport.Failure] = []

        for slot in blank.slots where isBlank(slot.answer) {
            found.append(
                failure(
                    block: blank.id, at: slot.span.start,
                    summary: "@Answer(slot: \(slot.index)) 의 본문이 비어 있다", evidence: nil))
        }

        // 표식과 정답 슬롯이 1..n 을 정확히 덮는가. 하나라도 어긋나면 학습자가 채울 수
        // 없는(또는 채워도 남는) 빈칸이 화면에 나온다.
        let markers = Set(BlankSlotMarker.indices(in: blank.template))
        let answered = Set(blank.slots.map(\.index))
        if markers != answered || answered != Set(1...max(1, answered.count)) {
            found.append(
                failure(
                    block: blank.id, at: blank.span.start,
                    summary: "@Blank 의 표식과 @Answer 슬롯이 1..n 을 덮지 않는다",
                    evidence: """
                        표식 \(markers.sorted().map(String.init).joined(separator: ","))
                        정답 \(answered.sorted().map(String.init).joined(separator: ","))
                        """))
        }
        return found
    }

    // MARK: - 회고

    private static func reflectionFailures(
        _ reflection: ReflectionBlock
    ) -> [PackValidationReport.Failure] {
        var found: [PackValidationReport.Failure] = []
        if reflection.prompts.isEmpty {
            found.append(
                failure(
                    block: reflection.id, at: reflection.span.start,
                    summary: "@Reflection 에 @Prompt 가 하나도 없다", evidence: nil))
        }
        for prompt in reflection.prompts where isBlank(prompt.prose) {
            found.append(
                failure(
                    block: reflection.id, at: prompt.span.start,
                    summary: "@Prompt(id: \(prompt.id)) 의 본문이 비어 있다", evidence: nil))
        }
        return found
    }

    // MARK: - 조립

    private static func failure(
        block: String, at position: SourcePosition, summary: String, evidence: String?
    ) -> PackValidationReport.Failure {
        PackValidationReport.Failure(
            stage: .semantic,
            kind: .inconsistentAnswer,
            blockID: block,
            summary: summary,
            evidence: evidence,
            line: position.isKnown ? position.line : nil,
            column: position.isKnown ? position.column : nil
        )
    }

    private static func isBlank(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }
}
