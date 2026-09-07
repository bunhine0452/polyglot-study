@Concept(id: rust-hello-concept) {
러스트 프로그램은 `fn main()` 에서 시작한다. 실행 파일이 만들어지면 운영체제가 가장 먼저 부르는 함수가 이것이고, 이름이 정확히 `main` 이어야 한다.

화면에 무언가를 찍을 때는 `println!` 을 쓴다. 이름 끝의 느낌표는 오타가 아니라 이것이 함수가 아니라 **매크로**라는 표시다. 매크로는 컴파일 시점에 코드로 펼쳐지는데, `println!` 이 매크로인 이유는 인자의 개수와 타입이 호출마다 다르기 때문이다.

문자열 안에 값을 끼워 넣으려면 중괄호 `{}` 를 자리 표시자로 두고 뒤에 값을 넘긴다. 자리 표시자의 개수와 넘긴 값의 개수가 다르면 컴파일이 실패한다 — 실행해 보고서야 아는 것이 아니라 굽는 단계에서 걸린다.

`//` 뒤부터 줄 끝까지는 주석이라 실행에 아무 영향이 없다. 코드가 무엇을 하는지가 아니라 왜 그렇게 하는지를 적는 자리다.
}

@Example(id: rust-hello-example, language: rust, expected: expected/rust-hello-and-println.txt) {
세 가지를 한 번에 본다 — 그냥 찍기, 값 하나 끼워 찍기, 값 둘 끼워 찍기. 주석은 출력에 나타나지 않는다.

```rust
fn main() {
    // 이 줄은 실행되지 않는다.
    println!("안녕하세요, 러스트");

    let year = 2026;
    println!("올해는 {}년입니다", year);

    let language = "Rust";
    let version = 2021;
    println!("{} 에디션 {}", language, version);
}
```
}

@Blank(id: rust-hello-blank, language: rust) {
출력 매크로의 이름과 자리 표시자를 채워 완성하자.

```rust
fn main() {
    let name = "러스트";
    ___1___("{} 를 시작합니다", ___2___);
}
```

@Answer(slot: 1) {
`println!`
}

@Answer(slot: 2) {
`name`
}
}

@Task(id: rust-hello-task, language: rust, starter: starters/rust-hello-and-println.rs, tests: tests/rust-hello-and-println.rs, solution: solutions/rust-hello-and-println.rs) {
이름을 받아 인사말을 만들어 돌려주는 함수 `greeting` 을 완성하라. `greeting("세계")` 는 정확히 `안녕하세요, 세계!` 를 돌려줘야 한다. 화면에 찍는 것이 아니라 `String` 으로 **반환**한다는 점에 주의하라. 빈 문자열을 받으면 `안녕하세요, 이름 없음!` 을 돌려준다.

@Hint {
`format!` 은 `println!` 과 같은 자리 표시자를 쓰지만 화면에 찍는 대신 `String` 을 돌려준다.
}

@Hint {
빈 문자열인지는 `name.is_empty()` 로 검사할 수 있다.
}

@Hint {
느낌표까지 포함해서 정확히 일치해야 한다 — 기대 문자열을 다시 읽어 보라.
}
}

@Quiz(id: rust-hello-quiz, answer: macro) {
@Question {
`println!` 의 이름 끝에 붙은 느낌표는 무엇을 뜻할까요?
}

@Choice(id: macro) {
함수가 아니라 매크로라는 표시다
}

@Choice(id: unsafe) {
안전하지 않은 연산이라는 경고다
}

@Choice(id: panic) {
실패하면 프로그램을 중단시킨다는 뜻이다
}

@Choice(id: style) {
관례일 뿐 문법적 의미는 없다
}

@Explanation {
느낌표는 매크로 호출 표시다. 매크로는 컴파일 시점에 코드로 펼쳐지므로 인자의 개수와 타입이 호출마다 달라도 된다 — `println!` 이 자리 표시자를 몇 개든 받을 수 있는 이유가 이것이다. 안전성이나 중단과는 관계가 없고, 관례도 아니라서 느낌표를 빼면 컴파일되지 않는다.
}
}

@Reflection(id: rust-hello-reflection) {
@Prompt(id: compile-time-check) {
자리 표시자 개수와 값의 개수가 맞지 않으면 실행 전에 컴파일이 막힙니다. 실행해 봐야 아는 것과 굽는 단계에서 아는 것의 차이가 개발에 어떤 영향을 줄지 적어 보세요.
}

@Prompt(id: print-vs-return) {
과제에서는 화면에 찍는 대신 문자열을 반환했습니다. 같은 기능을 찍는 함수로 만들면 무엇이 불편해질지 생각해 보세요.
}
}
