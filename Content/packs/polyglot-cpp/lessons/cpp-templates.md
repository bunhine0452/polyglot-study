@Concept(id: cpp-templates-concept) {
두 정수 중 큰 값을 구하는 함수와 두 double 중 큰 값을 구하는 함수는 타입만 다를 뿐 로직이 완전히 똑같다. 타입마다 똑같은 함수를 복사해 쓰는 대신, 템플릿은 타입 자체를 매개변수로 받는 함수를 한 번만 쓰게 해 준다: `template <typename T> T maxOf(T a, T b) { return (a > b) ? a : b; }`. `typename T` 는 "T 는 나중에 정해질 타입" 이라는 선언이고, 그 아래 함수는 T 를 마치 실제 타입처럼 쓴다.

호출할 때는 `maxOf(3, 5)` 처럼 평소 함수 부르듯 쓰면 된다. 컴파일러가 인자의 타입(`int`)을 보고 `T` 를 `int` 로 채워 그 버전의 함수를 그 자리에서 만들어 낸다 — 이를 템플릿 인스턴스화라고 한다. `maxOf(3.0, 5.0)` 처럼 double 로 부르면 `T = double` 버전이 따로 만들어진다. 즉 소스 코드는 하나지만 실제로 컴파일되는 함수는 호출된 타입마다 여러 개다.

클래스도 템플릿으로 만들 수 있다. `template <typename T> class Box { public: Box(T value) : content(value) {} T get() const { return content; } private: T content; };` 라고 정의하면 `Box<int>`, `Box<std::string>` 처럼 어떤 타입이든 담는 상자를 하나의 정의로 만들 수 있다. 사실 `std::vector<int>` 의 `<int>` 도 똑같은 클래스 템플릿 문법이다 — `std::vector` 자체가 클래스 템플릿이다.

템플릿 함수에 `T` 가 지원하지 않는 연산(예: `>` 가 없는 타입에 `maxOf` 를 쓰는 것)을 쓰면 컴파일 에러가 나는데, 메시지가 보통 인스턴스화된 지점과 템플릿 정의 양쪽을 함께 가리켜 길고 낯설게 보인다. 당황하지 말고 에러 메시지에서 "어떤 타입에 어떤 연산을 시도했는지"를 찾으면 원인을 짚을 수 있다.
}

@Example(id: cpp-templates-example, language: cpp, expected: expected/cpp-templates.txt) {
같은 함수 템플릿을 int 와 double 로 각각 호출하고, 클래스 템플릿으로 서로 다른 타입을 담는 상자를 만든다.

```cpp
#include <iostream>
#include <string>

template <typename T>
T maxOf(T a, T b) {
    return (a > b) ? a : b;
}

template <typename T>
class Box {
 public:
    Box(T value) : content(value) {}

    T get() const {
        return content;
    }

 private:
    T content;
};

int main() {
    std::cout << "maxOf(3, 5) = " << maxOf(3, 5) << std::endl;
    std::cout << "maxOf(2.5, 1.5) = " << maxOf(2.5, 1.5) << std::endl;

    Box<int> intBox(42);
    Box<std::string> strBox("안녕");

    std::cout << "intBox: " << intBox.get() << std::endl;
    std::cout << "strBox: " << strBox.get() << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-templates-blank, language: cpp) {
타입을 매개변수로 받는 함수 템플릿 선언을 채워 완성하자.

```cpp
#include <iostream>

___1___ <___2___ T>
T identity(T value) {
    return value;
}

int main() {
    std::cout << identity(7) << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`template`
}

@Answer(slot: 2) {
`typename`
}
}

@Task(id: cpp-templates-task, language: cpp, starter: starters/cpp-templates.cpp, tests: tests/cpp-templates.cpp, solution: solutions/cpp-templates.cpp) {
벡터에서 최댓값을 찾는 함수 템플릿 `maxIn` 과, 값 두 개를 짝지어 담는 클래스 템플릿 `Pair` 를 완성하라. `template <typename T> T maxIn(const std::vector<T>& values)` 는 `values` 의 최댓값을 돌려주되, `values` 가 비어 있으면 `std::invalid_argument` 를 던진다(`>` 연산자로 비교한다). `template <typename T> class Pair` 는 생성자 `Pair(T first, T second)` 로 두 값을 받아 `getFirst() const` 와 `getSecond() const` 로 각각 돌려준다. 템플릿이므로 정의를 그대로 헤더에 써야 한다.

@Hint {
maxIn 은 첫 원소로 best 를 초기화한 다음 나머지를 순회하며 > 로 비교해라.
}

@Hint {
Pair 의 생성자에서 초기화 목록(: firstValue(first), secondValue(second))으로 필드를 채워라.
}

@Hint {
getFirst·getSecond 는 그냥 해당 필드를 반환하기만 하면 된다.
}
}

@Quiz(id: cpp-templates-quiz, answer: two-versions) {
@Question {
template <typename T> T maxOf(T a, T b) { return (a > b) ? a : b; } 를 maxOf(3, 5) 와 maxOf(2.5, 1.5) 로 각각 호출했다. 실제로 컴파일되는 함수는 몇 개인가?
}

@Choice(id: two-versions) {
호출된 타입(int, double)마다 하나씩, 총 두 개의 서로 다른 함수가 만들어진다
}

@Choice(id: one-generic) {
타입에 상관없이 동작하는 함수 하나만 컴파일된다
}

@Choice(id: zero-until-run) {
실행 시점에 타입을 검사하므로 컴파일 시점에는 함수가 만들어지지 않는다
}

@Choice(id: one-per-file) {
이 함수가 쓰인 파일 하나당 함수 하나가 만들어진다
}

@Explanation {
템플릿은 호출될 때마다 그 타입에 맞는 실제 함수로 인스턴스화된다. maxOf(3, 5) 는 T=int 버전을, maxOf(2.5, 1.5) 는 T=double 버전을 컴파일 시점에 만들어 낸다 — 소스는 하나지만 결과물은 호출된 타입 수만큼 생긴다. C++ 템플릿은 실행 시점이 아니라 컴파일 시점에 타입이 정해지고, 파일 수와는 무관하다.
}
}

@Reflection(id: cpp-templates-reflection) {
@Prompt(id: copy-paste-vs-template) {
maxOf 를 int 버전과 double 버전으로 각각 손으로 복사해서 썼다면 나중에 버그를 고칠 때 무엇이 달라질지, 템플릿 하나로 관리하는 것과 비교해 적어 보세요.
}

@Prompt(id: template-error-messages) {
템플릿 함수에 지원하지 않는 타입을 넘겼을 때 에러 메시지가 왜 길고 낯설게 보이는지, 이번 레슨에서 읽은 설명을 바탕으로 자기 말로 정리해 보세요.
}
}
