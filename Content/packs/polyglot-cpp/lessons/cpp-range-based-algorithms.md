@Concept(id: cpp-rangealgo-concept) {
`begin()` 과 `end()` 는 컨테이너를 순회할 구간을 반복자 한 쌍으로 표현한다. `begin()` 은 첫 원소를 가리키고, `end()` 는 마지막 원소의 **다음** 자리를 가리킨다 — 그래서 이 구간을 half-open(반열림) 구간이라 부른다. `end()` 자체를 역참조하면 안 되고, "거기까지 왔으면 멈춰라" 는 신호로만 쓴다. 범위 기반 `for` 문도 내부적으로는 이 begin/end 쌍을 그대로 쓰고 있었다 — 다만 반복자를 직접 다루지 않도록 문법이 감춰 준 것뿐이다.

`<numeric>` 의 `std::accumulate(begin, end, init)` 은 구간의 모든 원소를 초깃값 `init` 에서 시작해 왼쪽부터 하나씩 더해 나간다. 네 번째 인자로 람다를 넘기면 덧셈 대신 그 연산을 쓴다 — 곱을 구하고 싶다면 초깃값을 1로, 연산을 곱셈으로 바꾸면 된다. 이렇게 "구간을 접어서 값 하나로 만드는" 것을 리듀스(reduce)라고도 부른다.

`<algorithm>` 의 `std::transform(begin, end, destBegin, fn)` 은 반대로 "펼치는" 연산이다. 입력 구간의 각 원소에 `fn` 을 적용한 결과를 목적지 반복자가 가리키는 자리부터 하나씩 써 넣는다. 중요한 점은 `transform` 이 목적지 컨테이너의 크기를 스스로 늘려주지 않는다는 것이다 — `push_back` 처럼 새 자리를 만드는 게 아니라 이미 있는 자리에 값을 대입하므로, 결과를 담을 벡터는 미리 필요한 크기로 만들어 둬야 한다.

인덱스로 `for (int i = 0; i < v.size(); ++i)` 를 직접 돌리는 대신 이런 알고리즘을 쓰면, "무엇을 할지" 만 람다로 적으면 되고 "어떻게 순회할지" 는 표준 라이브러리가 이미 검증해 둔 코드에 맡기게 된다.
}

@Example(id: cpp-rangealgo-example, language: cpp, expected: expected/cpp-range-based-algorithms.txt) {
accumulate 로 합과 곱을 구하고, transform 으로 각 원소를 두 배로 바꾼 새 벡터를 만든다.

```cpp
#include <iostream>
#include <numeric>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> numbers = {1, 2, 3, 4, 5};

    int sum = std::accumulate(numbers.begin(), numbers.end(), 0);
    std::cout << "합계: " << sum << std::endl;

    std::vector<int> doubled(numbers.size());
    std::transform(numbers.begin(), numbers.end(), doubled.begin(),
                   [](int n) { return n * 2; });

    std::cout << "두 배: ";
    for (int n : doubled) {
        std::cout << n << " ";
    }
    std::cout << std::endl;

    int product = std::accumulate(numbers.begin(), numbers.end(), 1,
                                   [](int acc, int n) { return acc * n; });
    std::cout << "곱: " << product << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-rangealgo-blank, language: cpp) {
구간을 접어 합을 구하는 알고리즘 이름과, 구간의 시작·끝을 뜻하는 멤버 함수를 채워 완성하자.

```cpp
#include <iostream>
#include <numeric>
#include <vector>

int main() {
    std::vector<int> values = {10, 20, 30};

    int total = std::___1___(values.___2___(), values.___3___(), 0);
    std::cout << total << std::endl;

    return 0;
}
```

@Answer(slot: 1) {
`accumulate`
}

@Answer(slot: 2) {
`begin`
}

@Answer(slot: 3) {
`end`
}
}

@Task(id: cpp-rangealgo-task, language: cpp, starter: starters/cpp-range-based-algorithms.cpp, tests: tests/cpp-range-based-algorithms.cpp, solution: solutions/cpp-range-based-algorithms.cpp) {
정수 벡터를 다루는 함수 두 개를 완성하라. `sumOfSquares` 는 각 원소의 제곱의 합을 `<numeric>` 의 `accumulate` 로 구한다. `incrementAll` 은 각 원소에 `amount` 를 더한 새 벡터를 `<algorithm>` 의 `transform` 으로 만들어 돌려준다. 두 함수 모두 빈 벡터가 들어오면 안전하게 처리해야 한다(`sumOfSquares` 는 0, `incrementAll` 은 빈 벡터).

@Hint {
accumulate 의 세 번째 인자는 초깃값이고, 네 번째로 이항 연산을 람다로 넘길 수 있다.
}

@Hint {
transform 은 입력 범위 [begin, end) 를 순회하며 결과를 목적지 반복자에 하나씩 쓴다.
}

@Hint {
result 벡터는 미리 values.size() 크기로 만들어 둬야 transform 이 쓸 자리가 있다.
}
}

@Quiz(id: cpp-rangealgo-quiz, answer: no-resize) {
@Question {
std::transform 에 목적지로 넘기는 반복자가 가리키는 컨테이너를 미리 필요한 크기로 만들어 둬야 하는 이유는?
}

@Choice(id: no-resize) {
transform 은 목적지 컨테이너의 크기를 스스로 늘려주지 않고 이미 있는 자리에 값을 쓰기만 한다
}

@Choice(id: type-check) {
크기가 다르면 컴파일 오류가 나기 때문이다
}

@Choice(id: parallel) {
미리 만들어 두면 transform 이 병렬로 실행되기 때문이다
}

@Choice(id: auto-shrink) {
transform 이 필요 없는 남는 자리를 알아서 지워주기 때문이다
}

@Explanation {
transform 은 push_back 처럼 컨테이너를 늘려가며 쓰는 것이 아니라, 목적지 반복자가 가리키는 자리에 순서대로 값을 대입한다. 자리가 미리 없으면 존재하지 않는 메모리에 쓰게 되어 정의되지 않은 동작이 된다. 크기 불일치는 컴파일 시점에 걸리지 않고, 기본 std::transform 호출은 병렬 실행을 요구하지 않으며, 남는 자리를 지워주지도 않는다.
}
}

@Reflection(id: cpp-rangealgo-reflection) {
@Prompt(id: init-value-change) {
accumulate 의 초깃값을 0 대신 1로 바꾸면 결과가 어떻게 달라질지 생각해 보세요.
}

@Prompt(id: half-open-reason) {
begin() 과 end() 로 정의되는 구간이 end() 원소를 포함하지 않는 half-open 구간인 이유가 무엇일지 적어 보세요.
}
}
