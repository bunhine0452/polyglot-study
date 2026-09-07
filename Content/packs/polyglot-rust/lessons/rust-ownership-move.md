@Concept(id: ownership-concept) {
러스트의 값에는 소유자가 정확히 하나 있다. String 처럼 힙에 데이터를 갖는 값을 다른 변수에 대입하면 데이터를 복사하는 대신 소유권 자체가 새 변수로 넘어간다 — 이것을 이동(move)이라 한다. 이동이 끝나면 원래 변수는 더 이상 그 값을 쓸 수 없다.

다음 코드를 보자. `let s1 = String::from("hi"); let s2 = s1; println!("{}", s1);` 이 코드는 컴파일되지 않는다. s1 의 소유권이 s2 로 이동한 뒤에 s1 을 다시 쓰려 했기 때문이다. 컴파일러는 "value borrowed here after move" 라는 메시지와 함께 오류 번호 E0382 를 낸다. 힙 메모리를 가리키는 포인터를 두 변수가 동시에 들고 있다가 둘 다 그 메모리를 해제하려 하면 위험하므로(이중 해제), 러스트는 애초에 유효한 소유자를 하나로 제한해 이 문제를 컴파일 단계에서 차단한다.

그런데 i32 같은 정수는 대입해도 원래 변수를 계속 쓸 수 있다. `let a = 5; let b = a; println!("{}", a);` 는 문제없이 컴파일된다. 크기가 고정되고 스택에만 존재하는 단순한 타입들(정수·부동소수점·bool·char 등)은 Copy 트레이트를 구현하고 있어서 대입이 이동이 아니라 그냥 복사가 된다 — 원본과 사본이 독립적으로 남으니 원본을 계속 써도 안전하다. 반면 String 처럼 힙 데이터를 가리키는 타입은 Copy 가 아니다.

그래도 String 을 진짜로 복사하고 싶다면 `clone()` 을 쓰면 된다. `let s2 = s1.clone();` 은 s1 이 가리키는 힙 데이터까지 통째로 복제해 s2 를 만들고, 그 뒤로 s1 과 s2 는 완전히 독립된 값이라 둘 다 자유롭게 쓸 수 있다. 다만 clone 은 실제로 데이터를 복사하는 비용이 들기 때문에 정말 독립된 사본이 필요할 때만 쓰는 것이 좋다.
}

@Example(id: ownership-example, language: rust, expected: expected/rust-ownership-move.txt) {
Copy 타입은 대입해도 둘 다 쓸 수 있고, String 은 clone 해야 둘 다 쓸 수 있고, clone 없이 대입하면 원본은 더 이상 쓰지 않는다.

```rust
fn main() {
    let a = 5;
    let b = a;
    println!("a = {}, b = {}", a, b);

    let s1 = String::from("hello");
    let s2 = s1.clone();
    println!("s1 = {}, s2 = {}", s1, s2);

    let s3 = String::from("world");
    let s4 = s3;
    println!("s4 = {}", s4);
}
```
}

@Blank(id: ownership-blank, language: rust) {
String 을 진짜로 복제하는 메서드 호출과, 정수를 옮겨 담을 변수 이름을 채우자.

```rust
fn main() {
    let original = String::from("Rust");
    let copy = original___1___;
    println!("{} / {}", original, copy);

    let x = 5;
    let ___2___ = x;
    println!("x = {}, y = {}", x, y);
}
```

@Answer(slot: 1) {
`.clone()`
}

@Answer(slot: 2) {
`y`
}
}

@Task(id: ownership-task, language: rust, starter: starters/rust-ownership-move.rs, tests: tests/rust-ownership-move.rs, solution: solutions/rust-ownership-move.rs) {
문자열 하나를 값으로 받아, 뒤에 느낌표를 붙인 것과 원본을 " / " 로 이어 돌려주는 함수 `build_pair` 를 작성하라. 원본을 나중에도 그대로 써야 하므로 옮기기 전에 clone 이 필요할 것이다. `build_pair(String::from("Go"))` 는 `"Go! / Go"` 를 돌려줘야 한다.

@Hint {
word 를 combined 로 옮기기 전에 clone 으로 사본을 하나 떠 둬야 나중에도 원본 내용을 쓸 수 있다.
}

@Hint {
`let mut combined = word;` 는 word 의 소유권을 combined 로 옮긴다 — 그 뒤로 word 는 못 쓴다.
}

@Hint {
format! 은 인자를 그대로 빌려서 출력만 하므로 combined 와 backup 을 넘길 때 clone 이 또 필요하지는 않다.
}
}

@Quiz(id: ownership-quiz, answer: i32-values) {
@Question {
다음 중 대입해도 원본 변수를 계속 쓸 수 있는 경우는 무엇일까요?
}

@Choice(id: i32-values) {
i32 값을 다른 변수에 대입할 때
}

@Choice(id: string-values) {
String 값을 다른 변수에 대입한 뒤 원래 변수를 다시 쓸 때
}

@Choice(id: moved-into-function) {
String 을 함수에 값으로 넘긴 뒤 그 변수를 다시 쓸 때
}

@Choice(id: moved-into-vec) {
String 을 다른 변수로 옮긴 뒤 원래 변수를 다시 쓸 때
}

@Explanation {
i32 처럼 크기가 고정되고 스택에만 있는 단순한 타입은 Copy 트레이트를 구현해서 대입이 곧 복사이므로 원본을 계속 쓸 수 있다. String 은 Copy 가 아니라서 대입이나 함수 호출에 값으로 넘기는 것은 모두 이동이고, 이동 뒤에 원래 변수를 다시 쓰면 E0382 컴파일 오류가 난다.
}
}

@Reflection(id: ownership-reflection) {
@Prompt(id: why-move-not-copy) {
String 같은 타입까지 대입할 때마다 전부 복사하는 것이 기본이었다면 어떤 성능 문제가 생겼을지 생각해 보세요.
}

@Prompt(id: clone-cost) {
clone 이 항상 안전한 해결책처럼 보이지만 남용하면 안 되는 이유를 비용 관점에서 적어 보세요.
}
}
