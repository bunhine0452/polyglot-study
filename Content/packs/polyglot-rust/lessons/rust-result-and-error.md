@Concept(id: rust-result-concept) {
`Option<T>` 은 값이 있는지 없는지만 말해 줄 뿐 없는 이유는 말해주지 않는다. 실패할 수 있는 일을 하는데 **왜** 실패했는지도 전달하고 싶다면 `Result<T, E>` 를 쓴다. 성공하면 결과를 담아 `Ok(값)`, 실패하면 이유를 담아 `Err(오류)` 를 돌려준다 — `Option` 처럼 이것도 결국 enum 이라 `match` 로 가른다.

많은 언어는 실패를 예외(exception)로 던지고, 호출자가 그 예외를 처리하지 않으면 조용히 위로 전파되다가 결국 프로그램을 죽인다. 러스트의 `Result` 는 반환 타입에 그대로 드러난다 — 함수 시그니처만 봐도 이 함수가 실패할 수 있는지, 실패하면 어떤 타입의 오류를 내는지 알 수 있고, 컴파일러가 그 값을 무시하도록 두지 않는다.

`Result` 를 반환하는 함수를 여러 겹 호출하다 보면 각 단계마다 `match` 로 오류를 확인하고 다시 넘기는 코드가 반복되기 쉽다. `?` 연산자는 이 반복을 없애준다. `let x = 함수()?;` 는 `함수()` 가 `Ok(값)` 이면 그 값을 x 에 넣고 계속 진행하고, `Err(오류)` 면 그 오류를 **그대로 지금 함수의 반환값으로 즉시 돌려주고 함수를 끝낸다**. 그래서 `?` 를 쓰는 함수의 반환 타입도 같은 오류 타입의 `Result` 여야 한다.

`?` 는 겉보기엔 오류를 감춘 것 같지만 실제로는 아무것도 감추지 않는다 — 오류가 나면 즉시 위로 전달될 뿐, 무시되는 경우는 없다. 반복되는 match 를 줄여줄 뿐 실패를 처리해야 한다는 원칙 자체는 그대로 지켜진다.
}

@Example(id: rust-result-example, language: rust, expected: expected/rust-result-and-error.txt) {
0으로 나누면 Err 를 돌려주는 함수와, 그 함수를 ? 로 호출해 오류를 그대로 전파하는 함수를 함께 본다.

```rust
fn divide(a: i32, b: i32) -> Result<i32, String> {
    if b == 0 {
        Err(String::from("0으로 나눌 수 없습니다"))
    } else {
        Ok(a / b)
    }
}

fn double_quotient(a: i32, b: i32) -> Result<i32, String> {
    let quotient = divide(a, b)?;
    Ok(quotient * 2)
}

fn main() {
    match divide(10, 2) {
        Ok(value) => println!("몫: {}", value),
        Err(message) => println!("오류: {}", message),
    }

    match divide(10, 0) {
        Ok(value) => println!("몫: {}", value),
        Err(message) => println!("오류: {}", message),
    }

    match double_quotient(9, 3) {
        Ok(value) => println!("두 배: {}", value),
        Err(message) => println!("오류: {}", message),
    }

    match double_quotient(9, 0) {
        Ok(value) => println!("두 배: {}", value),
        Err(message) => println!("오류: {}", message),
    }
}
```
}

@Blank(id: rust-result-blank, language: rust) {
양수면 성공을, 아니면 실패를 돌려주도록 Ok 와 Err 를 채워 완성하자.

```rust
fn parse_positive(n: i32) -> Result<i32, String> {
    if n > 0 {
        ___1___(n)
    } else {
        ___2___(String::from("양수가 아닙니다"))
    }
}

fn main() {
    match parse_positive(5) {
        Ok(v) => println!("좋음: {}", v),
        Err(e) => println!("나쁨: {}", e),
    }
}
```

@Answer(slot: 1) {
`Ok`
}

@Answer(slot: 2) {
`Err`
}
}

@Task(id: rust-result-task, language: rust, starter: starters/rust-result-and-error.rs, tests: tests/rust-result-and-error.rs, solution: solutions/rust-result-and-error.rs) {
정수 벡터 `values` 의 합을 구한 뒤 `divisor` 로 나눈 몫을 돌려주는 함수 `safe_divide_sum` 을 완성하라. 이미 주어진 `divide` 함수는 `divisor` 가 0 이면 `Err(String::from("0으로 나눌 수 없습니다"))` 를, 아니면 `Ok(몫)` 을 돌려준다. `safe_divide_sum` 은 합계를 구한 뒤 `divide` 를 `?` 로 호출해 오류가 나면 그대로 전달하고, 성공하면 `Ok(몫)` 을 돌려준다. 빈 벡터의 합은 0 으로 취급한다.

@Hint {
먼저 total 을 0 으로 시작해 for 루프로 values 의 합을 구하라.
}

@Hint {
divide(total, divisor)? 라고 쓰면 실패했을 때 그 Err 가 safe_divide_sum 의 반환값으로 즉시 나간다.
}

@Hint {
? 를 통과했다면 성공한 것이므로, 그 값을 Ok 로 감싸 돌려줘야 한다.
}
}

@Quiz(id: rust-result-quiz, answer: propagate) {
@Question {
함수 안에서 `Result` 를 반환하는 다른 함수를 호출한 결과에 `?` 를 붙였다. 그 결과가 `Err` 였다면 무슨 일이 일어나는가?
}

@Choice(id: propagate) {
그 Err 값을 지금 함수의 반환값으로 즉시 돌려주고 함수를 끝낸다
}

@Choice(id: panic) {
프로그램이 패닉을 일으키며 즉시 중단된다
}

@Choice(id: ignore) {
Err 를 무시하고 다음 줄부터 계속 실행한다
}

@Choice(id: convert-ok) {
Err 을 자동으로 Ok 로 바꿔 계속 실행한다
}

@Explanation {
? 는 Err 를 만나면 그 값을 그대로 현재 함수의 반환값으로 즉시 반환하며 함수를 끝낸다 — 그래서 ? 를 쓰는 함수의 반환 타입도 같은 종류의 Result 여야 한다. 프로그램을 중단시키는 것은 unwrap() 같은 다른 메서드의 일이고, ? 는 Err 를 무시하지도, Ok 로 바꾸지도 않는다.
}
}

@Reflection(id: rust-result-reflection) {
@Prompt(id: result-vs-exception) {
예외를 던지는 언어에서는 호출자가 처리하지 않아도 컴파일은 되고, 실행하다 처리 안 된 예외를 만나야 문제를 알게 됩니다. Result 는 이 문제를 어느 시점으로 옮겨 놓는지 적어 보세요.
}

@Prompt(id: question-mark-tradeoff) {
safe_divide_sum 안에서 ? 대신 match 로 divide 의 결과를 직접 갈랐다면 코드가 어떻게 달라졌을지, 그리고 Ok 와 Err 를 각각 다르게 처리해야 하는 상황이라면 ? 로 충분할지 생각해 보세요.
}
}
