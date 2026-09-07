@Concept(id: cpp-lambda-concept) {
지난 레슨에서 `sort` 에 비교 기준을 넘기려면 이름 있는 함수를 따로 정의해야 했다. 딱 한 곳에서만 쓸 짧은 함수를 위해 매번 파일 어딘가에 이름을 짓고 정의를 써야 한다면 번거롭다. 람다는 함수를 이름 없이 그 자리에서 바로 만드는 문법이다: `[](int a, int b) { return a > b; }` 는 정수 두 개를 받아 `a > b` 를 돌려주는 함수 그 자체다.

람다의 각 부분은 이렇다. `[]` 는 캡처 목록, `(int a, int b)` 는 매개변수 목록, `{ return a > b; }` 는 본문이다. 다른 함수와 똑같이 `bool isBig = [](int x) { return x > 100; };` 처럼 변수에 담아 나중에 `isBig(50)` 으로 호출할 수도 있고, `sort` 처럼 함수를 받는 자리에 그대로 넘길 수도 있다.

캡처 목록 `[]` 가 람다를 함수와 다르게 만드는 부분이다. 람다 바깥의 변수를 안에서 쓰고 싶으면 캡처해야 한다 — `[threshold](int x) { return x > threshold; }` 처럼 대괄호 안에 이름을 적으면 그 변수를 값으로 복사해 람다 안으로 가져온다(캡처하지 않은 바깥 변수는 람다 본문에서 쓸 수 없다). `[&threshold]` 처럼 `&` 를 붙이면 복사 대신 참조로 가져온다 — 참조 매개변수와 같은 원리다. 여러 변수를 한꺼번에 캡처하고 싶으면 `[=]` (전부 값으로) 또는 `[&]` (전부 참조로) 를 쓴다.

비교 함수를 넘겨야 하는 자리 — `sort` 의 세 번째 인자, 나중에 배울 여러 알고리즘 — 는 람다가 특히 자연스러운 자리다. 정렬 기준이 그 호출 하나에서만 의미가 있을 때, 이름 있는 함수를 따로 정의해 파일을 어지럽히는 대신 필요한 자리에서 바로 만들어 쓴다.
}

@Example(id: cpp-lambda-example, language: cpp, expected: expected/cpp-lambdas.txt) {
변수에 담은 람다를 호출해 보고, 캡처한 바깥 변수를 기준으로 벡터를 정렬한다.

```cpp
#include <algorithm>
#include <iostream>
#include <vector>

int main() {
    auto isBig = [](int x) { return x > 100; };
    std::cout << "50은 큰가: " << isBig(50) << std::endl;
    std::cout << "150은 큰가: " << isBig(150) << std::endl;

    int pivot = 5;
    std::vector<int> nums = {8, 2, 9, 1, 5, 3};

    std::sort(nums.begin(), nums.end(), [pivot](int a, int b) {
        // pivot 에 더 가까운 쪽이 앞으로 온다.
        int da = a - pivot;
        int db = b - pivot;
        if (da < 0) da = -da;
        if (db < 0) db = -db;
        return da < db;
    });

    std::cout << "pivot(" << pivot << ")에 가까운 순: ";
    for (int n : nums) {
        std::cout << n << " ";
    }
    std::cout << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-lambda-blank, language: cpp) {
바깥 변수 limit 을 값으로 캡처하는 람다를 채워 완성하자.

```cpp
#include <iostream>

int main() {
    int limit = 10;
    auto underLimit = ___1___limit___2___(int x) { return x < limit; };
    std::cout << underLimit(5) << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`[`
}

@Answer(slot: 2) {
`]`
}
}

@Task(id: cpp-lambda-task, language: cpp, starter: starters/cpp-lambdas.cpp, tests: tests/cpp-lambdas.cpp, solution: solutions/cpp-lambdas.cpp) {
정수 벡터와 기준값을 받아, 기준값보다 작은 원소만 남긴 새 벡터를 만들어 오름차순으로 정렬해 돌려주는 함수 `filterAndSort` 를 완성하라. 시그니처는 `std::vector<int> filterAndSort(const std::vector<int>& values, int limit)` 다. 반드시 람다를 하나 이상 써야 한다 — 예를 들어 필터링 조건을 판단하는 람다를 만들어 각 원소에 적용해라. 입력에 `limit` 보다 작은 원소가 하나도 없으면 빈 벡터를 돌려준다.

@Hint {
auto isUnder = [limit](int x) { return x < limit; }; 로 조건 판단 람다를 만들고 반복문에서 호출해라.
}

@Hint {
조건을 만족하는 원소만 새 벡터에 push_back 해라.
}

@Hint {
필터링이 끝난 뒤에 std::sort 로 정렬해라 — 순서는 필터링 다음이다.
}
}

@Quiz(id: cpp-lambda-quiz, answer: capture-copy) {
@Question {
람다 [limit](int x) { return x < limit; } 에서 캡처 목록 [limit] 의 역할은?
}

@Choice(id: capture-copy) {
바깥에 있는 변수 limit 의 값을 복사해 람다 본문에서 쓸 수 있게 한다
}

@Choice(id: declare-param) {
limit 을 람다의 매개변수로 선언한다
}

@Choice(id: return-type) {
람다의 반환 타입을 limit 으로 지정한다
}

@Choice(id: name-lambda) {
이 람다에 limit 이라는 이름을 붙인다
}

@Explanation {
대괄호 [] 는 캡처 목록이고, 그 안에 이름을 적으면 바깥 스코프의 그 변수를 값으로 복사해 람다 본문 안에서 쓸 수 있게 한다. 매개변수는 그 다음의 소괄호 (int x) 에서 선언되고, 반환 타입은 본문에서 추론되며, 람다 자체는 원래 이름이 없다(변수에 담으면 그 변수 이름으로 부를 뿐이다).
}
}

@Reflection(id: cpp-lambda-reflection) {
@Prompt(id: value-vs-ref-capture) {
[limit] 처럼 값으로 캡처하는 것과 [&limit] 처럼 참조로 캡처하는 것의 차이가 실제로 문제가 되는 상황(예: 람다를 만든 뒤 바깥의 limit 값이 바뀌는 경우)을 상상해 적어 보세요.
}

@Prompt(id: lambda-vs-named-function) {
이번 과제의 조건을 이름 있는 함수(예: bool isUnderLimit(int, int))로 따로 정의했다면 람다를 쓴 것과 비교해 무엇이 더 낫고 무엇이 덜 나을지 적어 보세요.
}
}
