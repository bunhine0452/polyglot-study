/// 두 언어짜리 레슨 소스 하나. 알고리즘 레슨의 모양을 그대로 흉내낸다 —
/// 개념·퀴즈·돌아보기는 한 번, 예제·빈칸·과제는 언어마다.
///
/// 팩 픽스처를 새로 만들지 않는 이유: 검증하려는 것이 **파일 배치가 아니라 화면의 동작**
/// 이라, 파서를 그대로 태운 문서 하나면 충분하다. 팩 포맷은 `ContentKitTests` 가 본다.
enum ReferenceLessonSource {
    static let twoLanguages = """
        @Concept(id: bs-concept) {
        정렬된 배열에서는 절반씩 버리며 찾을 수 있다. 어느 언어로 풀든 같은 이야기다.
        }

        @Example(id: bs-example-swift, language: swift, expected: expected/bs-swift.txt) {
        Swift 로 훑어본다.

        ```swift
        print("swift")
        ```
        }

        @Example(id: bs-example-py, language: python, expected: expected/bs-py.txt) {
        Python 으로 훑어본다.

        ```python
        print("python")
        ```
        }

        @Blank(id: bs-blank-swift, language: swift) {
        한 칸을 채워라.

        ```swift
        let mid = lo + (hi ___1___ lo) / 2
        ```

        @Answer(slot: 1) {
        `-`
        }
        }

        @Blank(id: bs-blank-py, language: python) {
        한 칸을 채워라.

        ```python
        mid = lo + (hi ___1___ lo) // 2
        ```

        @Answer(slot: 1) {
        `-`
        }
        }

        @Task(id: bs-task-swift, language: swift, starter: starters/bs.swift, \
        tests: tests/bs.swift, solution: solutions/bs.swift) {
        이진 탐색을 완성해라.
        }

        @Task(id: bs-task-py, language: python, starter: starters/bs.py, \
        tests: tests/bs.py, solution: solutions/bs.py) {
        이진 탐색을 완성해라.
        }

        @Quiz(id: bs-quiz, answer: half) {
        @Question {
        후보 구간은 매 반복마다 어떻게 되나?
        }

        @Choice(id: half) {
        절반으로 줄어든다
        }

        @Choice(id: one) {
        하나씩 줄어든다
        }

        @Explanation {
        그래서 비교 횟수가 로그에 비례한다.
        }
        }

        @Reflection(id: bs-reflect) {
        @Prompt(id: when) {
        정렬돼 있지 않다면 무엇부터 해야 할까?
        }
        }
        """
}
