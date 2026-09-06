public import PackReport

/// 수리 프롬프트.
///
/// ## 실패 종류마다 지시가 다르다
///
/// `Failure.Kind` 로 프롬프트를 가르는 것이 `{#lessongen-repair}` 의 요점이다. 가장
/// 분명한 예가 ``PackValidationReport/Failure/Kind/starterAlreadyPasses`` 다 —
/// "테스트가 통과하지 못했다" 와 정반대의 실패인데, 뭉뚱그려 "과제를 고쳐라" 로 보내면
/// 모델은 **과제를 더 어렵게** 만든다. 그건 고친 게 아니다. 필요한 지시는 "정답을
/// starter 에서 걷어 내라" 하나뿐이고, 테스트와 solution 은 손대면 안 된다.
///
/// ## 증거는 요약하지 않는다
///
/// `Failure.evidence` 는 러너가 실제로 뱉은 것이다. 컴파일러 진단의 줄 번호와 캐럿,
/// 테스트 러너의 기대/실제 값이 거기 있고, 그게 모델이 고칠 수 있는 유일한 재료다.
/// 요약하면 그 재료가 사라진다.
public enum RepairPrompt {
    /// 시스템 프롬프트 두 번째 조각. 첫 조각은 ``LessonPrompt/system`` 그대로다 —
    /// 접두사가 같아야 생성 단계에서 데워진 캐시를 수리가 이어 쓴다.
    public static let systemSuffix = """
        지금은 **수리** 작업이다. 이미 만들어진 레슨이 검증에서 떨어졌고, 러너가 뱉은 원문이
        함께 주어진다.

        - 실패한 부분만 고쳐라. 지적되지 않은 필드는 이전 값을 **그대로** 다시 내놔라.
        - 블록 id·선택지 id 를 바꾸지 마라. 학습 진도와 리포트가 그 id 로 매달려 있다.
        - 증거에 적힌 사실을 부정하지 마라. 러너가 그렇게 말했으면 그런 것이다.
        - 출력은 처음과 같은 JSON 스키마 전문이다. 일부만 보내지 마라.
        """

    /// 사용자 메시지. 현재 초안 + 실패 목록 + 러너 원문.
    public static func user(
        lesson: PackValidationReport.LessonResult,
        currentDraftJSON: String,
        language: LessonLanguage
    ) -> String {
        var text = """
            레슨 \(lesson.stableID) (\(lesson.language)) — \(lesson.title)

            ## 지금 이 레슨의 내용

            ```json
            \(currentDraftJSON)
            ```

            ## 검증이 잡아낸 것 (\(lesson.failures.count)건)
            """

        for (index, failure) in lesson.failures.enumerated() {
            text += "\n\n### \(index + 1). \(headline(for: failure.kind))\n"
            text += "\n단계: \(failure.stage.rawValue)"
            if let blockID = failure.blockID { text += " / 블록: \(blockID)" }
            if let line = failure.line {
                text += " / 위치: \(line)\(failure.column.map { ":\($0)" } ?? "")행"
            }
            text += "\n요약: \(failure.summary)\n"
            if let evidence = failure.evidence, !evidence.isEmpty {
                text += """

                    러너 원문:

                    ```
                    \(evidence)
                    ```
                    """
            }
            text += "\n\n무엇을 해야 하는가:\n\(instruction(for: failure.kind, language: language))"
        }

        text += """


            위 지적을 전부 반영한 레슨 전문을 같은 스키마로 내놔라.
            """
        return text
    }

    /// 실패 한 줄 제목.
    public static func headline(for kind: PackValidationReport.Failure.Kind) -> String {
        switch kind {
        case .brokenReference: "참조가 깨졌다"
        case .malformedDirective: "레슨 문법이 깨졌다"
        case .blockStructure: "여섯 블록 구성이 어긋났다"
        case .inconsistentAnswer: "정답이 선택지·표식과 맞지 않는다"
        case .exampleFailedToRun: "실행 예제가 돌지 않았다"
        case .exampleOutputMismatch: "실행 예제의 출력이 기대와 다르다"
        case .solutionFailsTests: "정답이 숨은 테스트를 통과하지 못했다"
        case .starterAlreadyPasses: "starter 가 이미 통과한다 — 과제가 무의미하다"
        }
    }

    /// **여기가 갈림길이다.** 종류마다 완전히 다른 일을 시킨다.
    public static func instruction(
        for kind: PackValidationReport.Failure.Kind,
        language: LessonLanguage
    ) -> String {
        switch kind {
        case .starterAlreadyPasses:
            """
            과제를 어렵게 만들지 마라. 테스트와 solution 은 **한 글자도 건드리지 마라.**
            starterCode 에서 정답에 해당하는 부분을 걷어 내는 것이 전부다. 시그니처·타입·
            독스트링은 남기고 본문은 구현되지 않은 상태로 둬라 — \(starterStub(language)).
            걷어 낸 뒤 숨은 테스트를 머리로 돌려 보고, **반드시 실패하는지** 확인해라.
            """
        case .solutionFailsTests:
            """
            solutionCode 를 고쳐 숨은 테스트를 전부 통과시켜라. 테스트를 고쳐 통과시키는 것은
            금지다 — 테스트가 요구하는 동작이 과제의 정의다. 증거에 적힌 기대값과 실제값을
            한 케이스씩 맞춰 가면서 고쳐라. 고친 뒤 starter 로는 여전히 실패하는지도 확인해라.
            """
        case .exampleFailedToRun:
            """
            예제 코드가 실행되지 않았다. 증거의 진단을 한 줄씩 읽고 code 를 고쳐라. 표준
            라이브러리 밖의 것을 쓰지 말고, 이 레슨까지 배운 문법만 써라. 고친 코드를 머리로
            실행해 expectedStdout 도 함께 다시 계산해라.
            """
        case .exampleOutputMismatch:
            """
            코드는 돌았고 **출력이 달랐다.** 기본은 expectedStdout 을 실제 출력에 맞추는
            것이다 — 증거에 실제 출력이 그대로 있으니 그것을 그대로 옮겨라. 서식·자릿수·공백·
            줄바꿈까지 바이트로 대조된다. 실제 출력 쪽이 교육적으로 틀렸다면 그때만 code 를
            고치고, 그 경우 expectedStdout 도 다시 계산해라.
            """
        case .inconsistentAnswer:
            """
            정답 키를 실제 선택지에 맞춰라. answerChoiceID 는 choices 의 어느 id 와 정확히
            같아야 하고, 빈칸은 template 의 `___n___` 표식 번호와 answers 의 slot 이 1 부터
            빠짐없이 대응해야 한다. 선택지 문면을 고치지 말고 대응만 맞춰라.
            """
        case .malformedDirective, .blockStructure:
            """
            산문·코드 필드의 모양이 문서 조립을 깨뜨렸다. 산문 어느 줄도 `}` 로 시작하거나
            `@` 와 대문자로 시작하지 않게 하고, 산문 필드에 코드펜스를 넣지 마라. 같은 내용을
            더 단순한 구조로 다시 써라.
            """
        case .brokenReference:
            """
            파일 참조가 어긋났다. 경로는 도구가 정하므로 네가 쓸 것은 내용뿐이다 —
            starterCode·testsCode·solutionCode·expectedStdout 을 빠짐없이 채웠는지 확인하고,
            비어 있던 것을 채워라.
            """
        }
    }

    private static func starterStub(_ language: LessonLanguage) -> String {
        switch language {
        case .python: "`raise NotImplementedError` 한 줄이면 된다"
        case .sql: "채워야 할 자리를 주석으로 표시한 골격 질의만 남겨라"
        case .swift: "`fatalError(\"여기를 구현해라\")` 한 줄이면 된다"
        }
    }
}
