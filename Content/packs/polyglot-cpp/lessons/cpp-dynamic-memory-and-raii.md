@Concept(id: cpp-raii-concept) {
`new` 는 힙에 메모리를 할당하고 그 주소를 가리키는 포인터를 돌려준다. `int* value = new int(42);` 는 정수 하나를 담을 공간을 만들고 42로 채운다. 이 메모리는 함수가 끝나도, 블록을 벗어나도 저절로 사라지지 않는다 — 스택 변수와 달리, 명시적으로 `delete value;` 를 불러야 회수된다.

문제는 `delete` 를 부르는 것을 잊기 쉽다는 데 있다. 함수 중간에 조기 반환이 있거나 예외가 던져지면 그 뒤에 있던 `delete` 는 실행되지 못하고 건너뛴다. 이렇게 회수되지 않은 메모리가 쌓이는 것을 메모리 누수라고 부른다. 프로그램이 오래 돌수록 누수는 계속 쌓이고, 결국 쓸 수 있는 메모리가 바닥난다 — 크래시하거나 컴파일 오류가 나는 것이 아니라 조용히 자원만 낭비되기 때문에 알아채기도 어렵다.

C++ 이 이 문제에 내놓은 답이 RAII(Resource Acquisition Is Initialization) 다. 자원을 얻는 일을 객체의 생성자에서 하고, 해제하는 일을 소멸자에서 하도록 묶어 두면, 그 객체가 스코프를 벗어나는 순간 컴파일러가 소멸자를 **반드시** 호출해 준다. 조기 반환이든 예외든 상관없다 — 스코프를 벗어나기만 하면 소멸자는 실행된다.

예제의 `Resource` 클래스가 이 패턴이다. 생성자가 자원을 얻었다는 뜻으로 메시지를 찍고, 블록을 벗어나면 소멸자가 자동으로 불려 해제 메시지를 찍는다. `delete` 를 어디서도 직접 부르지 않았는데도 정확한 시점에 정리가 일어난다는 점이 핵심이다.
}

@Example(id: cpp-raii-example, language: cpp, expected: expected/cpp-dynamic-memory-and-raii.txt) {
new/delete 를 직접 짝지어 쓰는 경우와, 소멸자가 스코프 종료 시 자동으로 불리는 RAII 패턴을 나란히 본다.

```cpp
#include <iostream>
#include <string>

class Resource {
public:
    Resource(const std::string& name) : name_(name) {
        std::cout << name_ << " 생성됨" << std::endl;
    }
    ~Resource() {
        std::cout << name_ << " 소멸됨" << std::endl;
    }
private:
    std::string name_;
};

int main() {
    int* value = new int(42);
    std::cout << "*value = " << *value << std::endl;
    delete value;

    {
        Resource r("자원");
        std::cout << "블록 안에서 사용 중" << std::endl;
    }
    std::cout << "블록을 벗어났다" << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-raii-blank, language: cpp) {
소멸자를 뜻하는 기호, 힙에 할당하는 키워드, 해제하는 키워드를 채워 완성하자.

```cpp
#include <iostream>

class Counter {
public:
    Counter() { std::cout << "카운터 생성" << std::endl; }
    ___1___Counter() { std::cout << "카운터 소멸" << std::endl; }
};

int main() {
    int* number = ___2___ int(7);
    std::cout << *number << std::endl;
    ___3___ number;

    Counter c;
    return 0;
}
```

@Answer(slot: 1) {
`~`
}

@Answer(slot: 2) {
`new`
}

@Answer(slot: 3) {
`delete`
}
}

@Task(id: cpp-raii-task, language: cpp, starter: starters/cpp-dynamic-memory-and-raii.cpp, tests: tests/cpp-dynamic-memory-and-raii.cpp, solution: solutions/cpp-dynamic-memory-and-raii.cpp) {
정수 배열을 `new[]` 로 관리하는 `DynamicArray` 클래스를 완성하라. 생성자는 `size` 개의 `int` 를 할당해 모두 0으로 채우고, 소멸자는 `delete[]` 로 해제한다. `set(index, value)` 는 지정한 자리에 값을 저장하고, `get(index)` 는 그 값을 돌려준다. `index` 가 `0` 미만이거나 `size` 이상이면 두 함수 모두 `std::out_of_range` 를 던져야 한다.

@Hint {
new int[size] 로 배열을 할당하고 for 문으로 0을 채운다.
}

@Hint {
delete[] 는 new[] 로 만든 배열에 짝을 맞춰 써야 한다.
}

@Hint {
index < 0 이거나 index >= size_ 면 std::out_of_range 를 던진다.
}
}

@Quiz(id: cpp-raii-quiz, answer: leak) {
@Question {
delete 를 빠뜨리고 함수를 빠져나가면 어떤 일이 생기나요?
}

@Choice(id: leak) {
그 메모리는 프로그램이 끝날 때까지 회수되지 않아 누수가 쌓인다
}

@Choice(id: crash) {
즉시 프로그램이 강제 종료된다
}

@Choice(id: auto) {
컴파일러가 대신 delete 를 호출해 준다
}

@Choice(id: compile-error) {
컴파일 오류가 난다
}

@Explanation {
new 로 할당한 메모리는 명시적으로 delete 하기 전까지 컴파일러가 알아서 해제해 주지 않는다. 빠뜨리면 그 블록은 회수되지 않고 프로그램이 오래 돌수록 누수가 쌓인다 — 크래시하거나 컴파일 오류가 나는 것이 아니라 조용히 자원만 낭비된다.
}
}

@Reflection(id: cpp-raii-reflection) {
@Prompt(id: exception-safety) {
RAII 를 쓰는 클래스는 소멸자에서 자원을 해제합니다. 예외가 던져져 함수를 빠져나갈 때도 소멸자가 호출되는 것이 왜 중요한지 적어 보세요.
}

@Prompt(id: raii-vs-manual) {
new/delete 를 직접 쓰는 대신 RAII 클래스를 쓰면 어떤 실수를 피할 수 있는지 생각해 보세요.
}
}
