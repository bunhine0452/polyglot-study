@Concept(id: functions-concept) {
함수는 `fn` 키워드로 시작해 이름, 괄호 안의 매개변수, 화살표 `->` 뒤에 반환 타입을 적는다. 예를 들어 `fn square(n: i32) -> i32` 는 i32 를 받아 i32 를 돌려주는 함수라는 뜻이다. 매개변수마다 타입을 반드시 적어야 하는데, 이는 함수를 호출하는 쪽 코드를 보지 않고도 함수 하나만 보고 무엇을 받고 무엇을 돌려주는지 알 수 있게 하기 위해서다.

러스트에서는 세미콜론이 있는지 없는지가 값의 운명을 가른다. 세미콜론이 붙은 `n * n;` 은 문(statement)이라 아무 값도 만들지 않고 버려지지만, 세미콜론이 없는 `n * n` 은 식(expression)이라 그 자체로 값을 갖는다. 함수의 마지막 줄에 세미콜론 없는 식을 두면 그 값이 함수의 반환값이 된다 — 다른 언어의 return 문 없이도 값이 자연스럽게 흘러나오는 셈이다.

그렇다고 return 이 필요 없는 것은 아니다. 함수 중간에서 즉시 빠져나가고 싶을 때는 `return 값;` 을 쓴다. 마지막 식으로 반환하는 방식과 return 은 같은 결과를 만들 수 있지만, return 은 세미콜론을 붙여도 그 값을 그대로 돌려준다는 점에서 예외다 — return 뒤의 값은 statement 규칙을 따르지 않는다.
}

@Example(id: functions-example, language: rust, expected: expected/rust-functions-and-return.txt) {
같은 모양의 계산을 두 가지 방식으로 반환한다 — 마지막 식 그대로, 그리고 return 으로.

```rust
fn square(n: i32) -> i32 {
    n * n
}

fn cube(n: i32) -> i32 {
    return n * n * n;
}

fn main() {
    println!("3의 제곱: {}", square(3));
    println!("3의 세제곱: {}", cube(3));
}
```
}

@Blank(id: functions-blank, language: rust) {
반환 타입을 잇는 화살표와, 값을 즉시 돌려주는 키워드를 채우자.

```rust
fn triple(n: i32) ___1___ i32 {
    ___2___ n * 3;
}

fn main() {
    println!("{}", triple(4));
}
```

@Answer(slot: 1) {
`->`
}

@Answer(slot: 2) {
`return`
}
}

@Task(id: functions-task, language: rust, starter: starters/rust-functions-and-return.rs, tests: tests/rust-functions-and-return.rs, solution: solutions/rust-functions-and-return.rs) {
섭씨 온도를 화씨로 바꾸는 함수 `celsius_to_fahrenheit` 를 작성하라. 공식은 `화씨 = 섭씨 * 9.0 / 5.0 + 32.0` 이다. `celsius_to_fahrenheit(0.0)` 은 `32.0` 을, `celsius_to_fahrenheit(-40.0)` 은 `-40.0` 을 돌려줘야 한다(섭씨와 화씨가 정확히 같아지는 지점이다).

@Hint {
마지막 줄에 세미콜론 없이 계산식만 남기면 그 값이 반환값이 된다.
}

@Hint {
곱셈과 나눗셈을 먼저 하고 32.0 을 더하면 된다: `c * 9.0 / 5.0 + 32.0`.
}

@Hint {
`return` 을 써도 되지만, 이 함수는 마지막 식만으로 충분하다.
}
}

@Quiz(id: functions-quiz, answer: statement-not-expr) {
@Question {
`fn double(n: i32) -> i32 { n * 2; }` 가 컴파일되지 않는 이유는 무엇일까요?
}

@Choice(id: statement-not-expr) {
세미콜론이 있어 statement 가 되어 값을 반환하지 않으므로 반환 타입 i32 와 맞지 않는다
}

@Choice(id: missing-return) {
return 키워드가 없어서 아예 컴파일되지 않는다
}

@Choice(id: wrong-arrow) {
화살표를 -> 대신 => 로 써야 하기 때문이다
}

@Choice(id: n-not-mut) {
n 이 mut 로 선언되지 않아서다
}

@Explanation {
`n * 2;` 처럼 세미콜론이 붙으면 statement 가 되어 값을 만들지 않고 유닛 타입 `()` 을 남긴다. 함수는 i32 를 반환하겠다고 선언했으므로 타입이 맞지 않아 컴파일 오류가 난다. return 이 없어도 마지막 식만으로 반환할 수 있으므로 return 부재가 원인은 아니고, 화살표 표기나 mut 여부와도 관계없다.
}
}

@Reflection(id: functions-reflection) {
@Prompt(id: semicolon-meaning) {
세미콜론이 있고 없고에 따라 같은 식이 값을 반환하는지 버려지는지가 갈립니다. 이것이 다른 언어와 비교해 어떤 장단점을 만들지 적어 보세요.
}

@Prompt(id: return-vs-last-expr) {
마지막 식으로 반환하는 방식과 return 을 명시하는 방식 중 언제 어느 쪽이 코드를 더 읽기 쉽게 만들지 생각해 보세요.
}
}
