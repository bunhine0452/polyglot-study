public import ContentKit
import Foundation
public import LearnCore

/// 디스크의 레슨을 ``LessonContentDraft`` 로 되읽는다.
///
/// 수리는 "처음부터 다시 쓰기" 가 아니라 "고치기" 다. 그러려면 모델에게 **지금 무엇이
/// 있는지** 를 보여 줘야 하고, 그 형태는 처음에 준 것과 같은 스키마여야 한다 — 다른
/// 모양으로 보여 주고 같은 모양으로 받겠다는 것은 모델에게 번역을 시키는 일이다.
///
/// 마크다운을 다시 파싱해서 만든다는 점이 중요하다. 초안을 따로 저장해 두면 팩과
/// 초안이 어긋날 수 있고(사람이 레슨을 손으로 고칠 수 있다), 그러면 수리가 사람의
/// 수정을 조용히 되돌린다.
public enum LessonDraftReader {
    public struct ReadLesson: Sendable {
        public var draft: LessonContentDraft
        /// 매니페스트에서 되살린 개요 칸. ``LessonAssembler`` 가 제목·순번·학습목표·선수
        /// 레슨만 읽으므로 그 넷만 진짜 값이다 — 나머지는 자리를 채운 것이고 프롬프트로
        /// 나가지 않는다.
        public var outline: LessonOutline
        public var language: LessonLanguage

        public init(draft: LessonContentDraft, outline: LessonOutline, language: LessonLanguage) {
            self.draft = draft
            self.outline = outline
            self.language = language
        }
    }

    public static func read(_ stableID: LessonID, from pack: ContentPack) throws -> ReadLesson {
        guard let entry = pack.manifest.lesson(stableID) else {
            throw LessonDraftReadError.unknownLesson(stableID.rawValue)
        }
        guard let language = LessonLanguage(entry.language) else {
            throw LessonDraftReadError.unsupportedLanguage(entry.language.rawValue)
        }
        let document = try pack.lesson(stableID)
        guard let concept = document.concept,
            let example = document.example,
            let blank = document.blank,
            let task = document.task,
            let quiz = document.quiz,
            let reflection = document.reflection
        else {
            throw LessonDraftReadError.incompleteLesson(stableID.rawValue)
        }

        let draft = LessonContentDraft(
            concept: LessonContentDraft.Concept(id: concept.id, prose: concept.prose),
            example: LessonContentDraft.Example(
                id: example.id,
                prose: example.prose,
                code: example.code,
                expectedStdout: try pack.text(at: example.expectedStdoutPath)),
            blank: LessonContentDraft.Blank(
                id: blank.id,
                prose: blank.prose,
                template: blank.template,
                answers: blank.slots.map {
                    LessonContentDraft.Blank.Answer(slot: $0.index, text: $0.answer)
                }),
            task: LessonContentDraft.Task(
                id: task.id,
                prose: task.prose,
                starterCode: try pack.text(at: task.starterPath),
                testsCode: try pack.text(at: task.testsPath),
                solutionCode: try pack.text(at: task.solutionPath),
                hints: task.hints.map(\.prose)),
            quiz: LessonContentDraft.Quiz(
                id: quiz.id,
                question: quiz.question,
                choices: quiz.choices.map {
                    LessonContentDraft.Quiz.Choice(id: $0.id, prose: $0.prose)
                },
                answerChoiceID: quiz.answerID,
                explanation: quiz.explanation ?? ""),
            reflection: LessonContentDraft.Reflection(
                id: reflection.id,
                prompts: reflection.prompts.map {
                    LessonContentDraft.Reflection.Prompt(id: $0.id, prose: $0.prose)
                }))

        return ReadLesson(
            draft: draft,
            outline: LessonOutline(
                stableID: entry.stableID,
                ordinal: entry.order,
                title: entry.title,
                summary: entry.title,
                objectives: entry.objectives,
                prerequisites: entry.prerequisites,
                concepts: [],
                estimatedMinutes: 20),
            language: language)
    }

    /// 초안을 프롬프트에 실을 JSON 으로. 사람이 읽을 수 있게 들여쓰기를 준다.
    public static func json(_ draft: LessonContentDraft) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(draft), as: UTF8.self)
    }
}

public enum LessonDraftReadError: Error, Hashable, Sendable, CustomStringConvertible {
    case unknownLesson(String)
    case unsupportedLanguage(String)
    case incompleteLesson(String)

    public var description: String {
        switch self {
        case .unknownLesson(let id): "매니페스트에 없는 레슨입니다: \(id)"
        case .unsupportedLanguage(let language): "레슨 생성이 모르는 언어입니다: \(language)"
        case .incompleteLesson(let id): "여섯 블록이 다 있지 않습니다: \(id)"
        }
    }
}
