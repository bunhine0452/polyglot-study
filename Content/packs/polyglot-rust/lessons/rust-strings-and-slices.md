@Concept(id: strings-concept) {
러스트에는 문자열이 두 종류다. `"안녕"` 처럼 큰따옴표로 감싼 문자열 리터럴은 `&str` 타입이고 프로그램 바이너리 안에 고정된 채로 들어있어 크기를 바꿀 수 없다. 반면 `String::from("안녕")` 으로 만든 값은 힙에 할당되어 소유자가 있고 늘어나거나 줄어들 수 있다. `&str` 은 남의 문자열을 잠깐 빌려 보는 창에 가깝고, `String` 은 그 내용을 실제로 소유하고 관리하는 쪽이다.

이미 있는 String 뒤에 문자열을 덧붙이려면 `push_str` 을 쓴다 — `s.push_str("!")` 는 s 자체를 바꾸므로 s 는 mut 여야 한다. 두 문자열을 이어 새 String 을 만들고 싶다면 `+` 연산자나 `format!` 매크로를 쓴다. `+` 는 왼쪽 피연산자의 소유권을 가져가 버리는 특이한 동작이 있어서, 조각을 여럿 이을 때는 format! 이 더 읽기 좋다.

문자열의 일부만 보고 싶을 때는 슬라이스를 쓴다. `&s[0..3]` 은 s 의 바이트 0번부터 2번까지를 빌려 본 `&str` 을 돌려준다. `len()` 은 문자 개수가 아니라 바이트 길이를 돌려준다는 점도 조심해야 한다 — 한글처럼 한 글자가 여러 바이트를 차지하는 문자에서는 슬라이스 경계를 아무 데나 잘랐다가 프로그램이 패닉할 수 있다. 이 레슨에서는 영문 ASCII 문자열로만 슬라이스를 연습해 그 위험을 피한다.
}

@Example(id: strings-example, language: rust, expected: expected/rust-strings-and-slices.txt) {
문자열 리터럴과 String 을 만들고, push_str 로 잇고, format! 로 새 문자열을 만든 뒤 길이와 슬라이스를 확인한다.

```rust
fn main() {
    let literal = "Rust"; // &str
    let mut owned = String::from("Hello, ");
    owned.push_str(literal);
    println!("{}", owned);

    let greeting = format!("{}!", owned);
    println!("{}", greeting);

    println!("길이(바이트): {}", greeting.len());

    let hello = &greeting[0..5];
    println!("앞 5글자: {}", hello);
}
```
}

@Blank(id: strings-blank, language: rust) {
String 뒤에 문자열을 잇는 메서드와, 앞 4바이트를 얻는 슬라이스 표기를 채우자.

```rust
fn main() {
    let mut s = String::from("Rust");
    s.___1___(" Lang");
    println!("{}", s);

    let first_four = &s___2___;
    println!("{}", first_four);
}
```

@Answer(slot: 1) {
`push_str`
}

@Answer(slot: 2) {
`[0..4]`
}
}

@Task(id: strings-task, language: rust, starter: starters/rust-strings-and-slices.rs, tests: tests/rust-strings-and-slices.rs, solution: solutions/rust-strings-and-slices.rs) {
단어를 받아 앞 3바이트에 "-01" 을 붙인 코드네임을 돌려주는 함수 `codename` 을 작성하라. `word` 는 항상 영문 ASCII 이고 최소 3글자 이상이라고 가정해도 된다. `codename("Falcon")` 은 `"Fal-01"` 을, 정확히 3글자인 `codename("Sky")` 는 `"Sky-01"` 을 돌려줘야 한다.

@Hint {
`&word[0..3]` 으로 앞 3바이트를 슬라이스할 수 있다.
}

@Hint {
`String::from(prefix)` 로 슬라이스를 소유하는 String 을 만들어라.
}

@Hint {
`result.push_str("-01")` 로 뒤에 붙여라 — result 는 mut 여야 한다.
}
}

@Quiz(id: strings-quiz, answer: ownership) {
@Question {
문자열 리터럴 `"Rust"` 와 `String::from("Rust")` 의 가장 중요한 차이는 무엇인가요?
}

@Choice(id: ownership) {
리터럴은 빌려 보는 &str 이고, String::from 은 힙에 소유된 값을 만든다
}

@Choice(id: speed) {
String::from 이 항상 더 빠르게 실행된다
}

@Choice(id: encoding) {
리터럴은 아스키만 담고 String 은 유니코드를 담는다
}

@Choice(id: no-difference) {
표기만 다를 뿐 완전히 같은 타입이다
}

@Explanation {
`"Rust"` 는 바이너리에 고정된 데이터를 빌려 보는 &str 이고, String::from("Rust") 는 그 내용을 힙에 복사해 소유하는 String 을 만든다. 속도 차이가 핵심이 아니고, 인코딩은 둘 다 UTF-8 로 같으며, 타입 자체도 &str 과 String 으로 서로 다르다.
}
}

@Reflection(id: strings-reflection) {
@Prompt(id: borrow-vs-own-string) {
함수가 문자열을 받을 때 &str 로 빌리는 것과 String 으로 소유권을 받는 것 중 무엇을 기본으로 골라야 할지, 그 이유를 적어 보세요.
}

@Prompt(id: byte-length-trap) {
len() 이 문자 개수가 아니라 바이트 길이라는 점이 한글이 섞인 문자열을 슬라이스할 때 어떤 문제를 일으킬 수 있을지 생각해 보세요.
}
}
