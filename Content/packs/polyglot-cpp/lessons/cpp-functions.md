@Concept(id: cpp-functions-concept) {
함수는 반환 타입·이름·매개변수 목록으로 시그니처를 이루고, 그 아래 중괄호 안에 실제 동작을 담는다. 호출하는 쪽은 이름과 매개변수 타입만 맞추면 되고 내부 구현은 몰라도 되므로, 여러 곳에서 같은 로직을 반복해 적지 않고 한 곳에 모아 둘 수 있다.

매개변수를 보통 방식으로 받으면(값 전달) 함수 안의 변수는 호출한 쪽 변수의 복사본이다. 함수 안에서 그 값을 바꿔도 복사본만 바뀔 뿐, 호출한 쪽의 원래 변수는 전혀 영향을 받지 않는다. 이것이 C++ 의 기본 동작인 이유는 안전함 때문이다 — 함수를 호출하는 쪽은 특별히 표시하지 않는 한 자신의 변수가 함수 내부에서 건드려지지 않으리라 믿을 수 있다.

반면 매개변수를 참조(`&`)로 받으면 함수 안의 이름은 호출한 쪽 변수의 또 다른 이름이 된다 — 앞에서 본 참조와 똑같은 원리다. 함수 안에서 그 이름을 통해 값을 바꾸면 호출한 쪽의 원래 변수도 함께 바뀐다. 복사를 피하면서 값을 읽기만 하고 싶다면 `const T&` 로 받아, 별명은 만들되 그 별명을 통한 수정은 막을 수도 있다.

매개변수 선언에 `= 값` 을 붙이면 기본 인자가 된다. 호출할 때 그 인자를 생략하면 선언에 적어 둔 값이 대신 쓰인다. 기본 인자는 매개변자 목록의 뒤쪽에서부터만 줄 수 있는데, 그렇지 않으면 어떤 인자를 생략한 것인지 호출하는 쪽에서 알 방법이 없기 때문이다 — 앞쪽 인자를 생략하고 뒤쪽만 넘기는 방법은 없다.
}

@Example(id: cpp-functions-example, language: cpp, expected: expected/cpp-functions.txt) {
같은 모양의 두 함수를 값 전달과 참조 전달로 각각 만들어 결과를 비교하고, 기본 인자가 있는 power 를 두 방식으로 호출한다.

```cpp
#include <iostream>

void incrementByValue(int n) {
    n += 1;
}

void incrementByReference(int& n) {
    n += 1;
}

int power(int base, int exponent = 2) {
    int result = 1;
    for (int i = 0; i < exponent; ++i) {
        result *= base;
    }
    return result;
}

int main() {
    int a = 5;
    incrementByValue(a);
    std::cout << "값 전달 후 a: " << a << std::endl;

    int b = 5;
    incrementByReference(b);
    std::cout << "참조 전달 후 b: " << b << std::endl;

    std::cout << "power(3): " << power(3) << std::endl;
    std::cout << "power(3, 3): " << power(3, 3) << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-functions-blank, language: cpp) {
score 를 참조로 받도록, bonus 의 기본값을 10으로 채워 완성하자.

```cpp
#include <iostream>

void addBonus(int ___1___ score, int bonus = ___2___) {
    score += bonus;
}

int main() {
    int s1 = 50;
    addBonus(s1);
    std::cout << "s1=" << s1 << std::endl;

    int s2 = 50;
    addBonus(s2, 20);
    std::cout << "s2=" << s2 << std::endl;

    return 0;
}
```

@Answer(slot: 1) {
`&`
}

@Answer(slot: 2) {
`10`
}
}

@Task(id: cpp-functions-task, language: cpp, starter: starters/cpp-functions.cpp, tests: tests/cpp-functions.cpp, solution: solutions/cpp-functions.cpp) {
가격을 참조로 받아 할인율만큼 깎는 함수 `applyDiscount` 를 완성하라. 두 번째 매개변수 `rate` 는 기본값 0.25(25%)를 갖는 기본 인자여야 한다. `applyDiscount(price)` 처럼 rate 를 생략하면 25% 를 깎고, `applyDiscount(price, 0.5)` 처럼 명시하면 그 비율만큼 깎는다. price 는 참조로 받으므로 함수 호출 뒤 원래 변수의 값이 직접 바뀌어 있어야 한다. rate 가 0이면 가격은 그대로여야 한다.

@Hint {
매개변수 선언에서 rate 뒤에 `= 0.25` 를 붙이면 기본 인자가 된다.
}

@Hint {
price 는 참조(&)로 받아야 함수 밖의 변수가 실제로 바뀐다.
}

@Hint {
price = price * (1.0 - rate); 로 한 번에 계산할 수 있다.
}
}

@Quiz(id: cpp-functions-quiz, answer: a-one-b-99) {
@Question {
`void f1(int n) { n = 99; }` 와 `void f2(int& n) { n = 99; }` 가 있다. `int a = 1; f1(a); int b = 1; f2(b);` 를 실행한 뒤 a 와 b 는 각각 무엇일까요?
}

@Choice(id: a-one-b-99) {
a는 1 그대로이고, b는 99가 된다
}

@Choice(id: both-99) {
a와 b 모두 99가 된다
}

@Choice(id: both-one) {
a와 b 모두 1 그대로다
}

@Choice(id: a-99-b-one) {
a는 99가 되고, b는 1 그대로다
}

@Explanation {
f1 은 값을 전달받으므로 매개변수 n 은 a 의 복사본이다. 함수 안에서 그 복사본을 99로 바꿔도 원본 a 에는 영향이 없어 a 는 그대로 1이다. f2 는 참조를 전달받으므로 n 은 b 의 또 다른 이름이고, n 을 99로 바꾸는 것은 곧 b 를 바꾸는 것이라 b 는 99가 된다.
}
}

@Reflection(id: cpp-functions-reflection) {
@Prompt(id: value-default-safety) {
값 전달을 기본으로 하고 필요할 때만 참조 전달을 선택하는 C++ 의 설계가 안전성 면에서 어떤 장점을 준다고 생각하나요?
}

@Prompt(id: trailing-default-args) {
기본 인자를 매개변수 목록의 뒤쪽에서부터만 줄 수 있다는 규칙이 왜 필요한지, 앞쪽 인자를 생략하려 한다면 어떤 문제가 생길지 적어 보세요.
}
}
