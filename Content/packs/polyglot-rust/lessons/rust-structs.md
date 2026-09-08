@Concept(id: rust-structs-concept) {
지금까지는 정수·문자열·벡터처럼 언어가 미리 준비해 둔 타입만 썼다. `struct` 는 관련 있는 값 여러 개를 하나의 이름 아래 묶어 나만의 타입을 만드는 문법이다. 직사각형의 가로와 세로처럼 항상 같이 다니는 값들을 따로따로 변수 두 개로 들고 다니는 대신, `Rectangle` 이라는 타입 하나로 묶으면 함수 시그니처도 짧아지고 "이 둘은 한 세트" 라는 의도도 코드에 그대로 드러난다.

`impl` 블록은 그 타입에 딸린 함수를 모아두는 자리다. 그중 `&self` 를 첫 매개변수로 받는 함수를 **메서드**라고 부르고, `rect.area()` 처럼 점 문법으로 호출한다. `&self` 는 "이 메서드를 호출한 바로 그 인스턴스를 빌려온다" 는 뜻이다 — 값을 복사하거나 소유권을 가져오지 않고 읽기만 하겠다는 선언이다.

반면 `self` 를 매개변수로 받지 않는 함수, 이를테면 `Rectangle::new(3, 4)` 의 `new` 는 **연관 함수**라고 부른다. 인스턴스가 아직 없는 상태에서 인스턴스를 만들어 내야 하니, 애초에 빌려올 `self` 가 없는 것이 당연하다. 연관 함수는 `타입이름::함수이름` 으로 호출한다는 점이 메서드와 다르다.

생성자로 쓰이는 함수의 이름이 꼭 `new` 여야 하는 것은 아니다 — `new` 는 관례일 뿐 언어가 강제하는 이름이 아니다. 다만 대부분의 러스트 코드가 이 관례를 따르므로, 낯선 타입을 볼 때 `new` 부터 찾아보면 생성자를 빨리 찾을 수 있다.
}

@Example(id: rust-structs-example, language: rust, expected: expected/rust-structs.txt) {
필드 두 개를 가진 구조체를 정의하고, 연관 함수로 인스턴스를 만든 뒤 필드와 메서드를 각각 읽어 본다.

```rust
struct Rectangle {
    width: i32,
    height: i32,
}

impl Rectangle {
    fn new(width: i32, height: i32) -> Rectangle {
        Rectangle { width, height }
    }

    fn area(&self) -> i32 {
        self.width * self.height
    }
}

fn main() {
    let rect = Rectangle::new(3, 4);
    println!("가로: {}", rect.width);
    println!("넓이: {}", rect.area());
}
```
}

@Blank(id: rust-structs-blank, language: rust) {
연관 함수로 인스턴스를 만드는 부분과 필드를 읽는 부분을 채워 완성하자.

```rust
struct Counter {
    value: i32,
}

impl Counter {
    fn new() -> Counter {
        Counter { value: 0 }
    }

    fn increment(&mut self) {
        self.value += 1;
    }
}

fn main() {
    let mut c = ___1___::new();
    c.increment();
    c.increment();
    println!("값: {}", c.___2___);
}
```

@Answer(slot: 1) {
`Counter`
}

@Answer(slot: 2) {
`value`
}
}

@Task(id: rust-structs-task, language: rust, starter: starters/rust-structs.rs, tests: tests/rust-structs.rs, solution: solutions/rust-structs.rs) {
직사각형을 나타내는 구조체 `Rectangle` 이 주어져 있다. 연관 함수 `new(width, height)` 는 이미 완성돼 있다. 나머지 두 메서드를 완성하라. `area` 는 넓이(width * height)를, `is_square` 는 width 와 height 가 같으면 `true`, 다르면 `false` 를 돌려준다. 변의 길이가 0 이어도 정상적으로 계산돼야 한다.

@Hint {
메서드 안에서는 self.width, self.height 처럼 self. 을 붙여 필드에 접근한다.
}

@Hint {
area 는 곱셈 한 줄이면 충분하다.
}

@Hint {
is_square 는 두 필드를 == 로 비교한 결과를 그대로 돌려주면 된다.
}
}

@Quiz(id: rust-structs-quiz, answer: move) {
@Question {
메서드 정의에서 `&self` 대신 `self` 를 받으면 (예: `fn consume(self)`) 무엇이 달라지는가?
}

@Choice(id: move) {
호출할 때 인스턴스의 소유권이 메서드로 이동해, 그 뒤로 원래 변수를 쓸 수 없다
}

@Choice(id: error) {
self 는 항상 &self 로 취급되므로 아무 차이가 없다
}

@Choice(id: readonly) {
self 를 받으면 필드를 절대 읽을 수 없게 된다
}

@Choice(id: static) {
self 를 받으면 그 함수는 연관 함수가 되어 인스턴스 없이 호출된다
}

@Explanation {
`self` 를 값으로 받으면 다른 함수에 값을 넘길 때와 똑같이 소유권이 이동한다 — 호출이 끝나면 원래 있던 변수는 더 이상 유효하지 않다. `&self` 는 그 값을 빌리기만 하므로 메서드가 끝나도 원래 변수를 계속 쓸 수 있다. self 를 받든 안 받든 필드는 그대로 읽을 수 있고, self 를 아예 받지 않아야 연관 함수가 된다는 점도 다르다.
}
}

@Reflection(id: rust-structs-reflection) {
@Prompt(id: why-associated-fn) {
`new` 는 왜 &self 를 받는 메서드가 아니라 연관 함수여야 할까요? 인스턴스를 만들어 내는 함수가 그 인스턴스 자체를 미리 빌려올 수 없는 이유를 적어 보세요.
}

@Prompt(id: grouping-vs-separate) {
width 와 height 를 struct 로 묶지 않고 두 변수로 따로 들고 다녔다면 함수 시그니처와 호출 코드가 어떻게 달라졌을지 생각해 보세요.
}
}
