@Concept(id: let-mut-concept) {
러스트에서 `let` 으로 만든 바인딩은 기본이 불변이다. 다른 언어에서는 변수를 만들면 당연히 나중에 값을 바꿀 수 있다고 여기기 쉽지만, 러스트는 그 반대를 기본값으로 둔다. 대부분의 값은 한 번 정해지면 끝까지 바뀌지 않아야 안전하고, 그것을 컴파일러가 강제해 주면 실수로 값을 덮어써서 생기는 버그를 프로그램을 실행하기도 전에 막을 수 있기 때문이다.

mut 없이 재대입을 시도하면 무슨 일이 일어나는지 보자. `let x = 5;` 로 묶은 다음 `x = 6;` 을 쓰면 컴파일러는 "cannot assign twice to immutable variable `x`" 라는 메시지와 함께 오류 번호 E0384 를 낸다. 실행조차 되지 않고 굽는 단계에서 막힌다는 점이 중요하다 — 이 버그는 테스트를 돌리기 전에, 심지어 프로그램을 단 한 번도 실행하지 않고도 잡힌다.

값을 나중에 바꿔야 한다면 `let` 뒤에 `mut` 를 붙이면 된다. `let mut x = 5;` 라고 선언하면 그 다음부터 `x = 6;` 처럼 재대입해도 컴파일러가 받아들인다. mut 는 컴파일러에게 주는 허락이면서 동시에 코드를 읽는 사람에게 주는 신호이기도 하다 — mut 가 없는 바인딩은 끝까지 그 값 그대로라는 것을 코드만 보고 믿을 수 있게 된다.
}

@Example(id: let-mut-example, language: rust, expected: expected/rust-let-and-mut.txt) {
이름은 한 번 묶고 다시 바꾸지 않는다. 횟수는 mut 를 붙여 두 번 다시 대입한다.

```rust
fn main() {
    let name = "러스트";
    println!("이름: {}", name);

    let mut count = 1;
    println!("횟수: {}", count);

    count = 2;
    println!("횟수: {}", count);

    count = 3;
    println!("횟수: {}", count);
}
```
}

@Blank(id: let-mut-blank, language: rust) {
x 는 바꾸지 않으니 그대로 두고, y 는 재대입할 것이므로 표식을 채워 완성하자.

```rust
fn main() {
    let x = 10;
    println!("x = {}", x);

    ___1___ y = 10;
    y = 20;
    println!("y = {}", ___2___);
}
```

@Answer(slot: 1) {
`let mut`
}

@Answer(slot: 2) {
`y`
}
}

@Task(id: let-mut-task, language: rust, starter: starters/rust-let-and-mut.rs, tests: tests/rust-let-and-mut.rs, solution: solutions/rust-let-and-mut.rs) {
정수 하나를 받아 `mut` 변수에 담고 두 번 1 씩 늘린 값을 돌려주는 함수 `bump_twice` 를 작성하라. `bump_twice(5)` 는 `7` 을, `bump_twice(0)` 은 `2` 를, `bump_twice(-3)` 은 `-1` 을 돌려줘야 한다.

@Hint {
`let mut total = n;` 처럼 바꿀 수 있는 변수에 먼저 담아라.
}

@Hint {
`total = total + 1;` 을 두 번 쓰면 두 번 늘어난다.
}

@Hint {
함수의 마지막 줄에 `total` 만 적으면 그 값이 반환값이 된다.
}
}

@Quiz(id: let-mut-quiz, answer: compile-error) {
@Question {
`let x = 5;` 로 만든 바인딩에 이어서 `x = 6;` 을 실행하면 어떻게 될까요?
}

@Choice(id: compile-error) {
컴파일이 실패한다 — 재대입에는 mut 가 필요하기 때문이다
}

@Choice(id: runtime-panic) {
컴파일은 되지만 실행 중에 패닉이 난다
}

@Choice(id: silently-ignored) {
컴파일과 실행 모두 되고 x 의 값은 그대로 5 로 남는다
}

@Choice(id: warning-only) {
경고만 뜨고 x 의 값은 6 으로 바뀐다
}

@Explanation {
let 으로 만든 바인딩은 기본이 불변이라 mut 없이 재대입하면 컴파일러가 E0384(cannot assign twice to immutable variable) 오류를 내며 굽는 단계에서 막는다. 실행 중 패닉이 아니라 컴파일 자체가 실패하므로 runtime-panic 은 틀렸고, 값이 조용히 무시되거나 경고만으로 넘어가는 것도 아니다 — 러스트는 이를 오류로 취급해 실행 파일을 아예 만들지 않는다.
}
}

@Reflection(id: let-mut-reflection) {
@Prompt(id: why-immutable-default) {
많은 언어가 변수를 기본으로 바꿀 수 있게 두는데 러스트는 그 반대를 기본값으로 골랐습니다. 이 선택이 어떤 종류의 버그를 미리 막아줄지 적어 보세요.
}

@Prompt(id: mut-as-signal) {
코드를 읽다가 mut 가 붙은 바인딩을 만나면 mut 가 없는 바인딩을 볼 때와 무엇이 다르게 느껴질지 생각해 보세요.
}
}
