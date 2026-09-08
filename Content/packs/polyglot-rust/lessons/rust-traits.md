@Concept(id: rust-traits-concept) {
지난 레슨에서 `T: PartialOrd` 처럼 트레이트 이름을 조건으로 썼다. 이번에는 그 트레이트 자체를 직접 만들어 본다. **트레이트**는 여러 타입이 공통으로 가질 수 있는 능력(메서드의 모음)을 이름 붙여 선언한 것이다. `trait Summary { fn summarize(&self) -> String; }` 라고 선언하면 "요약할 수 있는 것" 이라는 능력을 정의한 셈이고, 어떤 struct 든 `impl Summary for 타입이름 { ... }` 으로 그 능력을 갖출 수 있다.

트레이트 메서드는 몸체를 비워 두고 각 타입이 반드시 채우게 할 수도 있지만, **기본 구현**을 미리 적어 둘 수도 있다. 기본 구현이 있는 메서드는 타입이 `impl` 블록에서 아무것도 쓰지 않아도 그대로 쓸 수 있고, 필요하면 재정의해서 덮어쓸 수도 있다. 이 덕분에 트레이트 하나로 "공통으로 쓸 기본 동작" 과 "타입마다 달라야 하는 동작" 을 함께 표현할 수 있다.

어떤 함수가 "이 트레이트를 구현한 값이면 아무거나 받겠다" 고 하려면 매개변수 타입에 구체적인 타입 대신 `impl 트레이트이름` 을 쓴다. `fn print_headline(item: &impl Summary)` 는 `Summary` 를 구현한 타입이라면 무엇이든 받는다 — 지난 레슨의 제네릭 `<T: Summary>` 와 결국 같은 뜻이지만, 타입 매개변수 하나만 그 자리에서 바로 쓸 때는 `impl Trait` 이 더 짧다.

트레이트는 상속처럼 보이지만 다르다. 어떤 타입이 `Summary` 를 구현했다고 해서 다른 타입과 공통의 데이터 구조를 갖는 것은 아니다 — 공유하는 것은 오직 "이 메서드들을 가진다" 는 약속뿐이다.
}

@Example(id: rust-traits-example, language: rust, expected: expected/rust-traits.txt) {
`Article` 은 `summarize` 를 직접 구현하고, `Notice` 는 기본 구현을 그대로 쓴다. `headline` 은 두 타입 모두에서 기본 구현이 `summarize` 를 호출해 만든다.

```rust
trait Summary {
    fn summarize(&self) -> String {
        String::from("(요약 없음)")
    }

    fn headline(&self) -> String {
        format!("[요약] {}", self.summarize())
    }
}

struct Article {
    title: String,
    author: String,
}

impl Summary for Article {
    fn summarize(&self) -> String {
        format!("{} (by {})", self.title, self.author)
    }
}

struct Notice;

impl Summary for Notice {}

fn print_headline(item: &impl Summary) {
    println!("{}", item.headline());
}

fn main() {
    let article = Article {
        title: String::from("러스트 1.0 발표"),
        author: String::from("팀 러스트"),
    };
    let notice = Notice;

    print_headline(&article);
    print_headline(&notice);
}
```
}

@Blank(id: rust-traits-blank, language: rust) {
트레이트 선언 키워드, `impl for` 문법, `impl Trait` 매개변수 자리를 채워라.

```rust
___1___ Greet {
    fn greeting(&self) -> String {
        String::from("안녕하세요")
    }
}

struct Robot;

impl Greet ___2___ Robot {}

fn say_hello(g: ___3___) {
    println!("{}", g.greeting());
}

fn main() {
    let r = Robot;
    say_hello(&r);
}
```

@Answer(slot: 1) {
`trait`
}

@Answer(slot: 2) {
`for`
}

@Answer(slot: 3) {
`&impl Greet`
}
}

@Task(id: rust-traits-task, language: rust, starter: starters/rust-traits.rs, tests: tests/rust-traits.rs, solution: solutions/rust-traits.rs) {
`Shape` 트레이트에는 반드시 구현해야 하는 `area` 메서드와, `area` 를 이용해 이미 완성되어 있는 기본 구현 `describe` 가 있다. `Rectangle` 과 `Square` 에 대해 `area` 만 완성하라 — `describe` 는 손대지 않아도 자동으로 동작해야 한다.

@Hint {
`Rectangle::area` 는 `self.width * self.height` 다.
}

@Hint {
`Square::area` 는 `self.side * self.side` 다.
}

@Hint {
`describe` 는 이미 기본 구현이 되어 있으니 손댈 필요가 없다 — `area` 만 채우면 된다.
}
}

@Quiz(id: rust-traits-quiz, answer: reuse-without-override) {
@Question {
트레이트 메서드에 기본 구현을 두면 무엇이 좋은가요?
}

@Choice(id: reuse-without-override) {
타입이 따로 재정의하지 않아도 쓸 수 있는 동작을 트레이트 자체에 미리 둘 수 있다
}

@Choice(id: cannot-override) {
기본 구현이 있는 메서드는 어떤 타입도 재정의할 수 없게 된다
}

@Choice(id: fills-struct-fields) {
구현하는 struct 의 필드 초기값을 자동으로 채워준다
}

@Choice(id: must-rewrite) {
기본 구현이 있어도 impl 블록에서 반드시 다시 작성해야 한다
}

@Explanation {
기본 구현은 타입이 아무것도 쓰지 않아도 쓸 수 있는 동작을 트레이트 안에 미리 둔 것이다. 예제의 `Notice` 처럼 `impl Summary for Notice {}` 라고만 써도 `summarize` 와 `headline` 을 그대로 쓸 수 있다. 재정의는 여전히 가능하고(예제의 `Article`), struct 필드와는 무관하며, 반드시 다시 쓸 필요도 없다.
}
}

@Reflection(id: rust-traits-reflection) {
@Prompt(id: default-impl-reuse) {
`Notice` 가 `summarize` 를 한 줄도 쓰지 않고도 `headline` 까지 쓸 수 있었던 이유를 이번 레슨에서 배운 대로 설명해 보세요.
}

@Prompt(id: impl-trait-vs-generic) {
`fn print_headline(item: &impl Summary)` 를 지난 레슨 방식의 `fn print_headline<T: Summary>(item: &T)` 로 바꿔 써 보고, 두 표현이 왜 같은 뜻인지 생각해 보세요.
}
}
