@Concept(id: cpp-class-concept) {
`struct` 의 필드는 기본이 `public` 이라 누구나 밖에서 자유롭게 읽고 바꿀 수 있다. 은행 계좌의 잔액처럼 "음수가 되면 안 된다" 같은 규칙을 지켜야 하는 값이라면, 아무나 `account.balance = -100;` 을 쓸 수 있는 구조는 위험하다. `class` 는 `struct` 와 문법이 거의 같지만 기본 접근 권한이 `private` 이라는 점이 다르다 — 이 차이 하나로 "내부를 감춘다" 는 관용구를 표현한다.

`class Account { int balance; public: ... };` 처럼 쓰면 `balance` 는 클래스 밖에서 접근할 수 없다. 대신 `public:` 아래에 함수를 두어 그 함수를 통해서만 내부 값을 만지게 한다. 값을 읽게 해 주는 함수를 흔히 getter 라고 부르고(`int getBalance() const`), 바꾸게 해 주는 함수를 setter 라고 부른다. 클래스를 쓰는 이유는 단순히 숨기기 위해서가 아니라, 값이 바뀌는 통로를 함수 몇 개로 좁혀서 그 함수 안에서만 규칙을 검사하면 되게 만들기 위해서다.

생성자는 객체가 만들어지는 순간 호출되는 특별한 멤버 함수다. 이름이 클래스 이름과 같고 반환 타입이 없다(`Account(int initial) { ... }`). 생성자 안에서 필드를 초기값으로 채우면서 동시에 규칙을 검사할 수 있다 — 예를 들어 음수로 계좌를 열려는 시도를 생성자에서 막을 수 있다. 생성자가 없으면 컴파일러가 아무것도 안 하는 기본 생성자를 만들어 주는데, 그러면 필드가 초기화되지 않은 채로 남을 수 있어 위험하다.

`private` 은 캡슐화의 핵심이지만 만능은 아니다. getter·setter 를 모든 필드에 기계적으로 붙이기만 하면 `public` 필드와 다를 게 없다. 진짜 이점은 규칙이 있는 필드(잔액이 음수가 안 되는 것처럼)에 그 규칙을 강제하는 함수를 통해서만 접근하게 만드는 데 있다.
}

@Example(id: cpp-class-example, language: cpp, expected: expected/cpp-classes-and-encapsulation.txt) {
잔액이 음수가 되지 않도록 지키는 계좌 클래스를 만들고, 입금·출금을 거쳐 잔액을 확인한다.

```cpp
#include <iostream>

class Account {
 public:
    Account(int initial) {
        balance = (initial < 0) ? 0 : initial;
    }

    void deposit(int amount) {
        if (amount > 0) {
            balance += amount;
        }
    }

    bool withdraw(int amount) {
        if (amount <= 0 || amount > balance) {
            return false;
        }
        balance -= amount;
        return true;
    }

    int getBalance() const {
        return balance;
    }

 private:
    int balance;
};

int main() {
    Account acc(100);
    std::cout << "초기 잔액: " << acc.getBalance() << std::endl;

    acc.deposit(50);
    std::cout << "입금 후: " << acc.getBalance() << std::endl;

    bool ok = acc.withdraw(200);
    std::cout << "과도한 출금 결과: " << ok << std::endl;
    std::cout << "잔액 변화 없음: " << acc.getBalance() << std::endl;

    acc.withdraw(30);
    std::cout << "정상 출금 후: " << acc.getBalance() << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-class-blank, language: cpp) {
내부 필드를 감추고 생성자와 getter 로만 접근하게 만드는 부분을 채워 완성하자.

```cpp
#include <iostream>

class Counter {
 public:
    Counter(int start) {
        count = start;
    }

    void increment() {
        count++;
    }

    int getCount() const {
        return count;
    }

 ___1___:
    int ___2___;
};

int main() {
    Counter c(5);
    c.increment();
    std::cout << c.getCount() << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`private`
}

@Answer(slot: 2) {
`count`
}
}

@Task(id: cpp-class-task, language: cpp, starter: starters/cpp-classes-and-encapsulation.cpp, tests: tests/cpp-classes-and-encapsulation.cpp, solution: solutions/cpp-classes-and-encapsulation.cpp) {
재고를 관리하는 클래스 `Stock` 을 완성하라. `Stock` 은 `private` 필드 `int quantity` 를 갖는다(선언은 이미 있다). 생성자 `Stock(int initial)` 은 `initial` 이 음수면 0으로, 아니면 그 값으로 `quantity` 를 초기화한다. `add(int amount)` 는 `amount` 가 양수일 때만 `quantity` 에 더한다(음수·0 이면 아무 일도 하지 않는다). `remove(int amount)` 는 `amount` 가 양수이고 현재 `quantity` 이하일 때만 실제로 빼고 `true` 를 반환하며, 그렇지 않으면 아무것도 바꾸지 않고 `false` 를 반환한다. `getQuantity() const` 는 현재 수량을 반환한다.

@Hint {
생성자에서는 initial < 0 을 검사해서 quantity 를 결정해라.
}

@Hint {
remove 는 실패 조건(amount <= 0 이거나 amount > quantity)을 먼저 걸러서 false 로 빠르게 반환해라.
}

@Hint {
add 와 remove 모두 조건을 만족하지 않으면 quantity 를 아예 건드리지 않아야 한다.
}
}

@Quiz(id: cpp-class-quiz, answer: enforce-rules) {
@Question {
class 의 필드를 private 로 두고 getter·setter 함수로만 접근하게 만드는 이유로 가장 적절한 것은?
}

@Choice(id: enforce-rules) {
값이 바뀌는 통로를 함수 몇 개로 좁혀서 그 함수 안에서 규칙을 검사할 수 있게 하기 위해서다
}

@Choice(id: faster-runtime) {
private 필드는 public 필드보다 접근 속도가 빠르기 때문이다
}

@Choice(id: less-memory) {
private 필드는 메모리를 덜 차지하기 때문이다
}

@Choice(id: required-syntax) {
class 키워드를 쓰면 문법상 반드시 private 필드가 있어야 하기 때문이다
}

@Explanation {
캡슐화의 핵심은 성능이나 메모리가 아니라, 값이 바뀔 수 있는 경로를 함수로 좁혀서 그 함수 안에서 유효성 규칙(예: 잔액이 음수가 안 됨)을 강제할 수 있게 만드는 것이다. private 필드와 public 필드는 접근 속도나 메모리 사용에 차이가 없고, class 라고 해서 private 필드가 강제되는 것도 아니다(비워 두면 그냥 없는 것이다).
}
}

@Reflection(id: cpp-class-reflection) {
@Prompt(id: struct-vs-class) {
struct 와 class 는 기본 접근 권한만 다를 뿐 문법이 거의 같습니다. 언제 struct 를, 언제 class 를 쓰는 게 자연스러울지 자신의 기준을 적어 보세요.
}

@Prompt(id: getter-without-setter) {
Stock 클래스에는 quantity 를 직접 바꾸는 setter 가 없고 add·remove 만 있습니다. 만약 setQuantity(int) 를 추가한다면 지금까지 지켜온 어떤 규칙이 깨질 수 있을지 생각해 보세요.
}
}
