@Concept(id: cpp-inheritance-concept) {
`class Dog : public Animal` 은 Dog 가 Animal 이 가진 멤버를 물려받는다는 뜻이다. Animal 의 생성자·멤버 변수·멤버 함수를 Dog 가 다시 쓸 수 있고, Dog 만의 멤버를 추가로 가질 수도 있다. 여러 클래스가 공통으로 갖는 것을 기반 클래스에 한 번만 적어 두고, 각자 다른 부분만 파생 클래스에 적는 식으로 중복을 줄인다.

`virtual` 은 함수 앞에 붙어 "이 함수는 실제 객체의 타입에 따라 다르게 실행될 수 있다" 는 표시다. `Animal* pet = new Dog(...)` 처럼 기반 클래스 포인터가 파생 클래스 객체를 가리키고 있어도, `pet->speak()` 를 부르면 포인터의 선언 타입(Animal)이 아니라 실제로 가리키는 객체의 타입(Dog)에 맞는 함수가 실행된다. 파생 클래스에서 이 함수를 다시 정의할 때는 `override` 를 붙여 준다 — 시그니처가 기반 클래스와 정확히 일치하는지 컴파일러가 검사해 주므로, 오타로 새로운 함수를 만들어 버리는 실수를 막아 준다.

소멸자도 virtual 로 선언해야 하는 이유가 여기 있다. `delete pet;` 을 부를 때 pet 의 정적 타입은 Animal 이지만 가리키는 객체는 Dog 다. Animal 의 소멸자가 virtual 이 아니라면 Animal 부분만 정리되고 Dog 가 추가로 관리하는 자원은 그대로 남는다. virtual 로 선언해 두면 delete 가 실제 타입(Dog)의 소멸자부터 시작해서 기반 클래스까지 순서대로 정리해 준다.

예제에서 Dog 를 생성하고 소멸시키는 순서를 눈여겨보라. 생성은 기반 클래스(Animal)부터, 소멸은 파생 클래스(Dog)부터 시작한다 — 항상 "만들어질 때는 바깥에서 안으로, 사라질 때는 안에서 바깥으로" 순서가 뒤집힌다.
}

@Example(id: cpp-inheritance-example, language: cpp, expected: expected/cpp-inheritance-and-virtual.txt) {
Dog 가 Animal 을 상속하고 speak 를 재정의한 뒤, 기반 클래스 포인터로 다루면서 생성·소멸 순서를 확인한다.

```cpp
#include <iostream>
#include <string>

class Animal {
public:
    explicit Animal(const std::string& name) : name_(name) {
        std::cout << name_ << " (Animal) 생성" << std::endl;
    }
    virtual ~Animal() {
        std::cout << name_ << " (Animal) 소멸" << std::endl;
    }
    virtual std::string speak() const {
        return name_ + ": ...";
    }
protected:
    std::string name_;
};

class Dog : public Animal {
public:
    explicit Dog(const std::string& name) : Animal(name) {
        std::cout << name_ << " (Dog) 생성" << std::endl;
    }
    ~Dog() override {
        std::cout << name_ << " (Dog) 소멸" << std::endl;
    }
    std::string speak() const override {
        return name_ + ": 멍멍";
    }
};

int main() {
    Animal* pet = new Dog("바둑이");
    std::cout << pet->speak() << std::endl;
    delete pet;

    return 0;
}
```
}

@Blank(id: cpp-inheritance-blank, language: cpp) {
기반 클래스의 재정의 가능 표시, 상속 문법, 재정의 표시를 채워 완성하자.

```cpp
#include <iostream>
#include <string>

class Shape {
public:
    ___1___ std::string describe() const {
        return "도형";
    }
    virtual ~Shape() {}
};

class Circle ___2___ Shape {
public:
    std::string describe() const ___3___ {
        return "원";
    }
};

int main() {
    Shape* shape = new Circle();
    std::cout << shape->describe() << std::endl;
    delete shape;
    return 0;
}
```

@Answer(slot: 1) {
`virtual`
}

@Answer(slot: 2) {
`: public`
}

@Answer(slot: 3) {
`override`
}
}

@Task(id: cpp-inheritance-task, language: cpp, starter: starters/cpp-inheritance-and-virtual.cpp, tests: tests/cpp-inheritance-and-virtual.cpp, solution: solutions/cpp-inheritance-and-virtual.cpp) {
직원 등급별 보너스를 계산하는 두 파생 클래스를 완성하라. 기반 클래스 `Employee` 는 이미 주어졌고 `bonus()` 는 항상 0을 돌려준다. `Manager` 는 `salary` 의 10%(정수 나눗셈, 소수점 이하 버림)를, `Intern` 은 `salary` 와 무관하게 항상 `50000` 을 보너스로 돌려주도록 `override` 하라.

@Hint {
override 는 시그니처가 기반 클래스와 정확히 같아야 붙는다.
}

@Hint {
정수 나눗셈은 소수점 이하를 자동으로 버린다 — salary_ / 10.
}

@Hint {
Intern::bonus() 는 salary_ 를 아예 쓰지 않아도 된다.
}
}

@Quiz(id: cpp-inheritance-quiz, answer: slice) {
@Question {
Employee 의 소멸자를 virtual 로 선언하지 않으면 어떤 문제가 생기나요?
}

@Choice(id: slice) {
Employee* 로 파생 객체를 delete 할 때 파생 클래스의 소멸자가 호출되지 않을 수 있다
}

@Choice(id: compile-error) {
파생 클래스를 정의하는 즉시 컴파일 오류가 난다
}

@Choice(id: no-override) {
bonus() 를 override 할 수 없게 된다
}

@Choice(id: faster) {
가상 소멸자가 없으면 프로그램이 더 빨리 실행된다는 차이만 있다
}

@Explanation {
소멸자가 virtual 이 아니면 기반 클래스 포인터를 통해 delete 할 때 정적 타입(Employee)의 소멸자만 호출되고 파생 클래스(Manager, Intern)의 소멸자는 건너뛴다 — 파생 클래스가 추가로 관리하는 자원이 있다면 그대로 샌다. 컴파일은 문제없이 되고, override 자체는 소멸자의 virtual 여부와 무관하며, 실행 속도 차이는 이 문제의 핵심이 아니다.
}
}

@Reflection(id: cpp-inheritance-reflection) {
@Prompt(id: static-vs-dynamic-type) {
Employee 대신 Manager 객체를 직접 다룰 때와, Employee* 로 다룰 때 bonus() 호출 결과가 달라지는 이유를 적어 보세요.
}

@Prompt(id: add-new-role) {
새로운 직급(예: Director)을 추가한다면 기존 코드를 얼마나 고쳐야 할지 생각해 보세요.
}
}
