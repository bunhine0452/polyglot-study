@Concept(id: cpp-smartptr-concept) {
`new`/`delete` 를 직접 짝지어 쓰는 방식은 짝을 놓치기 쉽다는 약점이 있었다. `std::unique_ptr` 은 그 짝짓기를 타입 안에 넣어 버린다 — `std::unique_ptr<Resource> owner = std::make_unique<Resource>(...)` 로 만들면, `owner` 가 스코프를 벗어나는 순간 소멸자가 자동으로 `delete` 를 대신 불러 준다. `new` 를 직접 쓰지 않고 `std::make_unique` 를 쓰는 이유는, 할당과 소유권 넘기기 사이에 예외가 끼어들 여지를 없애 더 안전하기 때문이다.

`unique_ptr` 이라는 이름 그대로, 이 포인터가 가리키는 자원의 소유자는 오직 하나뿐이다. 그래서 복사할 수 없다 — 복사를 허용하면 소유자가 둘이 되고, 둘 다 소멸자에서 같은 메모리를 `delete` 하려다 문제가 생긴다. 소유권을 다른 곳으로 넘기고 싶다면 `std::move` 로 **이동**해야 하고, 이동한 뒤 원래 포인터는 비워진다(nullptr 가 된다).

하지만 소유자가 여럿이어야 하는 경우도 있다. 같은 자원을 캐시에도 넣고 다른 객체에도 넘겨주고 싶은데, 누가 마지막으로 쓰고 있는지 미리 알 수 없는 상황이다. 이때 쓰는 것이 `std::shared_ptr` 이다. 내부에 참조 개수를 들고 있다가, 복사될 때마다 개수를 늘리고 스코프를 벗어날 때마다 줄이며, 개수가 0이 될 때 비로소 자원을 해제한다.

기본은 `unique_ptr` 이다 — 소유자가 하나뿐이라는 사실이 코드에 분명히 드러나고 참조 개수를 관리하는 비용도 없다. 정말로 여러 곳이 소유권을 나눠 가져야 할 때만 `shared_ptr` 로 바꾼다.
}

@Example(id: cpp-smartptr-example, language: cpp, expected: expected/cpp-smart-pointers.txt) {
unique_ptr 하나가 자원을 전담하는 모습과, shared_ptr 을 복사할 때 참조 개수가 오르내리는 모습을 함께 본다.

```cpp
#include <iostream>
#include <memory>
#include <string>

class Resource {
public:
    explicit Resource(const std::string& name) : name_(name) {
        std::cout << name_ << " 생성됨" << std::endl;
    }
    ~Resource() {
        std::cout << name_ << " 소멸됨" << std::endl;
    }
    void use() const {
        std::cout << name_ << " 사용 중" << std::endl;
    }
private:
    std::string name_;
};

int main() {
    std::unique_ptr<Resource> owner = std::make_unique<Resource>("단독 소유");
    owner->use();

    std::shared_ptr<Resource> shared1 = std::make_shared<Resource>("공유 자원");
    {
        std::shared_ptr<Resource> shared2 = shared1;
        std::cout << "참조 개수: " << shared1.use_count() << std::endl;
        shared2->use();
    }
    std::cout << "블록 벗어난 뒤 참조 개수: " << shared1.use_count() << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-smartptr-blank, language: cpp) {
단독 소유 포인터의 타입, 역참조 연산자, 참조 개수를 묻는 멤버 함수를 채워 완성하자.

```cpp
#include <iostream>
#include <memory>

int main() {
    std::___1___<int> value = std::make_unique<int>(10);
    std::cout << ___2___value << std::endl;

    std::shared_ptr<int> shared = std::make_shared<int>(5);
    std::cout << shared.___3___() << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`unique_ptr`
}

@Answer(slot: 2) {
`*`
}

@Answer(slot: 3) {
`use_count`
}
}

@Task(id: cpp-smartptr-task, language: cpp, starter: starters/cpp-smart-pointers.cpp, tests: tests/cpp-smart-pointers.cpp, solution: solutions/cpp-smart-pointers.cpp) {
`source` 가 가진 값의 소유권을 가져와 돌려주는 함수 `takeOwnership` 을 완성하라. `std::move` 로 소유권을 옮겨야 하며, 옮기고 난 뒤에는 `source` 가 아무것도 가리키지 않아야 한다(`nullptr`). `source` 가 이미 비어 있다면 빈 상태 그대로 돌려주면 된다.

@Hint {
std::move 는 값을 복사하지 않고 소유권만 옮긴다.
}

@Hint {
unique_ptr 는 복사할 수 없다 — return 문에서도 std::move 가 필요하다.
}

@Hint {
옮기고 난 source 는 비어 있는(nullptr) 상태가 된다.
}
}

@Quiz(id: cpp-smartptr-quiz, answer: ownership) {
@Question {
shared_ptr 대신 unique_ptr 을 기본으로 선택해야 하는 이유는?
}

@Choice(id: ownership) {
소유자가 하나뿐이라는 것이 코드에서 분명해지고, 참조 카운트 비용도 없다
}

@Choice(id: more-features) {
unique_ptr 은 항상 shared_ptr 보다 더 많은 기능을 제공한다
}

@Choice(id: copyable) {
unique_ptr 은 자유롭게 복사할 수 있어 더 편리하다
}

@Choice(id: not-supported) {
shared_ptr 은 컴파일러가 지원하지 않는 경우가 있다
}

@Explanation {
unique_ptr 은 복사할 수 없고 이동만 가능해 소유자가 정확히 하나임을 타입으로 보장하고, 참조 카운트를 유지할 필요가 없어 오버헤드도 없다. shared_ptr 은 여러 곳에서 동시에 소유권을 나눠 가져야 할 때만 그 비용을 감수하고 쓴다. unique_ptr 이 기능적으로 더 많은 걸 제공하는 것도, 자유롭게 복사되는 것도 아니며 shared_ptr 은 표준 라이브러리 전체에서 지원된다.
}
}

@Reflection(id: cpp-smartptr-reflection) {
@Prompt(id: no-copy-clarity) {
unique_ptr 을 복사하려고 하면 컴파일 오류가 납니다. 이 제약이 왜 소유권을 명확하게 만드는지 적어 보세요.
}

@Prompt(id: when-shared-needed) {
여러 객체가 하나의 자원을 함께 참조해야 하는 상황을 하나 떠올려 shared_ptr 이 왜 필요한지 설명해 보세요.
}
}
