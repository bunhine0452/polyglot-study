@Concept(id: cpp-vartypes-concept) {
C++ 에서 변수를 선언하려면 타입을 먼저 적어야 한다. `int` 는 정수, `double` 은 소수점이 있는 실수, `bool` 은 참·거짓 두 값만 갖는 타입이다. 이렇게 타입을 나누는 이유는 각 타입이 메모리에 저장되는 방식과 그 위에서 할 수 있는 연산이 서로 다르기 때문이다 — 정수 연산은 오차 없이 정확하지만, 실수는 유한한 비트로 무한히 많은 소수를 흉내 내는 근사값이다. `bool` 은 내부적으로 1바이트를 쓰지만 `std::cout` 은 기본적으로 이를 숫자 `1`·`0` 으로 찍는다.

`int` 끼리 나누면 결과도 `int` 다. `7 / 2` 는 `3.5` 가 아니라 `3` 이다 — 나머지를 버리는 것이 아니라, 애초에 두 정수를 나누는 연산 자체가 정수 연산이기 때문이다. 이 계산 결과를 나중에 `double` 변수에 담아도 이미 버려진 소수점은 되살아나지 않는다. 실수 나눗셈을 하려면 나누는 시점에 피연산자 중 하나가 `double` 이어야 한다 — `7 / 2.0` 처럼 써야 `3.5` 가 나온다.

`auto` 는 변수의 타입을 직접 적는 대신 컴파일러가 초기값을 보고 추론하게 시킨다. 이것은 실행 중에 타입이 바뀌는 동적 타이핑이 아니다 — 컴파일 시점에 딱 한 번 타입이 정해지고, 그 뒤로는 다른 보통 변수와 똑같이 고정된다. `auto` 를 쓰려면 반드시 초기값이 있어야 하는데, 컴파일러가 추론할 대상이 없으면 타입을 정할 방법이 없기 때문이다.

한 글자를 담는 `char` 라는 타입도 있는데, `"A"` 같은 문자열과 달리 `'A'` 처럼 작은따옴표로 쓰고 한 글자만 담는다. 이 레슨에서는 다루지 않고 뒤에서 문자열을 순회할 때 다시 만난다.
}

@Example(id: cpp-vartypes-example, language: cpp, expected: expected/cpp-variables-and-types.txt) {
같은 나눗셈을 int 로 할 때와 double 로 할 때를 나란히 찍어 차이를 확인한다.

```cpp
#include <iostream>

int main() {
    int score = 7;
    int total = 2;

    int intDivision = score / total;
    double realDivision = score / 2.0;

    bool passed = intDivision >= 3;
    auto label = "결과";

    std::cout << label << std::endl;
    std::cout << "정수 나눗셈: " << intDivision << std::endl;
    std::cout << "실수 나눗셈: " << realDivision << std::endl;
    std::cout << "합격 여부: " << passed << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-vartypes-blank, language: cpp) {
count 를 정수로, isEven 을 참·거짓 타입으로 선언해 완성하자.

```cpp
#include <iostream>

int main() {
    ___1___ count = 6;
    double half = count / 2.0;
    ___2___ isEven = (count % 2 == 0);

    std::cout << "count=" << count << " half=" << half << " even=" << isEven << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`int`
}

@Answer(slot: 2) {
`bool`
}
}

@Task(id: cpp-vartypes-task, language: cpp, starter: starters/cpp-variables-and-types.cpp, tests: tests/cpp-variables-and-types.cpp, solution: solutions/cpp-variables-and-types.cpp) {
두 정수의 평균을 실수로 계산해 반환하는 함수 `average` 를 완성하라. `average(4, 2)` 는 `3.0` 을, `average(7, 2)` 는 `4.5` 를 돌려줘야 한다. 두 정수를 그냥 나누면 정수 나눗셈이 되어 소수점이 사라진다는 점에 주의하라. 두 인자가 모두 음수여도, 서로 상쇄되어 0이 되어도 올바르게 계산되어야 한다.

@Hint {
a + b 를 먼저 괄호로 묶고 2.0 으로 나눠라 — 2 로 나누면 정수 나눗셈이 된다.
}

@Hint {
정수와 실수를 함께 연산하면 결과는 자동으로 실수로 맞춰진다.
}

@Hint {
반환 타입이 이미 double 이므로, 나눗셈 자체를 실수 나눗셈으로 만드는 데 집중하라.
}
}

@Quiz(id: cpp-vartypes-quiz, answer: three) {
@Question {
`int total = 7; int count = 2; double avg = total / count;` 를 실행하면 avg 에는 무엇이 들어갈까요?
}

@Choice(id: three) {
3 — total / count 가 정수 나눗셈으로 먼저 계산된 뒤에 double 로 옮겨진다
}

@Choice(id: three-point-five) {
3.5 — 어차피 double 변수에 담기니까 나눗셈도 실수로 계산된다
}

@Choice(id: three-point-five-zero-zero) {
3.5000 — double 은 항상 소수 넷째 자리까지 표시된다
}

@Choice(id: compile-error) {
컴파일 에러 — int 를 double 변수에 대입할 수 없다
}

@Explanation {
대입은 나눗셈이 끝난 다음에 일어난다. total 과 count 가 둘 다 int 이므로 total / count 는 그 자리에서 정수 나눗셈으로 계산되어 3이 되고, 그 3이 double 로 변환되어 avg 에 들어간다. avg 의 타입이 double 이라는 사실은 나눗셈 자체의 방식을 바꾸지 못한다. int 를 double 에 대입하는 것은 정보 손실이 없는 방향이라 컴파일 에러도 나지 않는다.
}
}

@Reflection(id: cpp-vartypes-reflection) {
@Prompt(id: why-int-division-first) {
avg 의 타입이 double 인데도 total / count 가 정수 나눗셈으로 계산되는 이유를, 연산이 일어나는 "시점" 을 기준으로 설명해 보세요.
}

@Prompt(id: when-auto-confuses) {
auto 를 쓰면 타입을 안 적어도 되어 편하지만, 코드를 읽는 사람 입장에서는 오히려 헷갈릴 수 있는 경우가 있을까요?
}
}
