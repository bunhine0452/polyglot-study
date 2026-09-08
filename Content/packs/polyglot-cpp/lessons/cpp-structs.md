@Concept(id: cpp-structs-concept) {
지금까지는 사람 한 명의 이름과 나이를 다루려면 변수 두 개(`std::string name`, `int age`)를 따로 들고 다녔다. 사람이 여러 명이면 벡터도 두 개가 되고, 몇 번째 이름이 몇 번째 나이와 짝인지는 인덱스로만 맞춰야 한다. `struct` 는 이렇게 서로 관련된 값들을 하나의 이름 아래 묶는 도구다.

`struct Person { std::string name; int age; };` 라고 정의하면 `Person` 이라는 새 타입이 생긴다. `Person p{"철수", 20};` 처럼 중괄호로 필드를 순서대로 채워 만들 수 있고, `p.name`·`p.age` 로 각 필드에 접근한다. 필드에 기본값을 줄 수도 있다(`int age = 0;`) — 그러면 그 필드를 생략해도 컴파일러가 기본값을 채운다.

`struct` 도 값 타입이다. 함수에 값으로 넘기면 필드 전체가 복사되고, 대입하면 필드 전체가 복사된다. 그래서 `cpp.pass-by-reference` 에서 본 것과 똑같은 규칙이 적용된다 — 읽기만 하는 함수라면 `const Person&` 으로 받는 것이 관용구다.

`struct` 안에는 함수도 넣을 수 있다. 이를 멤버 함수라고 부르는데, 멤버 함수 안에서는 그 구조체의 필드를 앞에 아무것도 안 붙이고 바로 쓸 수 있다. 예를 들어 `Person` 에 `std::string describe() const { return name + "(" + std::to_string(age) + ")"; }` 를 넣으면 `p.describe()` 로 호출한다. 끝에 붙는 `const` 는 이 멤버 함수가 필드를 바꾸지 않는다는 약속이다.
}

@Example(id: cpp-structs-example, language: cpp, expected: expected/cpp-structs.txt) {
이름과 점수를 묶은 struct 를 정의하고, 멤버 함수로 등급을 매긴 뒤 여러 개를 벡터에 담아 순회한다.

```cpp
#include <iostream>
#include <string>
#include <vector>

struct Student {
    std::string name;
    int score = 0;

    char grade() const {
        if (score >= 90) return 'A';
        if (score >= 80) return 'B';
        return 'C';
    }
};

int main() {
    Student a{"민수", 95};
    Student b{"영희", 83};
    Student c{"철수"};

    std::vector<Student> students = {a, b, c};
    for (const Student& s : students) {
        std::cout << s.name << ": " << s.score << "점, " << s.grade() << "등급" << std::endl;
    }

    return 0;
}
```
}

@Blank(id: cpp-structs-blank, language: cpp) {
좌표를 묶는 struct 를 정의하고 필드에 접근하는 부분을 채워 완성하자.

```cpp
#include <iostream>

struct Point {
    int x;
    int ___1___;
};

int main() {
    Point p{3, 4};
    std::cout << p.x << ", " << p.___2___ << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`y`
}

@Answer(slot: 2) {
`y`
}
}

@Task(id: cpp-structs-task, language: cpp, starter: starters/cpp-structs.cpp, tests: tests/cpp-structs.cpp, solution: solutions/cpp-structs.cpp) {
직사각형을 표현하는 struct `Rectangle` 을 만들고, 그 안에 넓이와 둘레를 구하는 멤버 함수를 채워라. `Rectangle` 은 필드 `double width` 와 `double height` 를 갖는다(선언은 이미 되어 있다). `area() const` 는 `width * height` 를, `perimeter() const` 는 `2 * (width + height)` 를 반환해야 한다. 둘 다 필드를 바꾸지 않으므로 `const` 멤버 함수다. `width` 또는 `height` 가 0 이하이면 `area()` 와 `perimeter()` 는 각각 0.0 을 반환한다.

@Hint {
멤버 함수 안에서는 width·height 를 this-> 없이 바로 쓸 수 있다.
}

@Hint {
0 이하인지 검사하는 조건을 area() 와 perimeter() 양쪽에 똑같이 넣어라.
}

@Hint {
두 함수 모두 필드를 읽기만 하니 const 를 그대로 남겨 둬라.
}
}

@Quiz(id: cpp-structs-quiz, answer: no-mutate) {
@Question {
struct 의 멤버 함수 끝에 붙이는 `const` (예: `double area() const { ... }`)는 무엇을 의미하는가?
}

@Choice(id: no-mutate) {
이 멤버 함수가 구조체의 필드를 바꾸지 않는다는 약속이다
}

@Choice(id: return-const) {
이 함수의 반환값을 상수로 만든다는 뜻이다
}

@Choice(id: compile-speed) {
컴파일 속도를 높이기 위한 최적화 지시어다
}

@Choice(id: no-params) {
이 함수가 매개변수를 받을 수 없다는 뜻이다
}

@Explanation {
멤버 함수 뒤의 const 는 그 함수 안에서 자신의 필드를 바꾸지 않겠다는 컴파일러 차원의 약속이다. 이 약속 덕분에 const 참조로 받은 객체에서도 그 함수를 호출할 수 있다. 반환 타입의 const 여부나 매개변수 개수와는 무관하고, 컴파일 속도와도 관계없다.
}
}

@Reflection(id: cpp-structs-reflection) {
@Prompt(id: two-vectors-vs-struct) {
이름과 나이를 벡터 두 개(std::vector<std::string>, std::vector<int>)로 따로 관리하는 것과 struct 하나로 묶어 벡터 하나로 관리하는 것, 어느 쪽이 실수하기 쉬울지 생각해 보세요.
}

@Prompt(id: default-values) {
필드에 기본값을 주지 않으면 어떤 위험이 있을지, 이번 예제의 Student{"철수"} 처럼 일부 필드만 채운 경우를 떠올리며 적어 보세요.
}
}
