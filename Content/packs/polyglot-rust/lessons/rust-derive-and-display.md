@Concept(id: rust-derive-concept) {
`Debug`, `Clone`, `PartialEq` 같은 트레이트는 거의 항상 같은 방식으로 구현된다 — 필드를 하나씩 나열해서 찍거나, 필드를 하나씩 복사하거나, 필드를 하나씩 비교한다. 이런 기계적인 구현을 매번 손으로 쓰는 대신, struct 선언 위에 `#[derive(Debug, Clone, PartialEq)]` 를 붙이면 컴파일러가 그 구현을 대신 만들어 준다. 필드가 늘어나도 derive 목록은 그대로라서, 구조가 바뀌어도 구현을 손대지 않아도 된다.

`derive(Debug)` 로 얻는 출력은 `{:?}` 자리 표시자로 꺼내 쓴다. `{}` 자리 표시자가 쓰는 것은 `Display` 트레이트인데, 이것은 derive 할 수 없다 — 무엇을 "사람이 읽기 좋은 형태" 로 볼지는 타입마다 다르고 컴파일러가 짐작할 수 없기 때문이다. `Debug` 는 개발자가 값을 들여다보기 위한 것이라 형식이 기계적이어도 되지만, `Display` 는 최종 사용자에게 보여줄 형태라서 직접 `fmt` 메서드를 구현해야 한다.

`Display` 를 구현하려면 `std::fmt::Display` 트레이트의 `fmt` 메서드를 채운다. 이 메서드 안에서는 `println!` 대신 `write!(f, ...)` 를 쓰는데, 자리 표시자 문법은 완전히 같다 — `f` 가 최종적으로 화면이나 문자열로 이어지는 출력 대상이라는 점만 다르다.

derive 로 얻는 트레이트는 이번 셋만이 아니지만, 이 셋이 가장 자주 쓰인다. `Debug` 는 디버깅 출력, `Clone` 은 깊은 복사, `PartialEq` 는 `==` 비교를 가능하게 한다.
}

@Example(id: rust-derive-example, language: rust, expected: expected/rust-derive-and-display.txt) {
`Point` 는 derive 만으로 `{:?}` 출력과 `==` 비교, `clone()` 을 얻는다. `Temperature` 는 `Display` 를 직접 구현해 `{}` 로 사람이 읽을 형태를 만든다.

```rust
#[derive(Debug, Clone, PartialEq)]
struct Point {
    x: i32,
    y: i32,
}

struct Temperature {
    celsius: f64,
}

impl std::fmt::Display for Temperature {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:.1}°C", self.celsius)
    }
}

fn main() {
    let p1 = Point { x: 1, y: 2 };
    let p2 = p1.clone();

    println!("{:?}", p1);
    println!("{}", p1 == p2);

    let t = Temperature { celsius: 23.456 };
    println!("{}", t);
}
```
}

@Blank(id: rust-derive-blank, language: rust) {
derive 속성 이름과 Display 트레이트 이름을 채워라.

```rust
#[___1___(Debug, PartialEq)]
struct Color {
    red: u8,
    green: u8,
    blue: u8,
}

impl std::fmt::___2___ for Color {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "#{:02X}{:02X}{:02X}", self.red, self.green, self.blue)
    }
}

fn main() {
    let c = Color { red: 255, green: 0, blue: 128 };
    println!("{:?}", c);
    println!("{}", c);
}
```

@Answer(slot: 1) {
`derive`
}

@Answer(slot: 2) {
`Display`
}
}

@Task(id: rust-derive-task, language: rust, starter: starters/rust-derive-and-display.rs, tests: tests/rust-derive-and-display.rs, solution: solutions/rust-derive-and-display.rs) {
`Money` 는 센트 단위로 금액을 저장한다(`cents` 필드). `Display` 를 구현해 `"$달러.센트"` 형태로 보여주도록 하라. 센트가 한 자리 수면 앞에 0 을 채워 두 자리로 맞춘다(예: 5센트 → `"$0.05"`).

@Hint {
`self.cents / 100` 이 달러, `self.cents % 100` 이 센트다.
}

@Hint {
`write!(f, "...")` 는 `println!` 과 같은 자리 표시자 문법을 그대로 쓴다.
}

@Hint {
센트 자리에는 `{:02}` 를 써서 한 자리 수도 앞에 0 을 채워 두 자리로 맞춰라.
}
}

@Quiz(id: rust-derive-quiz, answer: debug-vs-display) {
@Question {
`{:?}` 와 `{}` 자리 표시자의 차이는 무엇인가요?
}

@Choice(id: debug-vs-display) {
`{:?}` 는 derive 로 자동으로 얻을 수 있는 개발자용 출력이고, `{}` 는 직접 구현해야 하는, 사람이 읽을 출력이다
}

@Choice(id: always-slower) {
`{:?}` 는 항상 `{}` 보다 실행 속도가 느리다
}

@Choice(id: numbers-only) {
`{}` 는 숫자 타입에만 쓸 수 있고 `{:?}` 는 모든 타입에 쓸 수 있다
}

@Choice(id: file-only) {
`{:?}` 는 값을 파일에 저장할 때만 쓰인다
}

@Explanation {
`{:?}` 는 `Debug` 트레이트를 쓰는데 이것은 `derive` 로 기계적으로 얻을 수 있는, 개발자가 값을 들여다보기 위한 출력이다. `{}` 는 `Display` 트레이트를 쓰는데 이것은 derive 할 수 없고 타입마다 무엇이 "읽기 좋은 형태" 인지 직접 정해서 `fmt` 를 구현해야 한다. 실행 속도나 파일 저장과는 관계가 없고, `Display` 는 숫자뿐 아니라 어떤 타입에도 구현할 수 있다.
}
}

@Reflection(id: rust-derive-reflection) {
@Prompt(id: debug-vs-display-purpose) {
`Point` 의 `{:?}` 출력과 `Temperature` 의 `{}` 출력이 서로 다른 목적을 가진다는 것을 이번 레슨의 예제로 설명해 보세요.
}

@Prompt(id: missing-partialeq) {
`Point` 선언에서 `PartialEq` 를 derive 목록에서 빼면 `p1 == p2` 줄에서 어떤 컴파일 오류가 날지 예상해 보고, 실제로 지워서 확인해 보세요.
}
}
