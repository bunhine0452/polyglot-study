@Concept(id: cpp-pbr-concept) {
함수를 값으로 호출하면(`void f(std::vector<int> v)`) 인자로 넘긴 벡터 전체가 복사된다. 원소가 몇 개 안 되면 티가 안 나지만, 수천 개짜리 벡터를 함수 하나 부를 때마다 복사한다면 그 비용은 고스란히 실행 시간으로 남는다. `cpp.const-and-references` 에서 본 참조(`&`)는 이 복사를 없애 준다 — 참조는 새 객체를 만들지 않고 기존 객체에 다른 이름을 붙일 뿐이다.

그래서 큰 값을 읽기만 할 때는 `const std::vector<int>& v` 로 받는 것이 관용구다. `const` 는 이 함수가 `v` 를 바꾸지 않겠다는 약속이고, `&` 는 복사를 생략하겠다는 뜻이다. 둘을 같이 쓰면 호출자 입장에서 안전하다 — 넘긴 벡터가 함수 안에서 몰래 바뀔 걱정 없이, 복사 비용도 내지 않는다.

반대로 함수가 호출자의 변수를 실제로 바꿔야 한다면 `const` 를 떼고 그냥 참조로 받는다(`std::vector<int>& v`). 이런 매개변수를 출력 매개변수라고 부르는데, 함수가 값을 `return` 하는 대신 넘겨받은 자리에 결과를 채워 넣는 방식이다. 함수 하나가 값을 여러 개 돌려줘야 할 때 특히 쓸모가 있다 — `return` 은 하나만 되지만 참조 매개변수는 여러 개 둘 수 있다.

요약하면 세 가지 선택지가 있다. 작은 값(`int`, `double`, `bool`)은 그냥 값으로 받아도 복사 비용이 미미하다. 큰 값을 읽기만 하면 `const&` 로 받는다. 큰 값을 바꿔야 하면 `&` 로 받는다. 어느 쪽도 아닌 채로 큰 값을 값으로 받는 것은 대개 실수다.
}

@Example(id: cpp-pbr-example, language: cpp, expected: expected/cpp-pass-by-reference.txt) {
합계를 구하는 함수는 읽기만 하니 const 참조로 받고, 각 원소를 두 배로 만드는 함수는 실제로 바꿔야 하니 참조로 받는다.

```cpp
#include <iostream>
#include <vector>

int sum(const std::vector<int>& values) {
    int total = 0;
    for (int v : values) {
        total += v;
    }
    return total;
}

void doubleInPlace(std::vector<int>& values) {
    for (int& v : values) {
        v *= 2;
    }
}

int main() {
    std::vector<int> numbers = {1, 2, 3, 4};
    std::cout << "합계: " << sum(numbers) << std::endl;

    doubleInPlace(numbers);
    std::cout << "두 배 후: ";
    for (int v : numbers) {
        std::cout << v << " ";
    }
    std::cout << std::endl;

    std::cout << "두 배 후 합계: " << sum(numbers) << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-pbr-blank, language: cpp) {
벡터를 복사하지 않고 읽기만 하는 함수의 매개변수를 채워 완성하자.

```cpp
#include <iostream>
#include <vector>

int countNegatives(___1___ std::vector<int>___2___ values) {
    int count = 0;
    for (int v : values) {
        if (v < 0) {
            count++;
        }
    }
    return count;
}

int main() {
    std::vector<int> data = {3, -1, 4, -1, -5};
    std::cout << countNegatives(data) << std::endl;
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

@Task(id: cpp-pbr-task, language: cpp, starter: starters/cpp-pass-by-reference.cpp, tests: tests/cpp-pass-by-reference.cpp, solution: solutions/cpp-pass-by-reference.cpp) {
정수 벡터에서 최댓값과 최솟값을 동시에 구하는 함수 `findMinMax` 를 완성하라. 시그니처는 다음과 같다: `void findMinMax(const std::vector<int>& values, int& outMin, int& outMax)`. `values` 는 읽기만 하므로 const 참조로 받고, 결과는 `outMin` 과 `outMax` 라는 두 출력 매개변수에 채워 넣는다(반환값은 없다). `values` 가 비어 있으면 `std::invalid_argument` 를 던진다. `values` 에 원소가 하나뿐이면 `outMin` 과 `outMax` 모두 그 값이 된다.

@Hint {
outMin·outMax 는 참조이므로 함수 안에서 대입하면 호출자의 변수가 바뀐다.
}

@Hint {
빈 벡터 검사를 가장 먼저 하고, 그 다음에 첫 원소로 초기값을 잡아라.
}

@Hint {
for (int v : values) 로 순회하면서 outMin·outMax 를 갱신해라.
}
}

@Quiz(id: cpp-pbr-quiz, answer: const-ref) {
@Question {
다음 중 `std::vector<int>` 를 매개변수로 받을 때 가장 적절한 선언은? (함수가 벡터 내용을 읽기만 하고 바꾸지 않는다고 가정)
}

@Choice(id: const-ref) {
void f(const std::vector<int>& v)
}

@Choice(id: by-value) {
void f(std::vector<int> v)
}

@Choice(id: plain-ref) {
void f(std::vector<int>& v)
}

@Choice(id: const-value) {
void f(const std::vector<int> v)
}

@Explanation {
읽기만 한다면 const 참조가 정답이다 — 복사 비용이 없고, const 가 실수로 바꾸는 것도 막아 준다. 값으로 받으면(by-value) 호출마다 전체를 복사하니 낭비다. const 없는 참조(plain-ref)는 컴파일은 되지만 '바꾸지 않는다'는 의도를 코드로 남기지 못해 나중에 실수로 바꿔도 컴파일러가 못 잡는다. const 값(const-value) 은 어차피 복사본이라 const 여부가 호출자에게 아무 의미가 없고 복사 비용만 그대로 남는다.
}
}

@Reflection(id: cpp-pbr-reflection) {
@Prompt(id: when-output-param) {
함수가 값을 두 개 이상 돌려줘야 할 때 출력 매개변수 대신 쓸 수 있는 다른 방법이 있을까요? 떠오르는 대로 적어 보세요.
}

@Prompt(id: const-as-documentation) {
매개변수에 const 를 붙이는 것이 컴파일러에게 뿐 아니라 코드를 읽는 사람에게도 어떤 정보를 주는지 생각해 보세요.
}
}
