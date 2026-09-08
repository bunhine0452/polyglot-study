@Concept(id: control-flow-concept) {
if 는 다른 언어와 비슷한 분기지만 러스트에서는 조건에 괄호가 필요 없다: `if n > 0 { ... } else if n < 0 { ... } else { ... }`. 각 블록은 중괄호로 감싸야 하고, 조건은 반드시 bool 이어야 한다 — 정수를 조건 자리에 그냥 넣는 것은 컴파일 오류다. 0이 거짓이고 나머지가 참으로 취급되는 다른 언어의 관행이 러스트에는 없다.

if 는 식으로도 쓸 수 있어서 `let` 에 바로 대입할 수 있다. `let sign = if n >= 0 { 1 } else { -1 };` 처럼 쓰면 if 와 else 각 블록의 마지막 식이 sign 에 대입된다. 이때 두 블록의 마지막 식은 반드시 같은 타입이어야 하고, else 를 아예 생략하면 조건이 거짓일 때 대입할 값이 없어 컴파일이 실패한다.

반복에는 while 과 loop 두 가지가 있다. while 은 조건이 참인 동안 반복하고, loop 는 조건 없이 무한히 반복하다가 break 를 만나면 멈춘다. loop 는 `break 값;` 처럼 값을 들고 빠져나올 수 있어서, 반복을 몇 번 해야 끝날지 미리 알 수 없는 상황에 특히 유용하다 — while 로는 어색하게 표현해야 하는 경우를 loop + break 로 자연스럽게 쓸 수 있다.
}

@Example(id: control-flow-example, language: rust, expected: expected/rust-control-flow-if-loop.txt) {
if·else if·else 로 분기하고, if 를 식으로 대입하고, while 과 loop + break 로 각각 반복한다.

```rust
fn main() {
    let n = -3;
    if n > 0 {
        println!("{}는 양수", n);
    } else if n < 0 {
        println!("{}는 음수", n);
    } else {
        println!("{}는 영", n);
    }

    let sign = if n >= 0 { 1 } else { -1 };
    println!("부호: {}", sign);

    let mut count = 0;
    while count < 3 {
        println!("while: {}", count);
        count = count + 1;
    }

    let mut i = 0;
    let doubled = loop {
        i = i + 1;
        if i == 4 {
            break i * 2;
        }
    };
    println!("loop 결과: {}", doubled);
}
```
}

@Blank(id: control-flow-blank, language: rust) {
if 를 식으로 써서 String 을 바로 돌려주는 함수를 완성하자.

```rust
fn classify(n: i32) -> String {
    ___1___ n > 0 {
        String::from("양수")
    } ___2___ {
        String::from("양수 아님")
    }
}

fn main() {
    println!("{}", classify(5));
}
```

@Answer(slot: 1) {
`if`
}

@Answer(slot: 2) {
`else`
}
}

@Task(id: control-flow-task, language: rust, starter: starters/rust-control-flow-if-loop.rs, tests: tests/rust-control-flow-if-loop.rs, solution: solutions/rust-control-flow-if-loop.rs) {
n 이 0 이 될 때까지 1씩 줄이면서 몇 번 줄였는지 세어 돌려주는 함수 `countdown_steps` 를 작성하라. n 은 항상 0 이상이라고 가정한다. `countdown_steps(5)` 는 `5` 를, `countdown_steps(0)` 은 `0` 을 돌려줘야 한다.

@Hint {
`remaining` 과 `steps` 두 개의 mut 변수를 0 부터, 혹은 n 부터 시작해 두어라.
}

@Hint {
while remaining > 0 조건 안에서 remaining 을 줄이고 steps 를 늘려라.
}

@Hint {
n 이 0 이면 while 조건이 처음부터 거짓이라 steps 는 0 으로 남는다.
}
}

@Quiz(id: control-flow-quiz, answer: compile-error-else-required) {
@Question {
if 를 식으로 써서 let 에 대입할 때 else 를 생략하면 어떻게 될까요?
}

@Choice(id: compile-error-else-required) {
else 가 없으면 조건이 거짓일 때 값이 없어 컴파일 오류가 난다
}

@Choice(id: default-zero) {
else 가 없으면 자동으로 0 같은 기본값이 대입된다
}

@Choice(id: runtime-panic-no-else) {
컴파일은 되고 실행 중 조건이 거짓이면 패닉한다
}

@Choice(id: type-any) {
타입이 자동으로 Option 이 되어 문제없이 컴파일된다
}

@Explanation {
if 를 식으로 쓸 때는 참·거짓 두 분기가 같은 타입의 값을 만들어야 한다. else 가 없으면 조건이 거짓일 때 대입할 값이 없어 타입을 맞출 수 없으므로 컴파일 오류가 난다. 자동으로 기본값이 들어가거나 타입이 Option 으로 바뀌는 일은 없고, 이 오류는 실행 전 컴파일 단계에서 이미 걸린다.
}
}

@Reflection(id: control-flow-reflection) {
@Prompt(id: why-bool-condition-required) {
러스트가 정수를 조건 자리에 그대로 못 쓰게 막고 반드시 bool 만 허용하는 것이 어떤 실수를 막아줄지 생각해 보세요.
}

@Prompt(id: loop-vs-while) {
조건을 미리 알 수 없어 loop 와 break 를 써야 하는 상황을 하나 떠올려, 같은 것을 while 로 억지로 흉내 낸다면 무엇이 번거로울지 적어 보세요.
}
}
