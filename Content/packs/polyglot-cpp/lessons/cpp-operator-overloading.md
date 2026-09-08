@Concept(id: cpp-operator-concept) {
`std::string a = "가"; std::string b = "나"; a + b` 는 문자열을 이어 붙인다 — `+` 가 정수에서는 덧셈이지만 문자열에서는 이어 붙이기로 동작한다. 이것이 연산자 오버로딩이다: 자신이 만든 타입에도 `+`, `==`, `<<` 같은 연산자를 원하는 뜻으로 정의할 수 있다. `cpp.hello-and-cout` 에서 본 `std::cout << x` 의 `<<` 도 원래 비트 시프트였던 연산자가 출력 스트림에 대해 다시 정의된 예다.

멤버 함수로 연산자를 정의하면 `operator+(const T& other) const` 처럼 쓴다. 이름이 `operator+` 라는 것만 빼면 평범한 멤버 함수다 — `a + b` 라는 코드는 컴파일러가 `a.operator+(b)` 로 바꿔 부르는 것과 같다. `operator==` 도 마찬가지로 `bool operator==(const T& other) const` 형태로 정의해 두 값의 대소·동등을 비교한다.

`operator<<` 는 조금 다르다. `std::cout << obj` 는 `std::cout.operator<<(obj)` 가 아니라 `operator<<(std::cout, obj)` 로 해석된다 — 왼쪽 피연산자가 `std::cout` 이지 `obj` 가 아니기 때문에, 멤버 함수가 아니라 클래스 밖의 독립 함수(free function)로 정의한다: `std::ostream& operator<<(std::ostream& out, const T& value) { out << ...; return out; }`. `std::ostream&` 를 반환하는 이유는 `std::cout << a << b` 처럼 이어 쓸 수 있게 하기 위해서다.

연산자를 오버로딩할 때는 그 연산자가 원래 갖던 뜻에서 크게 벗어나지 않아야 한다 — `+` 는 "두 값을 합친다"는 느낌을, `==` 는 "내용이 같다"는 느낌을 유지해야 코드를 읽는 사람이 놀라지 않는다. 모든 연산자를 오버로딩할 필요도 없다 — 그 타입에서 자연스러운 의미가 있는 연산자만 정의하면 된다.
}

@Example(id: cpp-operator-example, language: cpp, expected: expected/cpp-operator-overloading.txt) {
2차원 벡터를 표현하는 클래스에 +, ==, << 를 정의해 자연스러운 표현식으로 다룬다.

```cpp
#include <iostream>

class Vec2 {
 public:
    Vec2(int x, int y) : x_(x), y_(y) {}

    Vec2 operator+(const Vec2& other) const {
        return Vec2(x_ + other.x_, y_ + other.y_);
    }

    bool operator==(const Vec2& other) const {
        return x_ == other.x_ && y_ == other.y_;
    }

    int getX() const { return x_; }
    int getY() const { return y_; }

 private:
    int x_;
    int y_;
};

std::ostream& operator<<(std::ostream& out, const Vec2& v) {
    out << "(" << v.getX() << ", " << v.getY() << ")";
    return out;
}

int main() {
    Vec2 a(1, 2);
    Vec2 b(3, 4);

    Vec2 sum = a + b;
    std::cout << a << " + " << b << " = " << sum << std::endl;

    Vec2 c(1, 2);
    std::cout << "a == c: " << (a == c) << std::endl;
    std::cout << "a == b: " << (a == b) << std::endl;

    return 0;
}
```
}

@Blank(id: cpp-operator-blank, language: cpp) {
두 값이 같은지 비교하는 연산자 멤버 함수의 선언을 채워 완성하자.

```cpp
#include <iostream>

class Money {
 public:
    Money(int cents) : cents_(cents) {}

    bool operator___1___(const Money& other) const {
        return cents_ ___2___ other.cents_;
    }

 private:
    int cents_;
};

int main() {
    Money a(100);
    Money b(100);
    std::cout << (a == b) << std::endl;
    return 0;
}
```

@Answer(slot: 1) {
`==`
}

@Answer(slot: 2) {
`==`
}
}

@Task(id: cpp-operator-task, language: cpp, starter: starters/cpp-operator-overloading.cpp, tests: tests/cpp-operator-overloading.cpp, solution: solutions/cpp-operator-overloading.cpp) {
분수를 표현하는 클래스 `Fraction` 을 완성하라. `Fraction` 은 생성자 `Fraction(int num, int den)` 으로 분자·분모를 받는다(선언은 이미 있고 필드도 채워져 있다고 가정하지 않는다 — 생성자에서 직접 채워라). `den` 이 0이면 `std::invalid_argument` 를 던진다. `operator+(const Fraction& other) const` 는 `a/b + c/d = (a*d + c*b) / (b*d)` 공식으로 두 분수를 더한 새 `Fraction` 을 반환한다(기약분수로 줄이지 않아도 된다). `operator==(const Fraction& other) const` 는 `분자1 * 분모2 == 분자2 * 분모1` 로 두 분수가 같은 값을 나타내는지 비교한다(예: 1/2 와 2/4 는 같다). `getNumerator() const` 와 `getDenominator() const` 는 각각 분자·분모를 그대로 돌려준다. 클래스 밖에 `std::ostream& operator<<(std::ostream&, const Fraction&)` 도 정의해 `분자/분모` 형식(예: `3/4`)으로 출력해라.

@Hint {
생성자는 den 검사를 먼저 하고 나서 num_·den_ 을 채워라.
}

@Hint {
operator+ 는 공식 (a*d + c*b) / (b*d) 를 그대로 옮겨서 새 Fraction 을 만들어 return 해라.
}

@Hint {
operator<< 는 f.getNumerator() 와 f.getDenominator() 사이에 '/' 를 끼워 out 에 흘려보내고 out 을 돌려줘야 한다.
}
}

@Quiz(id: cpp-operator-quiz, answer: left-operand-is-stream) {
@Question {
자신이 만든 클래스 T 에 대해 std::cout << obj 가 동작하게 하려는 operator<< 를 T 의 멤버 함수가 아니라 클래스 밖의 독립 함수로 정의하는 이유는?
}

@Choice(id: left-operand-is-stream) {
std::cout << obj 는 obj.operator<<(...) 가 아니라 왼쪽 피연산자인 std::cout 을 기준으로 해석되기 때문이다
}

@Choice(id: faster) {
독립 함수가 멤버 함수보다 항상 실행 속도가 빠르기 때문이다
}

@Choice(id: member-forbidden) {
operator<< 는 C++ 문법상 멤버 함수로 정의하는 것이 아예 금지되어 있기 때문이다
}

@Choice(id: avoids-private) {
private 필드를 읽을 수 있는 유일한 방법이기 때문이다
}

@Explanation {
a << b 형태의 이항 연산자를 멤버 함수로 정의하면 왼쪽 피연산자(a)의 멤버여야 한다. std::cout << obj 에서 왼쪽은 std::cout(std::ostream)이지 obj 가 아니므로, obj 의 클래스에 멤버로 넣어서는 이 표현식을 받을 수 없다 — 그래서 두 인자를 모두 받는 독립 함수로 정의한다. 실행 속도나 문법상 금지와는 무관하고, private 필드는 getter 를 쓰거나 friend 선언으로 접근하지 독립 함수라서 저절로 되는 것이 아니다.
}
}

@Reflection(id: cpp-operator-reflection) {
@Prompt(id: natural-meaning) {
Fraction 에 operator- 나 operator* 를 추가한다면 어떤 공식을 써야 할지, 그리고 반대로 Fraction 에 operator[] 를 정의하는 것이 왜 어색할지 생각해 보세요.
}

@Prompt(id: equality-without-reduction) {
이번 과제의 operator== 은 분수를 기약분수로 줄이지 않고도 1/2 와 2/4 를 같다고 판단합니다. 그 비교 공식(분자1*분모2 == 분자2*분모1)이 왜 성립하는지 자기 말로 설명해 보세요.
}
}
