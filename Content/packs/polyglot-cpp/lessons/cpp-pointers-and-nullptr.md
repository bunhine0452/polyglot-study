@Concept(id: cpp-pointers-concept) {
포인터는 값이 아니라 값이 놓인 **주소**를 담는 변수다. `int* scorePtr = &score;` 는 `score` 가 메모리 어디에 있는지를 `scorePtr` 에 저장한다. `&` 는 변수 앞에 붙어 "이 변수의 주소를 달라" 는 뜻이고, `*` 는 포인터 앞에 붙어 "이 주소가 가리키는 값" 을 뜻한다. `*scorePtr = 20;` 처럼 역참조한 자리에 대입하면 원래 변수 `score` 의 값이 바뀐다 — 포인터를 거쳐 원본에 손을 댄 것이다.

앞서 배운 참조(&)와 겹쳐 보이지만 성격이 다르다. 참조는 선언할 때 반드시 누군가에게 묶여야 하고 이후 다른 대상으로 바꿀 수 없다. 포인터는 처음에 아무것도 안 가리키게 둘 수 있고, 나중에 다른 주소로 다시 대입할 수도 있다. "지금은 가리키는 대상이 없다" 를 표현할 방법이 참조에는 없지만 포인터에는 있다 — 그것이 `nullptr` 다.

`nullptr` 는 "아무것도 가리키지 않는다" 는 뜻의 포인터 값이다. 초기화하지 않은 포인터는 쓰레기 주소를 담고 있을 수 있어 위험하므로, 아직 가리킬 대상이 없다면 `nullptr` 로 명시적으로 초기화해 두는 것이 안전하다. 그리고 포인터를 역참조하기 전에는 `if (ptr == nullptr)` 같은 검사로 먼저 확인하는 습관을 들여야 한다 — `nullptr` 를 역참조하면 프로그램이 즉시 비정상 종료된다.

포인터와 참조는 결국 같은 것(주소)을 다루지만, 참조는 "항상 유효한 별명" 이라는 더 강한 약속을 하고 포인터는 "없을 수도, 바뀔 수도 있는 주소" 라는 더 느슨하지만 유연한 약속을 한다. 이 차이 때문에 함수 매개변수에는 보통 참조를 쓰고, "없음" 을 표현하거나 나중에 다른 대상으로 옮겨야 할 때는 포인터를 쓴다.
}

@Example(id: cpp-pointers-example, language: cpp, expected: expected/cpp-pointers-and-nullptr.txt) {
변수의 주소를 포인터에 담고, 그 포인터로 값을 읽고 바꾼 뒤, nullptr 검사까지 확인한다.

```cpp
#include <iostream>

int main() {
    int score = 10;
    int* scorePtr = &score;

    std::cout << "score = " << score << std::endl;
    std::cout << "*scorePtr = " << *scorePtr << std::endl;

    *scorePtr = 20;
    std::cout << "score 변경 후 = " << score << std::endl;

    int* nothing = nullptr;
    if (nothing == nullptr) {
        std::cout << "nothing 은 아무것도 가리키지 않는다" << std::endl;
    }

    return 0;
}
```
}

@Blank(id: cpp-pointers-blank, language: cpp) {
주소를 얻는 연산자, 값을 얻는 연산자, 그리고 "없음" 을 뜻하는 값을 채워 완성하자.

```cpp
#include <iostream>

int main() {
    int value = 42;
    int* ptr = ___1___value;
    std::cout << ___2___ptr << std::endl;

    int* empty = ___3___;
    if (empty == nullptr) {
        std::cout << "no value" << std::endl;
    }
    return 0;
}
```

@Answer(slot: 1) {
`&`
}

@Answer(slot: 2) {
`*`
}

@Answer(slot: 3) {
`nullptr`
}
}

@Task(id: cpp-pointers-task, language: cpp, starter: starters/cpp-pointers-and-nullptr.cpp, tests: tests/cpp-pointers-and-nullptr.cpp, solution: solutions/cpp-pointers-and-nullptr.cpp) {
벡터에서 처음 나오는 음수의 **주소**를 돌려주는 함수 `findFirstNegative` 를 완성하라. 음수를 찾으면 그 원소를 가리키는 `int*` 를 돌려주고, 끝까지 못 찾으면 `nullptr` 를 돌려준다. 반환된 포인터로 값을 바꾸면 원본 벡터의 값도 바뀌어야 한다.

@Hint {
size_t 로 인덱스를 돌리며 numbers[i] 가 음수인지 검사한다.
}

@Hint {
찾으면 &numbers[i] 를 돌려준다 — 인덱스가 아니라 주소다.
}

@Hint {
끝까지 못 찾으면 nullptr 를 돌려준다.
}
}

@Quiz(id: cpp-pointers-quiz, answer: reassign) {
@Question {
포인터와 참조의 가장 큰 차이는 무엇인가요?
}

@Choice(id: reassign) {
포인터는 다른 대상을 다시 가리키게 바꿀 수 있지만, 참조는 한 번 묶이면 바꿀 수 없다
}

@Choice(id: speed) {
포인터가 참조보다 항상 더 빠르게 동작한다
}

@Choice(id: type) {
참조는 정수에만 쓸 수 있고 포인터는 모든 타입에 쓸 수 있다
}

@Choice(id: syntax) {
포인터는 함수의 매개변수로 쓸 수 없고 참조만 가능하다
}

@Explanation {
참조는 선언 시 반드시 초기화되고 이후 다른 대상으로 바꿀 수 없다. 포인터는 nullptr 를 담거나 나중에 다른 주소를 대입할 수 있어 "가리키는 대상이 없음" 과 "다시 가리킴" 을 표현할 수 있다. 속도는 상황에 따라 다르고 컴파일러가 최적화하면 차이가 없는 경우가 많다. 참조도 포인터도 타입 제한이 따로 없고, 둘 다 매개변수로 쓸 수 있다.
}
}

@Reflection(id: cpp-pointers-reflection) {
@Prompt(id: null-deref-risk) {
nullptr 를 검사하지 않고 포인터를 역참조하면 어떤 문제가 생길 수 있을지 적어 보세요.
}

@Prompt(id: when-pointer-needed) {
포인터 대신 참조를 쓸 수 없는 상황은 어떤 경우일지 생각해 보세요.
}
}
