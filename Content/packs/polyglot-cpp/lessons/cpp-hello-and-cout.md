@Concept(id: cpp-hello-concept) {
C++ 프로그램은 `int main()` 에서 시작한다. 운영체제가 실행 파일을 띄우면 가장 먼저 부르는 함수가 이것이고, 이름이 정확히 `main` 이어야 한다. 끝의 `return 0;` 은 "정상적으로 끝났다" 를 운영체제에 알리는 값인데, `main` 에서는 생략해도 컴파일러가 0을 넣어 준다.

화면에 무언가를 찍으려면 `std::cout` 을 쓰고, 값은 `<<` 로 밀어 넣는다. `<<` 는 여러 번 이어 붙일 수 있어서 `std::cout << a << b;` 처럼 쓴다. 이 연산자는 원래 비트 시프트인데 출력 스트림에 대해 다른 뜻으로 다시 정의된 것이다 — 나중에 배울 연산자 오버로딩의 가장 흔한 예다.

`std::cout` 을 쓰려면 `<iostream>` 헤더를 include 해야 한다. C++ 에서 표준 기능은 자동으로 딸려 오지 않고, 쓸 것을 명시적으로 들여와야 한다. 앞의 `std::` 는 이름이 표준 라이브러리의 것임을 밝히는 이름공간 표시다.

줄바꿈은 `std::endl` 이나 `"\n"` 으로 넣는다. 둘의 차이는 `std::endl` 이 줄바꿈과 함께 버퍼를 비운다는 것인데, 짧은 프로그램에서는 결과가 같다.
}

@Example(id: cpp-hello-example, language: cpp, expected: expected/cpp-hello-and-cout.txt) {
그냥 찍기, 값 하나 끼워 찍기, 값 둘을 이어 찍기를 한 번에 본다. 주석은 출력에 나타나지 않는다.

```cpp
#include <iostream>
#include <string>

int main() {
    // 이 줄은 실행되지 않는다.
    std::cout << "안녕하세요, C++" << std::endl;

    int year = 2026;
    std::cout << "올해는 " << year << "년입니다" << std::endl;

    std::string language = "C++";
    int standard = 20;
    std::cout << language << " 표준 " << standard << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-hello-blank, language: cpp) {
출력 스트림의 이름과 값을 밀어 넣는 연산자를 채워 완성하자.

```cpp
#include <iostream>

int main() {
    int count = 3;
    ___1___ << "개수: " ___2___ count << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`std::cout`
}

@Answer(slot: 2) {
`<<`
}
}

@Task(id: cpp-hello-task, language: cpp, starter: starters/cpp-hello-and-cout.cpp, tests: tests/cpp-hello-and-cout.cpp, solution: solutions/cpp-hello-and-cout.cpp) {
이름을 받아 인사말을 만들어 돌려주는 함수 `greeting` 을 완성하라. `greeting("세계")` 는 정확히 `안녕하세요, 세계!` 를 돌려줘야 한다. 화면에 찍는 것이 아니라 `std::string` 으로 **반환**한다는 점에 주의하라. 빈 문자열을 받으면 `안녕하세요, 이름 없음!` 을 돌려준다.

@Hint {
`std::string` 끼리는 `+` 로 이어 붙일 수 있다.
}

@Hint {
비었는지는 `name.empty()` 로 검사한다.
}

@Hint {
느낌표까지 포함해서 정확히 일치해야 한다 — 기대 문자열을 다시 읽어 보라.
}
}

@Quiz(id: cpp-hello-quiz, answer: declaration) {
@Question {
`std::cout` 을 쓰려면 왜 `#include <iostream>` 이 필요할까요?
}

@Choice(id: declaration) {
컴파일러가 std::cout 이라는 이름의 선언을 그 헤더에서 얻기 때문이다
}

@Choice(id: runtime) {
실행 중에 출력 장치를 여는 코드가 그 안에 들어 있기 때문이다
}

@Choice(id: namespace) {
std 라는 이름공간 자체를 만들어 주기 때문이다
}

@Choice(id: optimize) {
출력 속도를 높이는 최적화가 그 헤더에 있기 때문이다
}

@Explanation {
C++ 은 쓰기 전에 선언을 봐야 한다. `<iostream>` 은 `std::cout` 이 무엇인지(어떤 타입이고 어떤 연산을 받는지)를 컴파일러에 알려 주는 선언을 담고 있다. 실행 시점의 장치 열기나 최적화와는 관계가 없고, `std` 이름공간은 어느 한 헤더가 만드는 것이 아니라 표준 라이브러리 전체가 나눠 채운다.
}
}

@Reflection(id: cpp-hello-reflection) {
@Prompt(id: explicit-include) {
C++ 은 쓸 기능을 직접 include 해야 합니다. 자동으로 다 딸려 오는 언어와 비교해 어떤 장단점이 있을지 적어 보세요.
}

@Prompt(id: print-vs-return) {
과제에서는 화면에 찍는 대신 문자열을 반환했습니다. 같은 기능을 찍는 함수로 만들면 테스트하기가 어떻게 달라질까요?
}
}
