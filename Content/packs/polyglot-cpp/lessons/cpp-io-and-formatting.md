@Concept(id: cpp-io-concept) {
`std::cout` 이 값을 밖으로 내보내는 통로라면, `std::cin` 은 값을 안으로 들여오는 통로다. 방향만 반대일 뿐 쓰는 법은 닮아서 `>>` 로 값을 받는다 — `int age; std::cin >> age;` 라고 쓰면 표준입력에서 공백을 건너뛴 뒤 숫자로 읽을 수 있는 부분을 정수로 바꿔 age 에 담는다. 프로그램이 한 번도 입력을 읽지 않으면 실행할 때마다 같은 결과만 낼 수 있으므로, cin 은 프로그램이 바깥 상황에 따라 다르게 반응하게 만드는 통로인 셈이다. (이 트랙의 채점 환경은 표준입력을 비워 둔 채로 실행하므로, 여기서 실제로 실행해 보는 예제·과제는 cin 을 쓰지 않는다.)

실수를 `std::cout` 으로 그냥 찍으면 서식이 값에 따라 달라진다 — 어떤 값은 `3.5` 처럼 나오고, 아주 크거나 아주 작은 값은 지수 표기로 바뀌기도 하며, 소수 자릿수도 유효 자릿수 기준으로 늘었다 줄었다 한다. 계산 로직은 그대로인데 값만 살짝 달라져도 찍히는 글자 수가 바뀔 수 있다는 뜻이다.

`<iomanip>` 의 `std::fixed` 는 이 요동을 없애고 항상 일반 소수 표기(지수 표기 금지)로 찍게 고정한다. 그 위에 `std::setprecision(n)` 을 얹으면 소수점 아래 자릿수가 정확히 n 자리로 못박힌다 — `fixed` 없이 `setprecision` 만 쓰면 정한 것은 소수 자릿수가 아니라 전체 유효 자릿수라는 점에서 뜻이 달라지므로 둘을 세트로 기억해 두는 편이 안전하다. 한 번 스트림에 흘려보낸 서식은 그 스트림에 계속 남아서, 이후에 찍는 다른 실수에도 똑같이 적용된다.

채점기는 프로그램이 낸 stdout 을 정답과 글자 하나하나 대조한다. 서식을 코드로 못박지 않으면 같은 계산이라도 값이 조금만 달라져도 출력되는 문자 수가 바뀌어, 로직은 맞았는데 자릿수 때문에 떨어지는 일이 생긴다. 실수를 출력할 때 자릿수를 항상 명시하는 습관은 그래서 이 트랙 전체에서 계속 요구된다.
}

@Example(id: cpp-io-example, language: cpp, expected: expected/cpp-io-and-formatting.txt) {
같은 std::fixed 를 켠 채로 setprecision 을 바꿔가며 실수 둘을 찍는다. 입력은 읽지 않는다.

```cpp
#include <iostream>
#include <iomanip>

int main() {
    double price = 19.999;
    double ratio = 2.0 / 3.0;

    std::cout << std::fixed << std::setprecision(2);
    std::cout << "가격: " << price << std::endl;
    std::cout << "비율: " << ratio << std::endl;

    std::cout << std::setprecision(4);
    std::cout << "비율(4자리): " << ratio << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-io-blank, language: cpp) {
pi 를 소수점 셋째 자리까지 고정해 찍도록 완성하자.

```cpp
#include <iostream>
#include <iomanip>

int main() {
    double pi = 3.14159;
    std::cout << ___1___ << std::setprecision(___2___) << pi << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`std::fixed`
}

@Answer(slot: 2) {
`3`
}
}

@Task(id: cpp-io-task, language: cpp, starter: starters/cpp-io-and-formatting.cpp, tests: tests/cpp-io-and-formatting.cpp, solution: solutions/cpp-io-and-formatting.cpp) {
실수를 소수점 둘째 자리까지 고정한 문자열로 만들어 반환하는 함수 `formatFixed` 를 완성하라. `formatFixed(3.1)` 은 `"3.10"` 을, `formatFixed(19.999)` 는 반올림되어 `"20.00"` 을 돌려줘야 한다. `0.0` 을 넣으면 `"0.00"` 이어야 하고, 음수를 넣으면 부호가 그대로 유지되어야 한다.

@Hint {
std::ostringstream 에 std::fixed 와 std::setprecision(2) 를 먼저 흘려보낸 뒤 값을 넣어라.
}

@Hint {
out.str() 로 스트림에 쌓인 문자열을 꺼내 반환하라.
}

@Hint {
<sstream> 과 <iomanip> 을 include 해야 std::ostringstream 과 std::setprecision 을 쓸 수 있다.
}
}

@Quiz(id: cpp-io-quiz, answer: format-varies) {
@Question {
채점기가 프로그램의 stdout 을 글자 그대로 비교한다고 할 때, 실수를 그냥 std::cout 으로 찍지 않고 std::fixed 와 std::setprecision 으로 자릿수를 못박아야 하는 이유는 무엇일까요?
}

@Choice(id: format-varies) {
cout 의 기본 서식은 값의 크기에 따라 소수 자릿수나 지수 표기 여부가 달라질 수 있어, 계산 로직은 그대로여도 값만 바뀌면 출력되는 문자가 달라질 수 있기 때문이다
}

@Choice(id: wont-compile) {
fixed 와 setprecision 을 쓰지 않으면 실수를 cout 으로 찍는 코드 자체가 컴파일되지 않기 때문이다
}

@Choice(id: truncates) {
fixed 를 쓰지 않으면 실수가 반올림 없이 그냥 잘려서 찍히기 때문이다
}

@Choice(id: slower) {
setprecision 을 쓰지 않으면 출력이 더 느려지기 때문이다
}

@Explanation {
cout 의 기본 서식은 값의 크기에 맞춰 일반 표기와 지수 표기를 오가고 유효 자릿수 기준으로 소수 자릿수를 정하기 때문에, 같은 코드라도 넣는 값에 따라 찍히는 문자 수가 달라질 수 있다. fixed·setprecision 은 이 표기 방식과 자릿수를 코드로 고정해 값이 달라져도 형식만은 예측 가능하게 만든다. 컴파일 여부나 반올림 방식, 출력 속도와는 관계가 없다.
}
}

@Reflection(id: cpp-io-reflection) {
@Prompt(id: cin-failure) {
std::cin >> age; 로 정수를 읽으려 하는데 사용자가 문자를 입력했다면 어떤 일이 일어날지 예상해 보고, 왜 그렇게 설계됐을지 생각해 보세요.
}

@Prompt(id: format-habit-elsewhere) {
이 트랙은 stdout 을 글자 그대로 비교해 채점합니다. 실수의 자릿수를 항상 명시하는 습관이 채점과 상관없는 실무 코드에서는 어떤 이유로 유용할까요?
}
}
