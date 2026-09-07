@Concept(id: rust-enums-concept) {
값이 정해진 몇 가지 모양 중 딱 하나일 때가 있다 — 신호등은 빨강·노랑·초록 중 하나이고, 도형은 원이거나 직사각형이거나 둘 중 하나다. `enum` 은 이런 "여럿 중 하나" 를 타입으로 표현한다. `bool` 이 참·거짓 둘 중 하나를 표현하는 언어 내장 enum 이라고 생각하면 감이 잡힌다.

각 변형(variant)은 자기만의 값을 함께 들고 다닐 수 있다. `Shape::Circle(5)` 처럼 원은 반지름 하나를, `Shape::Rectangle(3, 4)` 처럼 직사각형은 가로·세로 두 값을 갖는 식이다. 변형마다 붙어 있는 이 값을 **연관 값**이라 부른다 — 같은 `Shape` 타입이라도 어떤 변형이냐에 따라 들고 있는 데이터의 모양이 다를 수 있다.

`match` 는 이 변형을 갈라서 처리하는 문법이다. `if`·`else` 를 여러 번 쓰는 것과 다른 점은, **모든 변형을 다뤄야 컴파일이 된다**는 것이다. 변형 하나를 깜빡 빠뜨리면 러스트는 실행해 볼 필요도 없이 컴파일 단계에서 바로 알려준다. 나중에 enum 에 변형을 하나 추가했을 때, 그 변형을 놓친 match 표현식들이 전부 컴파일 오류로 떠오르는 것도 같은 이유다.

모든 경우를 하나하나 적기 번거롭거나 나머지는 똑같이 처리해도 될 때는 `_` 와일드카드를 마지막 팔에 둔다. `_` 는 "앞에서 다루지 않은 나머지 전부" 를 뜻하며, 이 팔이 있으면 새 변형이 추가돼도 컴파일은 계속 된다 — 다만 그 새 변형을 정말 다른 값으로 처리해야 하는지는 사람이 챙겨야 한다.
}

@Example(id: rust-enums-example, language: rust, expected: expected/rust-enums-and-match.txt) {
연관 값이 없는 enum 은 와일드카드로, 연관 값이 있는 enum 은 각 변형에서 값을 꺼내는 패턴으로 match 한다.

```rust
enum Direction {
    North,
    South,
    East,
    West,
}

fn is_vertical(direction: &Direction) -> bool {
    match direction {
        Direction::North => true,
        Direction::South => true,
        _ => false,
    }
}

enum Shape {
    Circle(i32),
    Rectangle(i32, i32),
}

fn describe(shape: &Shape) -> String {
    match shape {
        Shape::Circle(radius) => format!("반지름 {} 인 원", radius),
        Shape::Rectangle(width, height) => format!("{} x {} 인 직사각형", width, height),
    }
}

fn main() {
    println!("북쪽은 세로 방향인가: {}", is_vertical(&Direction::North));
    println!("동쪽은 세로 방향인가: {}", is_vertical(&Direction::East));

    let shapes = vec![Shape::Circle(5), Shape::Rectangle(3, 4)];
    for shape in &shapes {
        println!("{}", describe(shape));
    }
}
```
}

@Blank(id: rust-enums-blank, language: rust) {
동전의 나머지 경우를 와일드카드로 묶어 값을 돌려주도록 채워 완성하자.

```rust
enum Coin {
    Penny,
    Nickel,
    Quarter,
}

fn value(coin: &Coin) -> i32 {
    match coin {
        Coin::Penny => 1,
        Coin::Nickel => 5,
        ___1___ => ___2___,
    }
}

fn main() {
    println!("{}", value(&Coin::Quarter));
}
```

@Answer(slot: 1) {
`_`
}

@Answer(slot: 2) {
`25`
}
}

@Task(id: rust-enums-task, language: rust, starter: starters/rust-enums-and-match.rs, tests: tests/rust-enums-and-match.rs, solution: solutions/rust-enums-and-match.rs) {
enum `Temperature` 는 `Celsius(i32)` 아니면 `Fahrenheit(i32)` 다. 이 값을 받아 섭씨 정수로 바꿔 돌려주는 함수 `to_celsius` 를 완성하라. `Celsius` 면 값을 그대로 돌려주고, `Fahrenheit` 면 `(화씨 - 32) * 5 / 9` 공식으로 변환한다. 영하가 나오는 경우도 정상적으로 처리해야 한다.

@Hint {
match temp { ... } 로 두 변형을 모두 처리하라. 변형이 하나라도 빠지면 컴파일이 안 된다.
}

@Hint {
Fahrenheit(value) 패턴에서 value 는 &i32 다 — Celsius 쪽에서 그대로 돌려주려면 *value 로 역참조해야 한다.
}

@Hint {
정수 나눗셈은 소수점을 버린다. 이 테스트들의 값은 모두 나누어떨어지도록 골랐다.
}
}

@Quiz(id: rust-enums-quiz, answer: compile-error) {
@Question {
이미 쓰고 있던 enum 에 새 변형을 추가했는데, 기존 match 표현식에 와일드카드(_) 팔이 없다면 어떻게 되는가?
}

@Choice(id: compile-error) {
새 변형을 처리하는 팔이 없다는 컴파일 오류가 난다
}

@Choice(id: warning-only) {
경고만 뜨고 실행 파일은 정상적으로 만들어진다
}

@Choice(id: first-arm) {
새 변형은 자동으로 match 의 첫 번째 팔에 매칭된다
}

@Choice(id: auto-default) {
컴파일러가 새 변형에 대한 기본 처리를 알아서 만들어 준다
}

@Explanation {
match 는 모든 변형을 다뤄야 컴파일이 통과하는 **완전성 검사**를 한다. 와일드카드가 없는 상태에서 변형을 추가하면 그 변형을 처리하지 않은 match 표현식이 전부 컴파일 오류로 드러난다. 경고로 그치거나 조용히 첫 팔에 매칭되거나 기본값을 만들어 주는 일은 없다 — 그랬다면 새로 생긴 경우를 놓치고도 프로그램이 아무 일 없다는 듯 실행됐을 것이다.
}
}

@Reflection(id: rust-enums-reflection) {
@Prompt(id: exhaustiveness-value) {
다른 언어의 switch 문은 case 를 빠뜨려도 컴파일되는 경우가 많습니다. match 가 모든 경우를 강제하는 것이 실무에서 어떤 버그를 미리 막아 줄지 적어 보세요.
}

@Prompt(id: when-wildcard) {
변형이 10개인 enum 에서 그중 2개만 특별하게 처리하고 나머지는 똑같이 다뤄도 될 때와, 모든 변형을 하나하나 명시해야 안전할 때는 각각 언제일지 생각해 보세요.
}
}
