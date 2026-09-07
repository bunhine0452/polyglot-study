@Concept(id: cpp-testing-concept) {
지금까지 함수를 짜고 나면 눈으로 결과를 보고 "맞는 것 같다" 고 판단해 왔다. 하지만 함수가 늘어날수록, 그리고 나중에 코드를 고칠수록 매번 눈으로 확인하는 것은 지치고 놓치기 쉽다. 필요한 것은 "이 입력에는 이 결과가 나와야 한다" 는 약속을 코드로 남겨 두고, 그 약속이 지켜지는지 기계가 대신 확인하게 하는 것이다.

가장 간단한 형태는 실제값과 기대값을 비교하는 함수를 스스로 만드는 것이다. `checkEqual(label, actual, expected)` 처럼 두 값을 받아 같으면 통과를, 다르면 무엇이 왜 다른지를 출력하는 함수 하나면 충분하다. 표준 라이브러리의 `<cassert>` 에는 `assert(조건)` 이라는 매크로도 있는데, 조건이 거짓이면 파일명과 줄 번호를 찍고 프로그램을 즉시 멈춘다 — 개발 중에 "여기서부터는 절대 거짓이면 안 된다"는 전제를 박아 두는 용도로 쓰지만, 하나라도 실패하면 그 자리에서 멈춰 버리므로 여러 검사를 한 번에 다 돌려 보고 싶을 때는 맞지 않는다.

그래서 스스로 만드는 체크 함수는 실패해도 프로그램을 멈추지 않고 다음 검사로 넘어가게 만드는 것이 유용하다. 그리고 실패했을 때 "기대값은 X 인데 실제값은 Y 다" 처럼 둘을 나란히 보여주면, 코드를 처음부터 다시 훑지 않아도 어디서 계산이 어긋났는지 짐작할 수 있다.

사실 이 트랙의 모든 과제를 풀 때마다 이미 이 방식을 경험했다. 과제를 채점하는 숨은 검사들이 실패하면 "OO 가 X 이어야 하는데 Y 입니다" 라는 메시지가 나왔는데, 그것이 바로 지금 배우는 기대값·실제값 비교 패턴이다. 경계값 — 0, 음수, 빈 입력처럼 순진한 구현이 놓치기 쉬운 경우 — 을 검사 목록에 하나 더 넣어 두는 습관도 여기서부터 시작된다.
}

@Example(id: cpp-testing-example, language: cpp, expected: expected/cpp-testing-with-assert.txt) {
square 함수가 몇 가지 입력에서 옳은 값을 내는지, 스스로 만든 checkEqual 함수로 확인한다. 마지막 하나는 일부러 틀린 기대값을 넣어 실패 메시지가 어떻게 보이는지 보여준다.

```cpp
#include <iostream>
#include <string>

int square(int n) {
    return n * n;
}

void checkEqual(const std::string& label, int actual, int expected) {
    if (actual == expected) {
        std::cout << "[통과] " << label << std::endl;
    } else {
        std::cout << "[실패] " << label << ": 기대값은 " << expected
                   << "인데 실제값은 " << actual << "입니다" << std::endl;
    }
}

int main() {
    checkEqual("2의 제곱", square(2), 4);
    checkEqual("0의 제곱", square(0), 0);
    checkEqual("음수의 제곱", square(-3), 9);
    checkEqual("일부러 틀린 기대값", square(5), 999);

    return 0;
}
```
}

@Blank(id: cpp-testing-blank, language: cpp) {
같은지 비교하는 연산자와, 3 더하기 4의 기대값을 채워 완성하자.

```cpp
#include <iostream>
#include <string>

void checkEqual(const std::string& label, int actual, int expected) {
    if (actual ___1___ expected) {
        std::cout << "[통과] " << label << std::endl;
    } else {
        std::cout << "[실패] " << label << std::endl;
    }
}

int main() {
    checkEqual("삼 더하기 사", 3 + 4, ___2___);
    return 0;
}
```

@Answer(slot: 1) {
`==`
}

@Answer(slot: 2) {
`7`
}
}

@Task(id: cpp-testing-task, language: cpp, starter: starters/cpp-testing-with-assert.cpp, tests: tests/cpp-testing-with-assert.cpp, solution: solutions/cpp-testing-with-assert.cpp) {
실제값과 기대값을 비교해 결과를 문자열로 돌려주는 함수 `compareResult` 를 완성하라. 두 값이 같으면 정확히 `"일치"` 를 돌려준다. 다르면 `"기대값 X, 실제값 Y"` 형식으로 돌려준다(X 는 expected, Y 는 actual 을 숫자 그대로 적은 것).

@Hint {
std::to_string 으로 int 를 std::string 으로 바꿀 수 있다.
}

@Hint {
같은지 먼저 검사하고, 아니면 형식 문자열을 만든다.
}

@Hint {
기대값이 먼저, 실제값이 나중이라는 순서를 정확히 지켜라.
}
}

@Quiz(id: cpp-testing-quiz, answer: diagnose) {
@Question {
실패한 검사의 메시지에 기대값과 실제값을 둘 다 적어야 하는 이유는?
}

@Choice(id: diagnose) {
둘을 나란히 보면 코드를 다시 읽지 않고도 무엇이 잘못됐는지 바로 짐작할 수 있기 때문이다
}

@Choice(id: shorter) {
메시지를 더 짧게 만들 수 있기 때문이다
}

@Choice(id: compile-req) {
컴파일러가 두 값을 다 요구하기 때문이다
}

@Choice(id: only-actual) {
실제값만 있으면 항상 충분해서 기대값은 사실 필요 없다
}

@Explanation {
실패 메시지에 기대값과 실제값을 같이 적어 두면, 그 둘의 차이만 보고도 어디서 계산이 어긋났는지 짐작할 수 있다. 실제값만 있으면 "이 값이 왜 틀렸는지" 를 판단할 기준이 없어 코드를 처음부터 다시 추적해야 한다. 메시지 길이나 컴파일러 요구사항과는 관계없다.
}
}

@Reflection(id: cpp-testing-reflection) {
@Prompt(id: message-vs-boolean) {
compareResult 처럼 실패 이유를 문자열로 만들어 두면, 그냥 true/false 만 돌려주는 것과 비교해 디버깅이 어떻게 달라질지 적어 보세요.
}

@Prompt(id: recall-harness-messages) {
이 트랙의 과제를 풀 때마다 본 실패 메시지("OO 가 X 이어야 하는데 Y 입니다")를 떠올리며, 그 형식이 왜 그렇게 생겼을지 생각해 보세요.
}
}
