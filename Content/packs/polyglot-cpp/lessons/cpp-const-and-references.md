@Concept(id: cpp-constref-concept) {
`const` 는 컴파일러에게 하는 약속이다 — 이 변수는 초기화된 뒤로 절대 바뀌지 않는다는 것을 밝히면, 컴파일러가 그 약속을 강제로 지켜 준다. 실수로 값을 다시 대입하는 코드를 적으면 프로그램이 돌아간 뒤에야 드러나는 버그가 아니라, 컴파일이 아예 되지 않는 에러로 바로 잡힌다. 매직 넘버 대신 `const int maxRetries = 3;` 처럼 이름을 붙이면 그 값이 앞으로도 바뀌지 않는다는 의도까지 코드에 남길 수 있다.

`&` 로 선언하는 참조는 이미 있는 변수에 붙이는 또 다른 이름이다. 복사본을 새로 만드는 것이 아니라, 같은 변수를 다른 이름으로 부르는 것뿐이라 참조를 통해 값을 바꾸면 원래 변수도 함께 바뀐다. 참조는 독자적인 실체가 없기 때문에 선언과 동시에 반드시 무언가를 가리켜야 한다 — `int& ref;` 처럼 가리킬 대상 없이 선언하는 것은 애초에 성립하지 않는다. 그리고 한번 어떤 변수에 묶이면 다른 변수를 다시 가리키도록 바꿀 수 없다.

`const` 와 `&` 를 합친 const 참조는 값을 복사하지 않으면서도 그 값을 통해서는 원본을 바꿀 수 없게 만든 읽기 전용 별명이다. 원본 변수는 다른 경로로 여전히 바뀔 수 있지만, 이 별명을 쥔 코드만큼은 "보기만 하고 건드리지 않는다" 는 것이 보장된다. const 참조는 심지어 이름이 없는 임시값에도 붙을 수 있어서 — 예를 들어 계산식의 결과처럼 변수가 아닌 값도 잠깐 이름을 빌려 줄 수 있다 — 이 덕분에 함수 매개변수 자리에서 특히 자주 쓰인다.
}

@Example(id: cpp-constref-example, language: cpp, expected: expected/cpp-const-and-references.txt) {
const 로 상수를, &로 별명을, 그리고 둘을 합친 const 참조를 각각 만들어 본다.

```cpp
#include <iostream>

int main() {
    const int maxRetries = 3;
    std::cout << "최대 재시도: " << maxRetries << std::endl;

    int score = 10;
    int& scoreRef = score;
    scoreRef += 5;
    std::cout << "score: " << score << std::endl;

    const int& readOnly = score;
    std::cout << "읽기 전용 별명: " << readOnly << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-constref-blank, language: cpp) {
limit 은 바뀌지 않는 상수로, alias 는 count 의 참조로 선언해 완성하자.

```cpp
#include <iostream>

int main() {
    ___1___ int limit = 100;
    int count = 40;
    int ___2___ alias = count;
    alias += 10;

    std::cout << "limit=" << limit << " count=" << count << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`const`
}

@Answer(slot: 2) {
`&`
}
}

@Task(id: cpp-constref-task, language: cpp, starter: starters/cpp-const-and-references.cpp, tests: tests/cpp-const-and-references.cpp, solution: solutions/cpp-const-and-references.cpp) {
정수 하나를 참조로 받아 그 값을 두 배로 바꾸는 함수 `doubleInPlace` 를 완성하라. 이 함수는 아무것도 반환하지 않고, 대신 참조로 받은 변수 자체의 값을 바꾼다. `int n = 5; doubleInPlace(n);` 을 실행하면 n 은 10이 되어야 한다. 0을 넣으면 0 그대로여야 하고, 음수를 넣으면 부호를 유지한 채로 두 배가 되어야 한다.

@Hint {
n 은 이미 참조이므로, n 에 값을 대입하면 원래 변수가 바뀐다.
}

@Hint {
반환값이 없는 함수이므로 return 문은 필요 없다.
}

@Hint {
n * 2 를 계산해서 그대로 n 에 대입하라.
}
}

@Quiz(id: cpp-constref-quiz, answer: uninitialized-ref) {
@Question {
다음 중 컴파일 에러가 나는 코드는 무엇일까요?
}

@Choice(id: reassign-through-ref) {
int a = 1; int& ref = a; ref = 2;
}

@Choice(id: uninitialized-ref) {
int a = 1; int& ref; ref = a;
}

@Choice(id: print-const) {
const int c = 1; std::cout << c;
}

@Choice(id: const-ref-bind) {
int a = 1; const int& ref = a;
}

@Explanation {
참조는 독자적인 데이터가 없는, 순전히 다른 변수의 또 다른 이름이다. 그래서 선언과 동시에 반드시 무언가를 가리켜야 하는데, `int& ref;` 는 가리킬 대상 없이 참조를 만들려는 것이라 컴파일러가 거부한다. 나머지 셋은 모두 유효하다 — 별명을 통해 원본 값을 바꾸는 것, const 값을 출력하는 것, 이미 있는 변수에 const 참조로 별명을 붙이는 것 모두 문제가 없다.
}
}

@Reflection(id: cpp-constref-reflection) {
@Prompt(id: when-to-const) {
const 로 선언할 변수와 그냥 변수로 둘 변수를 어떻게 구분하는 게 좋을지, 자신이 짜본 코드나 예상되는 상황을 들어 적어 보세요.
}

@Prompt(id: alias-metaphor) {
참조를 "변수의 또 다른 이름(별명)" 이라고 비유했습니다. 이 비유가 잘 들어맞는 부분과, 오히려 헷갈리게 만드는 부분이 있다면 무엇일까요?
}
}
