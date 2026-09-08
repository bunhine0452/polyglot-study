@Concept(id: scalar-concept) {
러스트의 정수·실수·불리언은 크기와 정밀도가 다른 여러 타입으로 나뉜다. 정수 리터럴에 타입을 적지 않으면 컴파일러가 기본으로 `i32` 를 고르고, 소수점이 있는 리터럴은 `f64` 를 고른다. 특별한 이유가 없다면 이 둘을 쓰는 게 무난하다 — i32 는 대부분의 플랫폼에서 다루기 빠른 정수 폭이고 f64 는 계산 오차가 가장 적은 실수 표현이기 때문이다.

타입을 명시하지 않아도 되는 것은 러스트가 값이 쓰이는 방식을 보고 타입을 되짚어 추론하기 때문이다 — 이것을 타입 추론이라 한다. 의도를 분명히 하고 싶거나 기본값과 다른 타입이 필요할 때는 `let count: i32 = 9;` 처럼 콜론 뒤에 타입을 적어 명시할 수 있다. 이미 정해진 값을 다른 타입으로 바꾸고 싶다면 `as` 로 변환한다 — `count as f64` 는 정수 count 를 실수로 바꾼 새 값을 만든다.

정수 나눗셈과 실수 나눗셈은 결과가 다르다. `7 / 2` 처럼 두 피연산자가 모두 정수면 소수점 아래를 버리고 `3` 을 돌려준다. 반면 `7.0 / 2.0` 처럼 실수끼리 나누면 `3.5` 를 그대로 돌려준다. 정수 나눗셈이 반올림이 아니라 절삭이라는 것을 모르면 평균이나 비율을 계산할 때 값이 왜 어긋나는지 한참을 헤매게 된다.
}

@Example(id: scalar-example, language: rust, expected: expected/rust-scalar-types-and-inference.txt) {
같은 값을 정수로 나눌 때와 실수로 나눌 때를 나란히 비교하고, as 로 타입을 바꿔 본다.

```rust
fn main() {
    let a: i32 = 7;
    let b: i32 = 2;
    println!("정수 나눗셈: {}", a / b);

    let x: f64 = 7.0;
    let y: f64 = 2.0;
    println!("실수 나눗셈: {:.1}", x / y);

    let inferred = 42;
    let converted = inferred as f64;
    println!("추론된 정수: {}", inferred);
    println!("f64 로 바꾼 값: {:.1}", converted);

    let is_greater: bool = a > b;
    println!("a가 b보다 큰가: {}", is_greater);
}
```
}

@Blank(id: scalar-blank, language: rust) {
count 의 타입을 명시하고, 나누기 전에 실수로 바꾸는 자리를 채우자.

```rust
fn main() {
    let count: ___1___ = 9;
    let ratio = count ___2___ f64 / 2.0;
    println!("ratio = {:.1}", ratio);
}
```

@Answer(slot: 1) {
`i32`
}

@Answer(slot: 2) {
`as`
}
}

@Task(id: scalar-task, language: rust, starter: starters/rust-scalar-types-and-inference.rs, tests: tests/rust-scalar-types-and-inference.rs, solution: solutions/rust-scalar-types-and-inference.rs) {
정수 두 개 `a`, `b` 를 받아 실수 나눗셈으로 평균을 구하는 함수 `average` 를 작성하라. 정수 나눗셈이 아니라 `f64` 로 바꾼 뒤 나눠야 소수점이 살아남는다는 점에 주의하라. `average(4, 5)` 는 `4.5` 를, `average(0, 0)` 은 `0.0` 을 돌려줘야 한다.

@Hint {
`a as f64` 로 정수를 실수로 바꿀 수 있다.
}

@Hint {
정수끼리 먼저 나누면 소수점이 버려지니, 나누기 전에 반드시 f64 로 바꿔라.
}

@Hint {
`(a as f64 + b as f64) / 2.0` 순서로 먼저 더한 뒤 나눠라.
}
}

@Quiz(id: scalar-quiz, answer: i32) {
@Question {
타입 표기 없이 `let x = 5;` 라고만 쓰면 x 의 타입은 무엇으로 추론될까요?
}

@Choice(id: i32) {
i32 — 정수 리터럴의 기본 타입이다
}

@Choice(id: i64) {
i64 — 러스트의 정수는 항상 64비트로 처리된다
}

@Choice(id: f64) {
f64 — 숫자 리터럴은 기본적으로 실수로 처리된다
}

@Choice(id: usize) {
usize — 인덱스에 쓰이는 타입이 기본으로 추론된다
}

@Explanation {
타입 표기가 없는 정수 리터럴은 다른 제약이 없는 한 i32 로 추론된다. i64 는 더 큰 정수 타입일 뿐 기본값이 아니고, f64 는 소수점이 있는 리터럴에만 적용되는 기본값이며, usize 는 인덱싱처럼 문맥이 요구할 때만 추론된다.
}
}

@Reflection(id: scalar-reflection) {
@Prompt(id: why-default-i32-f64) {
러스트가 정수는 i32, 실수는 f64 를 기본으로 고른 것이 여러분이 이전에 쓰던 언어와 어떻게 다르거나 비슷한지 적어 보세요.
}

@Prompt(id: integer-division-surprise) {
정수 나눗셈이 소수점을 버린다는 것을 모른 채 평균이나 비율을 계산하면 어떤 버그가 생길 수 있을지 예를 들어 보세요.
}
}
