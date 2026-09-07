@Concept(id: cpp-vector-concept) {
`std::vector<T>` 는 크기가 실행 중에 늘어나는 배열이다. 일반 배열은 크기를 컴파일할 때 이미 정해 둬야 하지만, vector 는 원소가 몇 개나 필요할지 미리 몰라도 되게 만들어 준다 — 필요한 메모리를 스스로 관리하면서 요청이 들어올 때마다 늘어난다.

`push_back` 은 새 원소를 맨 뒤에 덧붙인다. `size()` 는 지금까지 담긴 원소 개수를 돌려주는데, 이 값의 타입은 음수가 있을 수 없는 부호 없는 정수(`std::size_t`)다. 인덱스로 원소에 접근할 때는 `v[i]` 처럼 대괄호를 쓰는데, 이 연산은 i 가 실제로 유효한 범위 안에 있는지 검사해 주지 않는다 — 범위를 벗어난 인덱스를 넣으면 무엇이 나올지 보장되지 않으므로, 인덱스를 쓰기 전에는 항상 `size()` 와 비교해 스스로 검사해야 한다.

원소 하나하나의 값만 필요하고 인덱스는 필요 없다면 범위 기반 for(`for (int x : v)`)가 더 짧고 실수할 자리도 적다. 인덱스를 세는 변수도, 범위를 벗어날 위험도 없이 처음부터 끝까지 순서대로 값을 하나씩 꺼내 준다. 그 값을 직접 바꿔서 원본 벡터에도 반영하고 싶다면 `int&` 로 받으면 되지만, 이 레슨에서는 값을 읽기만 하는 형태로 충분하다.
}

@Example(id: cpp-vector-example, language: cpp, expected: expected/cpp-vector-basics.txt) {
push_back 으로 채우고, size 와 인덱스로 접근한 뒤, 범위 기반 for 로 합을 구한다.

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> scores;
    scores.push_back(90);
    scores.push_back(85);
    scores.push_back(78);

    std::cout << "개수: " << scores.size() << std::endl;
    std::cout << "첫 점수: " << scores[0] << std::endl;
    std::cout << "마지막 점수: " << scores[scores.size() - 1] << std::endl;

    int total = 0;
    for (int score : scores) {
        total += score;
    }
    std::cout << "합계: " << total << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-vector-blank, language: cpp) {
numbers 에 10을 추가하는 메서드 이름과, 범위 기반 for 가 순회할 대상을 채워 완성하자.

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> numbers;
    numbers.___1___(10);
    numbers.push_back(20);
    numbers.push_back(30);

    int total = 0;
    for (int n : ___2___) {
        total += n;
    }

    std::cout << "size=" << numbers.size() << " total=" << total << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`push_back`
}

@Answer(slot: 2) {
`numbers`
}
}

@Task(id: cpp-vector-task, language: cpp, starter: starters/cpp-vector-basics.cpp, tests: tests/cpp-vector-basics.cpp, solution: solutions/cpp-vector-basics.cpp) {
정수 벡터에서 짝수만 더해 반환하는 함수 `sumEvens` 를 완성하라. 벡터는 복사하지 않도록 const 참조로 받는다. 빈 벡터를 넣으면 0을 반환하고, 짝수가 하나도 없어도 0을 반환한다. 음수인 짝수도 올바르게 더해야 한다.

@Hint {
범위 기반 for 로 nums 의 각 원소를 하나씩 꺼내라.
}

@Hint {
n % 2 == 0 으로 짝수인지 검사하라 — 음수도 이 검사로 잘 걸러진다.
}

@Hint {
빈 벡터는 반복문 몸통이 한 번도 실행되지 않아 자연스럽게 0이 반환된다.
}
}

@Quiz(id: cpp-vector-quiz, answer: undefined-behavior) {
@Question {
std::vector<int> v = {1, 2, 3}; 일 때 v[3] 에 접근하면 어떻게 될까요?
}

@Choice(id: throws) {
예외가 발생해서 프로그램이 안전하게 종료된다
}

@Choice(id: undefined-behavior) {
정의되지 않은 동작이다 — 범위를 벗어난 접근이라 무엇이 나올지 보장되지 않는다
}

@Choice(id: returns-zero) {
자동으로 0이 반환된다
}

@Choice(id: compile-error) {
컴파일 에러가 난다
}

@Explanation {
operator[] 는 인덱스가 유효한 범위 안에 있는지 검사하지 않는다. v.size() 가 3이면 유효한 인덱스는 0, 1, 2 뿐이고 v[3] 은 벡터가 차지한 메모리 바로 바깥을 들여다보는 것이라 어떤 값이 나올지, 심지어 프로그램이 어떻게 동작할지도 보장되지 않는다. 예외가 발생하지도, 자동으로 0이 채워지지도, 컴파일 에러가 나지도 않는다 — 그래서 인덱스를 쓰기 전에 항상 size() 와 비교해 범위를 스스로 검사해야 한다.
}
}

@Reflection(id: cpp-vector-reflection) {
@Prompt(id: growth-cost) {
push_back 으로 계속 원소를 추가해도 vector 가 알아서 커지는 방식이, 크기가 고정된 배열과 비교해 어떤 비용을 치를 것 같은지 짐작해 적어 보세요.
}

@Prompt(id: when-index-needed) {
범위 기반 for 로는 지금 원소가 몇 번째인지 알 수 없습니다. 인덱스 자체가 꼭 필요한 상황이라면 무엇을 대신 쓰겠는지 적어 보세요.
}
}
