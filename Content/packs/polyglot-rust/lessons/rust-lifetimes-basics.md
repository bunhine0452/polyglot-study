@Concept(id: rust-lifetimes-concept) {
참조를 매개변수로 받아 참조를 돌려주는 함수를 생각해 보자. `fn longest(x: &str, y: &str) -> &str` 처럼 쓰면 컴파일이 실패한다 — 오류 코드는 E0106, "missing lifetime specifier" 다. 이유는 이렇다. 돌려주는 참조가 `x` 를 가리킬 수도 `y` 를 가리킬 수도 있는데, `x` 와 `y` 는 서로 다른 시점까지 유효할 수 있다. 반환값이 둘 중 어느 쪽의 유효 기간을 따르는지 컴파일러가 알아야 그 반환값을 호출한 쪽에서 안전하게 쓸 수 있는지 검사할 수 있는데, 지금 시그니처만으로는 그 정보가 없다.

이 정보를 채워 주는 것이 **수명 표기** `'a` 다. `fn longest<'a>(x: &'a str, y: &'a str) -> &'a str` 이라고 쓰면 "`x`, `y`, 그리고 반환값이 모두 같은 수명 `'a` 를 공유한다" 는 뜻이 된다. 실제로 컴파일러는 이것을 "반환값은 `x` 와 `y` 중 더 짧게 살아 있는 쪽 이상으로는 오래 쓰이지 않는다" 는 뜻으로 받아들인다. `'a` 자체가 특정 길이를 정하는 것이 아니라, 여러 참조 사이의 유효 기간 관계를 컴파일러에게 알려주는 이름표일 뿐이다.

수명 표기가 막아 주는 대표적인 사고가 **댕글링 참조**다. 함수 안에서 만든 지역 변수의 참조를 그대로 돌려주려 하면 — 예를 들어 `fn dangle() -> &String { let s = String::from("안녕"); &s }` 처럼 쓰면 — `s` 는 함수가 끝나며 사라지는데 그 주소를 가진 참조만 바깥으로 나가게 된다. 다른 언어라면 이렇게 만들어진 참조로 이미 해제된 메모리를 읽는 사고가 나지만, 러스트는 이런 함수를 애초에 컴파일 단계에서 거부한다. 지역 변수 `s` 의 수명이 함수 밖으로 나갈 수 없다는 것을 컴파일러가 알고 있기 때문이다.

수명 표기는 새로운 검사를 추가하는 것이 아니라, 이미 해 오던 빌림 검사에 필요한 정보를 사람이 명시적으로 적어 주는 것에 가깝다. 매개변수와 반환값이 모두 참조 하나뿐이라면 컴파일러가 대부분 알아서 추론해 주지만, 참조가 둘 이상 얽히면 그 관계를 `'a` 로 직접 말해 줘야 한다.
}

@Example(id: rust-lifetimes-example, language: rust, expected: expected/rust-lifetimes-basics.txt) {
`longest` 는 `'a` 하나로 두 매개변수와 반환값의 관계를 표현한다. 실제로 호출해 보면 더 긴 쪽의 내용이 그대로 돌아온다.

```rust
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}

fn main() {
    let s1 = String::from("hello world");
    let s2 = String::from("hi");
    let result = longest(&s1, &s2);
    println!("더 긴 문자열: {}", result);

    let s3 = String::from("짧다");
    let s4 = String::from("이것은 더 긴 문자열입니다");
    println!("더 긴 문자열: {}", longest(&s3, &s4));
}
```
}

@Blank(id: rust-lifetimes-blank, language: rust) {
매개변수와 반환값이 같은 수명을 공유한다는 것을 표기하는 자리를 채워라.

```rust
fn echo___1___(s: &___2___ str) -> &___3___ str {
    s
}

fn main() {
    let text = String::from("안녕하세요");
    println!("{}", echo(&text));
}
```

@Answer(slot: 1) {
`<'a>`
}

@Answer(slot: 2) {
`'a`
}

@Answer(slot: 3) {
`'a`
}
}

@Task(id: rust-lifetimes-task, language: rust, starter: starters/rust-lifetimes-basics.rs, tests: tests/rust-lifetimes-basics.rs, solution: solutions/rust-lifetimes-basics.rs) {
두 문자열 슬라이스 중 더 긴 쪽을 돌려주는 `longer` 를 완성하라. 길이가 같으면 첫 번째 인자를 돌려준다. 반환값이 두 인자 중 하나를 그대로 가리키므로 수명 표기가 필요하다.

@Hint {
`x.len()` 과 `y.len()` 을 비교하면 된다.
}

@Hint {
길이가 같은 경우까지 포함해서 `x` 를 돌려주려면 `>=` 를 쓰면 된다.
}

@Hint {
반환 타입이 `&'a str` 이므로 `x` 나 `y` 를 그대로 돌려주면 되고 새 문자열을 만들 필요는 없다.
}
}

@Quiz(id: rust-lifetimes-quiz, answer: e0106-ambiguous) {
@Question {
`fn longest(x: &str, y: &str) -> &str { ... }` 는 왜 컴파일되지 않을까요?
}

@Choice(id: e0106-ambiguous) {
반환하는 참조가 x 와 y 중 어느 쪽의 수명을 따르는지 컴파일러가 알 수 없기 때문이다(E0106)
}

@Choice(id: no-str-param) {
&str 은 애초에 함수 매개변수로 쓸 수 없기 때문이다
}

@Choice(id: if-not-allowed) {
함수 몸체에 if 를 쓰면 참조를 반환할 수 없기 때문이다
}

@Choice(id: short-names) {
매개변수 이름 x, y 가 너무 짧기 때문이다
}

@Explanation {
반환값이 `x` 를 가리킬 수도 `y` 를 가리킬 수도 있는데, 이 둘의 유효 기간이 다를 수 있어서 컴파일러는 반환값이 얼마나 오래 유효한지 알 수 없다. `<'a>` 를 붙여 세 자리 모두 같은 수명을 공유한다고 명시해야 이 모호함이 풀린다. `&str` 매개변수 자체는 흔히 쓰이고, if 문이나 매개변수 이름 길이는 이 오류와 무관하다.
}
}

@Reflection(id: rust-lifetimes-reflection) {
@Prompt(id: what-a-guarantees) {
`longest<'a>(x: &'a str, y: &'a str) -> &'a str` 에서 `'a` 가 실제로 무엇을 보장하는지 자신의 말로 정리해 보세요.
}

@Prompt(id: why-dangling-blocked) {
함수 안에서 만든 지역 변수의 참조를 밖으로 돌려주는 코드가 왜 컴파일 단계에서 막혀야 하는지, 그것이 허용됐다면 어떤 문제가 생겼을지 생각해 보세요.
}
}
