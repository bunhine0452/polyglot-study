@Concept(id: cpp-algo-concept) {
벡터를 정렬하거나 원소를 찾는 일은 직접 반복문을 짜서 할 수도 있지만, 표준 라이브러리는 `<algorithm>` 헤더에 이미 검증된 구현을 갖춰 두었다. `std::sort(v.begin(), v.end())` 한 줄이면 `v` 전체가 오름차순으로 정렬된다. `begin()` 과 `end()` 는 각각 벡터의 처음과 끝(마지막 원소의 '다음' 자리)을 가리키는 반복자인데, 지금은 "정렬할 구간의 시작과 끝"이라고만 알아 두면 충분하다.

기본 정렬은 `<` 연산자를 기준으로 오름차순이다. 다른 기준으로 정렬하고 싶으면 `sort` 의 세 번째 인자로 비교 함수를 넘긴다. 비교 함수는 두 값을 받아 "첫 번째가 두 번째보다 앞에 와야 하면 true" 를 돌려주는 함수다. 예를 들어 내림차순으로 정렬하려면 `a > b` 를 돌려주는 함수를 넘기면 된다. 이 함수를 매번 따로 정의하는 것이 번거로운데, 다음 레슨에서 배울 람다가 바로 이 자리에 쓰인다.

`std::find(begin, end, value)` 는 구간에서 `value` 와 같은 첫 원소를 가리키는 반복자를 돌려준다. 못 찾으면 `end()` 와 같은 반복자를 돌려준다 — 그래서 `if (it != v.end())` 로 찾았는지 검사한다. `std::count(begin, end, value)` 는 `value` 와 같은 원소가 몇 개인지 개수를 세어 정수로 돌려준다. `find` 는 반복자를, `count` 는 정수를 돌려준다는 차이를 기억해 두면 헷갈리지 않는다.

이 함수들은 모두 벡터 자체가 아니라 구간(begin, end)을 받는다는 공통점이 있다. 그래서 벡터 전체가 아니라 일부 구간만 정렬하거나 찾을 수도 있고, 나중에 배열이나 다른 컨테이너에도 같은 함수를 그대로 쓸 수 있다.
}

@Example(id: cpp-algo-example, language: cpp, expected: expected/cpp-algorithms-sort-find.txt) {
벡터를 오름차순·내림차순으로 각각 정렬해 보고, find 와 count 로 원소를 찾는다.

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

bool descending(int a, int b) {
    return a > b;
}

int main() {
    std::vector<int> nums = {5, 2, 8, 2, 9, 1};

    std::sort(nums.begin(), nums.end());
    std::cout << "오름차순: ";
    for (int n : nums) {
        std::cout << n << " ";
    }
    std::cout << std::endl;

    std::sort(nums.begin(), nums.end(), descending);
    std::cout << "내림차순: ";
    for (int n : nums) {
        std::cout << n << " ";
    }
    std::cout << std::endl;

    auto it = std::find(nums.begin(), nums.end(), 8);
    if (it != nums.end()) {
        std::cout << "8을 찾았다" << std::endl;
    }

    int twos = std::count(nums.begin(), nums.end(), 2);
    std::cout << "2의 개수: " << twos << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-algo-blank, language: cpp) {
벡터 전체를 정렬하는 sort 호출을 채워 완성하자.

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main() {
    std::vector<int> nums = {3, 1, 2};
    std::sort(nums.___1___(), nums.___2___());
    for (int n : nums) {
        std::cout << n << " ";
    }
    std::cout << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`begin`
}

@Answer(slot: 2) {
`end`
}
}

@Task(id: cpp-algo-task, language: cpp, starter: starters/cpp-algorithms-sort-find.cpp, tests: tests/cpp-algorithms-sort-find.cpp, solution: solutions/cpp-algorithms-sort-find.cpp) {
정수 벡터에서 특정 값보다 큰 원소가 몇 개 있는지 세고, 그 값을 포함해 정렬했을 때 그 값이 처음 나오는 위치(0부터 시작하는 인덱스)를 함께 구하는 함수 `analyze` 를 완성하라. 시그니처는 `void analyze(std::vector<int> values, int target, int& outGreaterCount, int& outSortedIndex)` 다. `values` 는 값으로 받으므로 함수 안에서 자유롭게 정렬해도 호출자의 벡터에는 영향이 없다. `outGreaterCount` 에는 (정렬 전) `values` 에서 `target` 보다 큰 원소의 개수를 채운다. 그 다음 `values` 를 오름차순으로 정렬하고, `target` 이 처음 나오는 인덱스를 `outSortedIndex` 에 채운다. `target` 이 `values` 에 없으면 `outSortedIndex` 에 -1 을 채운다.

@Hint {
outGreaterCount 는 정렬하기 전에 원본 순서 그대로 세도 상관없다 — 개수는 순서와 무관하다.
}

@Hint {
find 가 돌려주는 반복자와 begin() 의 차이(it - values.begin())가 인덱스가 된다.
}

@Hint {
find 결과가 end() 와 같은지 먼저 검사해서 -1 을 채우는 경우를 분리해라.
}
}

@Quiz(id: cpp-algo-quiz, answer: end-iterator) {
@Question {
std::find(v.begin(), v.end(), x) 가 x 를 찾지 못했을 때 돌려주는 값은?
}

@Choice(id: end-iterator) {
v.end() 와 같은 반복자
}

@Choice(id: minus-one) {
정수 -1
}

@Choice(id: null) {
nullptr
}

@Choice(id: throws) {
예외를 던진다
}

@Explanation {
std::find 는 항상 반복자를 돌려주는 함수라서, 못 찾았을 때도 정수나 nullptr 이 아니라 v.end() 와 같은 반복자를 돌려준다. -1 은 인덱스 기반 검색(예: std::string::find)에서 흔한 실패 값이지만 std::find 는 그렇지 않다. 예외도 던지지 않는다 — 못 찾는 것은 정상적인 결과 중 하나로 취급된다.
}
}

@Reflection(id: cpp-algo-reflection) {
@Prompt(id: handwritten-vs-library) {
sort 를 직접 반복문(예: 버블 정렬)으로 짰다면 어떤 위험이 있을지, 표준 라이브러리 구현을 쓰는 것과 비교해 적어 보세요.
}

@Prompt(id: find-vs-count) {
std::find 는 반복자를, std::count 는 정수를 돌려줍니다. 둘의 반환 타입이 다른 것이 각각의 용도와 어떻게 맞아떨어지는지 생각해 보세요.
}
}
