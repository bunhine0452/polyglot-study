@Concept(id: borrowing-concept) {
함수에 값을 넘길 때마다 소유권까지 넘기면 함수가 끝난 뒤에는 원래 변수를 쓸 수 없다. 소유권은 그대로 두고 값을 잠깐 빌려주고 싶을 때 `&` 를 쓴다. `fn print_len(s: &String) { println!("{}", s.len()); }` 처럼 매개변수 타입 앞에 &를 붙이면 그 함수는 값을 빌리기만 하고, 함수가 끝나면 빌림도 끝난다 — 호출한 쪽은 값을 그대로 계속 쓸 수 있다.

빌린 값을 함수 안에서 바꾸고 싶다면 `&mut` 로 가변 참조를 넘겨야 한다. `fn add_exclaim(s: &mut String) { s.push_str("!"); }` 처럼 쓰고, 호출할 때도 `add_exclaim(&mut s)` 처럼 mut 참조를 넘긴다. 물론 s 자신도 `let mut s = ...` 로 선언되어 있어야 한다 — 원본이 불변이면 가변 참조를 만들 수조차 없다.

러스트는 같은 값에 대한 가변 참조를 동시에 하나만 허용한다. 다음 코드를 보자. `let mut s = String::from("hi"); let r1 = &mut s; let r2 = &mut s; println!("{} {}", r1, r2);` 이 코드는 컴파일되지 않는다. r1 이 아직 쓰이고 있는 동안 r2 라는 두 번째 가변 참조를 또 만들었기 때문이다. 컴파일러는 "cannot borrow `s` as mutable more than once at a time" 라는 메시지와 함께 오류 번호 E0499 를 낸다. 두 참조가 동시에 값을 바꿀 수 있다면 한쪽이 읽는 도중 다른 쪽이 바꿔버리는 경합이 생길 수 있는데, 빌림 검사기(borrow checker)는 이런 상황을 실행해 보지 않고도 컴파일 단계에서 차단한다.

반대로 불변 참조 `&` 는 동시에 여러 개 있어도 된다 — 다들 값을 읽기만 할 뿐 바꾸지 않으니 경합이 생기지 않기 때문이다. 다만 가변 참조와 불변 참조를 동시에 섞어 쓸 수는 없다.
}

@Example(id: borrowing-example, language: rust, expected: expected/rust-borrowing-references.txt) {
값을 빌리기만 하는 함수와 값을 바꾸는 함수를 나란히 본다. 빌려준 뒤에도 원본은 계속 쓸 수 있다.

```rust
fn print_len(s: &String) {
    println!("길이: {}", s.len());
}

fn add_exclaim(s: &mut String) {
    s.push_str("!");
}

fn main() {
    let s = String::from("hello");
    print_len(&s);
    println!("여전히 쓸 수 있다: {}", s);

    let mut m = String::from("hi");
    add_exclaim(&mut m);
    println!("바뀐 값: {}", m);
}
```
}

@Blank(id: borrowing-blank, language: rust) {
값을 바꾸는 함수의 매개변수 타입과, 호출할 때 넘기는 가변 참조 표기를 채우자.

```rust
fn shout(s: ___1___ String) {
    s.push_str("!");
}

fn main() {
    let mut word = String::from("hi");
    shout(___2___ word);
    println!("{}", word);
}
```

@Answer(slot: 1) {
`&mut`
}

@Answer(slot: 2) {
`&mut`
}
}

@Task(id: borrowing-task, language: rust, starter: starters/rust-borrowing-references.rs, tests: tests/rust-borrowing-references.rs, solution: solutions/rust-borrowing-references.rs) {
문자열 참조와 개수를 받아, 그 개수만큼 별표 `*` 를 문자열 뒤에 붙이는 함수 `pad_with_stars(s: &mut String, count: i32)` 를 작성하라. 함수는 값을 돌려주지 않고 s 를 직접 바꾼다. count 가 0 이면 아무것도 붙이지 않는다.

@Hint {
s 는 &mut String 이니 s.push_str(...) 처럼 메서드로 직접 바꿀 수 있다.
}

@Hint {
while 로 0부터 count 미만까지 반복하며 매번 별 하나씩 붙여라.
}

@Hint {
count 가 0이면 while 조건이 처음부터 거짓이라 s 는 그대로 남는다.
}
}

@Quiz(id: borrowing-quiz, answer: two-mutable-refs) {
@Question {
`let mut s = String::from("hi"); let r1 = &mut s; let r2 = &mut s; println!("{} {}", r1, r2);` 가 컴파일되지 않는 이유는 무엇일까요?
}

@Choice(id: two-mutable-refs) {
같은 값에 대한 가변 참조를 동시에 둘 만들었기 때문이다
}

@Choice(id: missing-mut-on-s) {
s 선언에 mut 가 빠졌기 때문이다
}

@Choice(id: string-not-copy) {
String 이 Copy 트레이트를 구현하지 않았기 때문이다
}

@Choice(id: println-cant-take-refs) {
println! 은 참조를 인자로 받을 수 없기 때문이다
}

@Explanation {
러스트는 같은 값에 대한 가변 참조를 동시에 하나만 허용한다. r1 이 아직 쓰이고 있는 동안 r2 라는 두 번째 가변 참조를 또 만들었으므로 E0499 오류가 난다. s 는 이미 mut 로 선언되어 있고, Copy 여부나 println! 의 참조 처리 능력과는 관계없는 문제다.
}
}

@Reflection(id: borrowing-reflection) {
@Prompt(id: why-one-mutable-ref) {
가변 참조를 동시에 하나만 허용하는 규칙이, 다른 언어에서라면 실행 중에야 드러났을 어떤 버그를 컴파일 단계에서 미리 막아주는지 적어 보세요.
}

@Prompt(id: borrow-vs-move-choice) {
함수에 값을 넘길 때 소유권을 넘길지(이동) 아니면 빌려줄지(&) 를 고를 때 어떤 기준으로 판단하면 좋을지 생각해 보세요.
}
}
