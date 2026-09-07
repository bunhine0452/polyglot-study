@Concept(id: cpp-optional-concept) {
값을 찾는 함수는 "못 찾았다"는 결과도 정상적인 결과 중 하나다. 정수를 돌려주는 함수라면 못 찾았을 때 -1 같은 특수값을 쓰고 싶어지지만, -1 이 진짜 유효한 값일 수도 있는 상황이라면 이 방법은 애매해진다. `std::optional<T>` 는 "`T` 타입의 값이 있거나, 아예 없거나" 를 타입으로 표현한다 — `std::optional<int>` 는 정수가 있을 수도, 없을 수도 있는 상자다.

값이 있는 `optional` 은 그냥 그 값으로 만든다(`std::optional<int> found = 42;`). 값이 없음을 표현하려면 `std::nullopt` 를 돌려준다. 호출한 쪽에서는 `has_value()` 로 값이 있는지 검사하고, 있으면 `value()` 로 꺼낸다. 값이 없을 때 기본값을 쓰고 싶다면 `value_or(기본값)` 이 더 간결하다 — `has_value()` 를 검사하는 `if` 문 없이 한 줄로 "있으면 그 값, 없으면 기본값" 을 얻는다.

`optional` 은 "값이 없을 수 있다"는 정상적인 상황을 표현하는 데 쓴다. 반면 예외(`throw`/`try`/`catch`)는 함수가 자신의 계약을 지킬 수 없는, 정상 흐름을 벗어난 상황에 쓴다. 예를 들어 벡터에서 조건에 맞는 원소를 찾는 함수라면 못 찾는 것이 흔한 일이니 `optional` 이 자연스럽다. 반면 나눗셈 함수에 0을 나누는 수로 넘기는 것은 함수가 정의될 수 없는 입력이니 예외로 알리는 쪽이 맞다.

예외를 던지려면 `throw std::invalid_argument("메시지");` 처럼 쓰고(`<stdexcept>` 헤더가 필요하다), 받으려면 `try { ... } catch (const std::invalid_argument& e) { ... }` 로 감싼다. `catch` 블록에서 `e.what()` 을 호출하면 던질 때 넣은 메시지를 문자열로 돌려받는다. 예외를 처리하지 않고 그냥 두면 프로그램이 비정상 종료된다 — 그래서 잡을 수 있는 곳에서 반드시 `catch` 해야 한다.
}

@Example(id: cpp-optional-example, language: cpp, expected: expected/cpp-optional-and-error.txt) {
벡터에서 조건에 맞는 첫 원소를 optional 로 찾고, 나눗셈 함수는 0으로 나누면 예외를 던지도록 만든다.

```cpp
#include <iostream>
#include <optional>
#include <stdexcept>
#include <vector>

std::optional<int> findFirstEven(const std::vector<int>& values) {
    for (int v : values) {
        if (v % 2 == 0) {
            return v;
        }
    }
    return std::nullopt;
}

double safeDivide(double a, double b) {
    if (b == 0.0) {
        throw std::invalid_argument("0으로 나눌 수 없다");
    }
    return a / b;
}

int main() {
    std::vector<int> nums = {1, 3, 4, 7};
    std::optional<int> even = findFirstEven(nums);
    if (even.has_value()) {
        std::cout << "첫 짝수: " << even.value() << std::endl;
    }

    std::vector<int> odds = {1, 3, 5};
    std::optional<int> noEven = findFirstEven(odds);
    std::cout << "기본값 사용: " << noEven.value_or(-1) << std::endl;

    try {
        double result = safeDivide(10.0, 2.0);
        std::cout << "10 / 2 = " << result << std::endl;

        double bad = safeDivide(10.0, 0.0);
        std::cout << "이 줄은 실행되지 않는다: " << bad << std::endl;
    } catch (const std::invalid_argument& e) {
        std::cout << "예외 발생: " << e.what() << std::endl;
    }

    return 0;
}
```
}

@Blank(id: cpp-optional-blank, language: cpp) {
값이 없을 때 기본값을 돌려주는 value_or 호출을 채워 완성하자.

```cpp
#include <iostream>
#include <optional>

int main() {
    std::optional<int> maybe = std::nullopt;
    int result = maybe.___1___(___2___);
    std::cout << result << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`value_or`
}

@Answer(slot: 2) {
`0`
}
}

@Task(id: cpp-optional-task, language: cpp, starter: starters/cpp-optional-and-error.cpp, tests: tests/cpp-optional-and-error.cpp, solution: solutions/cpp-optional-and-error.cpp) {
이름으로 나이를 찾는 함수 `findAge` 와, 나이 두 개의 차이를 구하는 함수 `ageDifference` 를 완성하라. `findAge(const std::vector<std::pair<std::string, int>>& people, const std::string& name)` 는 `people` 에서 이름이 `name` 과 같은 첫 항목의 나이를 `std::optional<int>` 로 돌려주고, 없으면 `std::nullopt` 를 돌려준다. `ageDifference(int a, int b)` 는 `a` 와 `b` 중 큰 값에서 작은 값을 뺀 음수 아닌 차이를 돌려주되, 둘 중 하나라도 음수면 `std::invalid_argument` 를 던진다.

@Hint {
person.first 가 이름, person.second 가 나이다 — std::pair 의 필드 이름이다.
}

@Hint {
일치하는 항목을 찾으면 그 자리에서 바로 return person.second; 로 끝내라.
}

@Hint {
ageDifference 는 음수 검사를 가장 먼저 하고, 그 다음 삼항 연산자로 큰 쪽에서 작은 쪽을 빼라.
}
}

@Quiz(id: cpp-optional-quiz, answer: optional-then-exception) {
@Question {
"벡터에서 조건에 맞는 원소를 찾는데 없을 수도 있다"는 상황과 "함수에 정의되지 않은 입력(예: 0으로 나누기)이 들어왔다"는 상황을 각각 표현할 때 더 적절한 도구는?
}

@Choice(id: optional-then-exception) {
전자는 std::optional, 후자는 예외(throw)가 더 적절하다
}

@Choice(id: exception-then-optional) {
전자는 예외, 후자는 std::optional 이 더 적절하다
}

@Choice(id: both-optional) {
둘 다 std::optional 로 표현하는 것이 항상 낫다
}

@Choice(id: both-exception) {
둘 다 예외로 표현하는 것이 항상 낫다
}

@Explanation {
못 찾는 것이 흔하고 정상적인 결과인 상황에는 optional 이 자연스럽다 — 호출자가 매번 try-catch 를 쓸 필요 없이 has_value 로 검사하면 된다. 반면 0으로 나누기처럼 함수가 계약을 지킬 수 없는, 정상 흐름을 벗어난 입력에는 예외가 더 적절하다 — 호출자가 실수로 결과를 확인하지 않고 넘어가는 것을 막아 준다.
}
}

@Reflection(id: cpp-optional-reflection) {
@Prompt(id: sentinel-vs-optional) {
"못 찾으면 -1 을 돌려준다"는 방식과 std::optional<int> 를 돌려주는 방식을 비교했을 때, -1 이 실제로 유효한 값일 수 있는 상황을 하나 떠올려 왜 optional 이 더 안전한지 적어 보세요.
}

@Prompt(id: uncaught-exception) {
예외를 던지는 함수를 호출하면서 catch 를 하나도 쓰지 않으면 어떤 일이 벌어질지, 그리고 그것이 왜 위험한지 적어 보세요.
}
}
