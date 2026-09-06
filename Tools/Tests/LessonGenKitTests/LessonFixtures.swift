import Foundation
import LearnCore
import LLMKit
import LessonGenKit
import PackReport

/// 레슨 생성 테스트가 공유하는 값들.
enum LessonFixtures {
    /// 문법을 지킨 초안. 여기서 한 필드씩 망가뜨려 거부 경로를 태운다.
    static func draft(
        conceptID: String = "fstring-basics",
        exampleID: String = "fstring-run",
        blankID: String = "fstring-blank",
        taskID: String = "initials",
        quizID: String = "fstring-quiz",
        reflectionID: String = "fstring-reflect"
    ) -> LessonContentDraft {
        LessonContentDraft(
            concept: LessonContentDraft.Concept(
                id: conceptID,
                prose: """
                    파이썬의 f-string 은 문자열 앞에 `f` 를 붙이는 서식 문법이다.

                    중괄호 안에는 임의의 식이 들어간다.
                    """),
            example: LessonContentDraft.Example(
                id: exampleID,
                prose: "아래 코드를 실행해 값이 어떻게 끼워 넣어지는지 확인한다.",
                code: """
                    name = "polyglot"
                    print(f"{name} has 3 tracks")
                    """,
                expectedStdout: "polyglot has 3 tracks\n"),
            blank: LessonContentDraft.Blank(
                id: blankID,
                prose: "두 칸을 채워라.",
                template: """
                    values = [1, 2, 3]
                    total = ___1___(values)
                    print(f"total={___2___}")
                    """,
                answers: [
                    LessonContentDraft.Blank.Answer(slot: 1, text: "sum"),
                    LessonContentDraft.Blank.Answer(slot: 2, text: "total"),
                ]),
            task: LessonContentDraft.Task(
                id: taskID,
                prose: "이니셜을 돌려주는 `initials(full_name)` 를 완성해라.",
                starterCode: """
                    def initials(full_name):
                        raise NotImplementedError
                    """,
                testsCode: """
                    import unittest

                    from solution import initials


                    class InitialsTests(unittest.TestCase):
                        def test_two_words(self):
                            self.assertEqual(initials("ada lovelace"), "AL")
                    """,
                solutionCode: """
                    def initials(full_name):
                        return "".join(word[0].upper() for word in full_name.split())
                    """,
                hints: ["`str.split()` 은 연속된 공백을 하나로 묶는다."]),
            quiz: LessonContentDraft.Quiz(
                id: quizID,
                question: "f-string 의 `!r` 은 무엇을 하는가?",
                choices: [
                    LessonContentDraft.Quiz.Choice(
                        id: "repr-conversion", prose: "값을 `repr()` 로 변환해 넣는다."),
                    LessonContentDraft.Quiz.Choice(id: "rounding", prose: "소수점을 반올림한다."),
                    LessonContentDraft.Quiz.Choice(id: "raw-string", prose: "raw 문자열로 만든다."),
                ],
                answerChoiceID: "repr-conversion",
                explanation: "`f\"{value!r}\"` 은 `repr(value)` 의 결과를 넣는다."),
            reflection: LessonContentDraft.Reflection(
                id: reflectionID,
                prompts: [
                    LessonContentDraft.Reflection.Prompt(
                        id: "readability", prose: "`%` 서식과 비교해 어느 쪽이 잘 읽히는지 판단해라."),
                    LessonContentDraft.Reflection.Prompt(
                        id: "injection", prose: "사용자 입력을 그대로 넣으면 왜 위험한가?"),
                ]))
    }

    static func outline(
        slug: String = "fstring",
        ordinal: Int = 1,
        prerequisites: [LessonID] = []
    ) -> LessonOutline {
        LessonOutline(
            stableID: LessonID("python.\(slug)"),
            ordinal: ordinal,
            title: "f-string 으로 문자열 만들기",
            summary: "값을 문자열에 끼워 넣는다.",
            objectives: ["f-string 으로 값을 끼워 넣을 수 있다.", "서식 세 가지를 구분할 수 있다."],
            prerequisites: prerequisites,
            concepts: ["f-string", "format"],
            estimatedMinutes: 20)
    }

    static func track(lessonCount: Int = 1) -> TrackOutline {
        var lessons: [LessonOutline] = []
        for index in 1...lessonCount {
            lessons.append(
                outline(
                    slug: "lesson-\(index)",
                    ordinal: index,
                    prerequisites: index > 1 ? [LessonID("python.lesson-\(index - 1)")] : []))
        }
        return TrackOutline(
            language: .python,
            trackTitle: "파이썬 입문",
            trackSummary: "표준 라이브러리만으로 실행 가능한 프로그램을 쓴다.",
            generatorModel: "test-vendor/test-model",
            lessons: lessons)
    }

    static func draftJSON(_ draft: LessonContentDraft = LessonFixtures.draft()) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try! encoder.encode(draft), as: UTF8.self)
    }

    static func response(
        text: String,
        model: String = "z-ai/glm-5.3-flash",
        upstream: String = "TestUpstream",
        cachedTokens: Int? = nil,
        cost: Double? = 0.0001
    ) -> CompletionResponse {
        CompletionResponse(
            id: "gen-TEST",
            model: model,
            upstreamProvider: upstream,
            text: text,
            finishReason: .stop,
            usage: TokenUsage(
                inputTokens: 1000,
                outputTokens: 500,
                cachedInputTokens: cachedTokens,
                costUSD: cost))
    }

    /// 임시 디렉터리 하나. 테스트가 끝나면 지운다.
    static func temporaryDirectory(_ name: String = "lessongen-test") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func runLog(
        directory: URL,
        budgetUSD: Double? = nil,
        sessionID: String? = "test-session",
        pinnedProviders: [String] = []
    ) throws -> RunLog {
        try RunLog(
            rootDirectory: directory,
            runID: "testrun",
            command: "test",
            startedAt: Date(timeIntervalSince1970: 1_787_752_741),
            models: ModelSelection(base: ModelID("z-ai/glm-5.3-flash")),
            sessionID: sessionID,
            budgetUSD: budgetUSD,
            pinnedProviders: pinnedProviders)
    }

    /// 실패 하나짜리 검증 리포트.
    static func report(
        packID: String = "polyglot-mvp",
        stableID: String = "python-fstring",
        kind: PackValidationReport.Failure.Kind = .starterAlreadyPasses,
        evidence: String = "Ran 3 tests in 0.001s\n\nOK"
    ) -> PackValidationReport {
        PackValidationReport(
            packID: packID,
            packVersion: "0.1.0",
            validatedAt: 1_787_752_741_000,
            stagesRun: [.structural, .syntax, .semantic, .execution],
            lessons: [
                PackValidationReport.LessonResult(
                    stableID: stableID,
                    language: "python",
                    title: "f-string 으로 문자열 만들기",
                    failures: [
                        PackValidationReport.Failure(
                            stage: .execution,
                            kind: kind,
                            blockID: "initials",
                            summary: "starter 가 숨은 테스트를 통과했습니다.",
                            evidence: evidence)
                    ])
            ])
    }
}
