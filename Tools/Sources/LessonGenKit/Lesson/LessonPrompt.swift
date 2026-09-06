import LearnCore

/// 레슨 생성·수리가 공유하는 프롬프트.
///
/// ## 시스템 프롬프트가 고정인 이유
///
/// 프롬프트 캐시는 **접두사 바이트 일치**다. 한 글자만 달라도 뒤가 전부 무효가 되므로
/// 시각·레슨 id·언어 같은 가변부는 여기 들어오지 못한다. 그래서 언어별 하네스 계약을
/// 세 언어 **전부** 실어 둔다 — 언어마다 다른 시스템 프롬프트를 쓰면 트랙이 바뀔 때마다
/// 캐시가 차가워지고, 접두사가 짧아져 캐시로 아낄 것도 줄어든다.
///
/// 수리 단계도 이 시스템 프롬프트를 **그대로** 앞에 두고 지시문을 두 번째 조각으로
/// 덧붙인다. 접두사가 같으면 생성에서 데워진 캐시를 수리가 이어 쓴다.
///
/// 캐시가 실제로 붙었는지는 `usage.cached_tokens` 로 확인한다 — 접두사를 잘 잡아도
/// `session_id` 로 업스트림을 고정하지 않으면 매번 차갑다 (`{#lessongen-prompt-caching}`).
public enum LessonPrompt {
    /// 모든 요청의 안정 접두사. **여기에 가변값을 넣지 마라.**
    public static let system: String = {
        let contracts = LessonLanguage.allCases.map { language in
            """
            ## \(language.rawValue)

            실행 예제:
            \(language.exampleContract)

            채점 하네스:
            \(language.harnessContract)
            """
        }.joined(separator: "\n\n")

        return """
            너는 프로그래밍 학습 앱 Polyglot Study 의 레슨 저자다. 레슨 하나를 **데이터로** \
            내놓는다. 마크다운 문서를 쓰는 것이 아니다 — 주어진 JSON 스키마의 필드를 채우면 \
            도구가 문서로 조립한다.

            # 레슨의 모양

            모든 레슨은 예외 없이 여섯 블록이다: 개념 → 실행 예제 → 빈칸 → 테스트 과제 → \
            퀴즈 → 회고. 여섯을 다 채워야 한다.

            # 블록마다 무엇을 쓰는가

            - **concept** — 읽는 블록. 개념을 설명하는 한국어 산문이다.
            - **example** — 읽고 실행하는 블록. `code` 는 그대로 실행되는 프로그램이고, \
            `expectedStdout` 은 그것을 돌렸을 때 나오는 출력이다.
            - **blank** — **코드 빈칸 채우기**다. `template` 은 몇 글자를 도려낸 **코드**이고, \
            도려낸 자리에는 밑줄 셋 + 번호 + 밑줄 셋 표식이 들어간다. `answers` 의 각 항목은 \
            그 표식 자리에 그대로 끼워 넣을 코드 조각이다. 예를 들어 template 이

                values = [1, 2, 3]
                total = ___1___(values)
                print(f"total={___2___}")

            이면 answers 는 slot 1 = `sum`, slot 2 = `total` 이다. template 에 제목이나 \
            설명 문장을 쓰지 마라 — 그 자리는 코드다.
            - **task** — 편집하고 채점받는 블록. starter·tests·solution 세 코드가 한 벌이다.
            - **quiz** — 선택지 하나를 고르는 블록.
            - **reflection** — 채점하지 않는 열린 질문.

            # 반드시 지킬 것

            1. **과제는 starter 로 통과할 수 없어야 한다.** starter 에는 시그니처와 주석과 \
            "여기를 구현해라" 에 해당하는 자리만 있고 정답 로직이 없다. 숨은 테스트를 \
            starter 로 돌리면 반드시 실패해야 하고, solution 으로 돌리면 반드시 통과해야 한다. \
            이 둘 중 하나라도 어긋나면 그 과제는 학습자에게 아무것도 가르치지 않는다.
            2. **예제의 기대 출력은 네가 머리로 실행한 결과다.** 코드를 한 줄씩 따라가서 \
            stdout 에 나갈 문자를 그대로 적어라. 있을 법한 출력을 지어내지 마라. 서식·자릿수·\
            공백·줄바꿈이 바이트로 대조된다.
            3. **테스트는 최소 3개이고 하나는 경계값이다.** 빈 입력, 0, 음수, 중복처럼 순진한 \
            구현이 놓치는 경우를 넣어라.
            4. **선수 개념만 쓴다.** 주어진 학습목표와 선수 레슨이 다루지 않은 문법·라이브러리를 \
            끌어오지 마라.
            5. 학습자에게 보이는 모든 문장은 한국어다. 식별자·API 이름·코드는 원문 그대로 둔다.
            6. 퀴즈 오답은 그럴듯해야 한다. 명백히 틀린 선택지는 아무것도 가르치지 않는다.
            7. 코드에는 외부 패키지를 쓰지 않는다. 표준 라이브러리만 쓴다.

            # 필드에 쓰지 말아야 할 것

            - 산문 필드에 코드펜스(```)를 넣지 마라. 코드는 전용 필드로 간다.
            - 산문의 어떤 줄도 `}` 로 시작하거나 `@` 와 대문자로 시작할 수 없다.
            - 파일 경로를 만들지 마라. 경로는 도구가 정한다.

            # 언어별 계약

            \(contracts)
            """
    }()

    /// 레슨 한 편의 가변부.
    public static func user(
        outline: LessonOutline,
        language: LessonLanguage,
        trackTitle: String,
        precedingTitles: [String],
        notes: String?
    ) -> String {
        var text = """
            트랙: \(trackTitle) (\(language.rawValue))
            레슨 순번: \(outline.ordinal)
            레슨 제목: \(outline.title)
            요약: \(outline.summary)
            학습목표:
            \(outline.objectives.map { "- \($0)" }.joined(separator: "\n"))
            다루는 개념: \(outline.concepts.joined(separator: ", "))
            """
        if precedingTitles.isEmpty {
            text += "\n\n이 트랙의 첫 레슨이다. 학습자는 이 언어를 처음 본다고 가정해라."
        } else {
            text += """


                앞선 레슨(여기서 다룬 것은 전제해도 된다):
                \(precedingTitles.map { "- \($0)" }.joined(separator: "\n"))
                """
        }
        if let notes, !notes.trimmedOuterWhitespace().isEmpty {
            text += "\n\n추가 요구사항:\n\(notes)"
        }
        text += "\n\n이 레슨의 여섯 블록을 스키마대로 채워라."
        return text
    }

    /// 직렬화가 거부했을 때 같은 대화에 덧붙일 사용자 메시지.
    ///
    /// 실패를 **문법 규칙 위반**으로 되돌려 준다. 모델이 다시 같은 구조를 만들지 않도록
    /// 무엇을 하라까지 적는다.
    /// 응답이 스키마를 만족하는 JSON 이 아니었을 때.
    ///
    /// 구조화 출력을 걸어도 일어난다 — 업스트림이 문법을 강제하지 않고 유도만 하면
    /// 스키마 밖의 글자가 섞인다. 그래서 이 재요청은 "형식" 만 말한다.
    public static func schemaRetry(_ detail: String) -> String {
        """
        방금 준 응답을 JSON 으로 읽지 못했다 (\(detail)).

        같은 레슨을 다시 내놓되, 주어진 스키마를 만족하는 **JSON 객체 하나만** 보내라.
        앞뒤에 설명·머리말·코드펜스를 붙이지 말고, 객체를 닫는 중괄호 뒤에 아무것도 쓰지 마라.
        """
    }

    public static func serializationRetry(_ error: LessonSerializationError) -> String {
        """
        방금 준 레슨은 문서로 조립하지 못했다.

        \(error.promptFeedback)

        같은 레슨을 처음부터 다시, 같은 스키마로 내놔라. 다른 필드는 그대로 두어도 된다.
        """
    }
}
