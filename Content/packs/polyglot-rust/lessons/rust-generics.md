@Concept(id: rust-generics-concept) {
정수 목록에서 최댓값을 찾는 함수와 실수 목록에서 최댓값을 찾는 함수는 로직이 완전히 같다 — 다른 것은 오직 원소의 타입뿐이다. 타입마다 함수를 새로 쓰는 대신, 타입 자체를 매개변수로 받도록 쓸 수 있다. `<T>` 를 함수 이름 뒤에 붙이면 `T` 는 호출할 때 실제 타입으로 채워지는 자리 표시자가 된다.

제네릭 함수 안에서 `T` 값에 무슨 연산을 쓸 수 있는지는 `T` 가 어떤 능력을 갖췄다고 약속했는지에 달려 있다. 예를 들어 `>` 로 두 값을 비교하려면 모든 타입이 비교를 지원하는 것은 아니므로, `T: PartialOrd` 처럼 **트레이트 경계**를 적어 "비교할 수 있는 타입만 받겠다" 고 컴파일러에 알려야 한다. 경계를 빠뜨리면 컴파일이 실패한다 — `T` 가 정말 `>` 를 지원하는지 컴파일러가 확인할 방법이 없기 때문이다. 트레이트가 정확히 무엇인지는 다음 레슨에서 다루고, 여기서는 "이 능력이 있는 타입만" 이라는 조건을 다는 문법으로만 받아들이면 된다.

제네릭은 함수뿐 아니라 struct 에도 쓸 수 있다. `struct Pair<T> { first: T, second: T }` 라고 쓰면 `Pair<i32>` 도, `Pair<f64>` 도, `Pair<String>` 도 같은 정의 하나로 만들어진다. 구체적인 타입은 인스턴스를 만들 때 값으로부터 추론된다.

결국 제네릭이 하는 일은 코드 중복을 없애는 것이다. 타입별로 거의 같은 함수나 struct 를 여러 벌 두는 대신 하나만 두고, 그 하나가 어떤 타입에 쓰일 수 있는지를 트레이트 경계로 정확히 표현한다.
}

@Example(id: rust-generics-example, language: rust, expected: expected/rust-generics.txt) {
`largest` 는 `T: PartialOrd + Copy` 경계 덕분에 정수 목록과 실수 목록 모두에 쓸 수 있다. `Pair<T>` 는 같은 정의로 정수 쌍을 담는다.

```rust
fn largest<T: PartialOrd + Copy>(list: &[T]) -> T {
    let mut result = list[0];
    for &item in list {
        if item > result {
            result = item;
        }
    }
    result
}

struct Pair<T> {
    first: T,
    second: T,
}

impl<T: PartialOrd + Copy> Pair<T> {
    fn larger(&self) -> T {
        if self.first > self.second {
            self.first
        } else {
            self.second
        }
    }
}

fn main() {
    let numbers = vec![34, 50, 25, 100, 65];
    println!("가장 큰 정수: {}", largest(&numbers));

    let floats = vec![3.5, 7.2, 1.1];
    println!("가장 큰 실수: {}", largest(&floats));

    let pair = Pair { first: 10, second: 20 };
    println!("더 큰 값: {}", pair.larger());
}
```
}

@Blank(id: rust-generics-blank, language: rust) {
제네릭 함수와 제네릭 struct 의 타입 매개변수 자리를 채워라.

```rust
fn identity<___1___>(value: T) -> T {
    value
}

struct Wrapper<___2___> {
    value: T,
}

fn main() {
    println!("{}", identity(5));
    println!("{}", identity("hello"));

    let w = Wrapper { value: 42 };
    println!("{}", w.value);
}
```

@Answer(slot: 1) {
`T`
}

@Answer(slot: 2) {
`T`
}
}

@Task(id: rust-generics-task, language: rust, starter: starters/rust-generics.rs, tests: tests/rust-generics.rs, solution: solutions/rust-generics.rs) {
슬라이스에서 최댓값을 찾는 제네릭 함수 `max_of` 를 완성하라. 목록이 비어 있으면 `None` 을, 그렇지 않으면 `Some(최댓값)` 을 돌려준다. `PartialOrd` 와 `Copy` 를 모두 만족하는 타입이면 정수든 실수든 동작해야 한다.

@Hint {
`list.is_empty()` 로 빈 목록을 가장 먼저 걸러내라.
}

@Hint {
`list[0]` 을 초기값으로 삼고 나머지 원소와 하나씩 `>` 로 비교하라.
}

@Hint {
결과는 `Some(...)` 으로 감싸야 한다 — 반환 타입이 `Option<T>` 임을 잊지 마라.
}
}

@Quiz(id: rust-generics-quiz, answer: not-all-comparable) {
@Question {
제네릭 함수 `fn largest<T>(list: &[T]) -> T` 안에서 `item > result` 를 쓰려면 `T: PartialOrd` 라는 트레이트 경계가 왜 필요한가요?
}

@Choice(id: not-all-comparable) {
모든 타입이 `>` 연산을 지원하는 것은 아니므로, 비교 가능한 타입만 받겠다고 컴파일러에 알려야 한다
}

@Choice(id: always-required) {
제네릭 함수는 트레이트 경계 없이는 어떤 경우에도 컴파일되지 않는다
}

@Choice(id: runtime-speed) {
트레이트 경계를 붙이면 비교 연산의 실행 속도가 빨라진다
}

@Choice(id: limit-types) {
`T` 가 여러 타입으로 쓰이지 못하도록 막기 위해서다
}

@Explanation {
`T` 는 임의의 타입을 대신하므로, 컴파일러는 `T` 가 정말 `>` 를 지원하는지 알 방법이 없다. `PartialOrd` 경계를 달아야 "이 함수는 비교 가능한 타입만 받는다" 는 조건이 명시되어 컴파일러가 `>` 사용을 허락한다. 트레이트 경계가 없어도 되는 제네릭 함수도 많고(예: 값을 그대로 돌려주는 `identity`), 실행 속도와는 무관하며, 여러 타입에 쓰이는 것을 막는 것이 아니라 오히려 어떤 타입까지 허용할지 정확히 표현하는 것이 목적이다.
}
}

@Reflection(id: rust-generics-reflection) {
@Prompt(id: duplication-avoided) {
`largest` 를 `i32` 용과 `f64` 용으로 따로 만들었다면 코드가 얼마나 늘어났을지, 제네릭이 그 중복을 어떻게 없앴는지 적어 보세요.
}

@Prompt(id: missing-bound-guess) {
`max_of` 정의에서 `PartialOrd` 경계를 지우면 어떤 컴파일 오류가 날지 예상해 보고, 실제로 지워서 오류 메시지를 확인해 보세요.
}
}
