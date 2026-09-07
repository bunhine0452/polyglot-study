@Concept(id: for-ranges-concept) {
for 는 반복자(iterator)를 따라 도는 반복문이다. 가장 흔한 형태는 범위와 함께 쓰는 것으로, `for i in 0..5 { ... }` 는 i 가 0, 1, 2, 3, 4 를 차례로 돌지만 끝값 5는 포함하지 않는다. 끝값까지 포함하고 싶다면 `..=` 를 써서 `0..=5` 라고 적으면 5까지 포함해 여섯 번 돈다. while 로 인덱스를 손수 늘리고 조건을 검사하는 것보다 for 와 범위를 쓰면 시작·끝·증가가 한 줄에 담기고, 증가시키는 것을 잊어 무한 루프에 빠지는 실수 자체가 구조적으로 불가능해진다.

for 는 배열도 그대로 돌 수 있다. `let numbers = [10, 20, 30]; for n in numbers { ... }` 처럼 쓰면 n 이 배열의 원소를 순서대로 받는다. 인덱스를 따로 계산할 필요 없이 값 자체를 바로 쓸 수 있어서, 원소 하나하나를 처리하는 것이 목적이라면 이 형태가 가장 읽기 쉽다.

값과 함께 인덱스도 필요하다면 `.enumerate()` 를 쓴다. `for (i, n) in numbers.iter().enumerate() { ... }` 처럼 쓰면 i 에 0부터 시작하는 인덱스가, n 에 그 위치의 값이 들어온다. 인덱스와 값을 한 번에 묶어 꺼내 주므로 직접 카운터 변수를 두고 늘리는 것보다 안전하고 간결하다.
}

@Example(id: for-ranges-example, language: rust, expected: expected/rust-for-and-ranges.txt) {
반열림 범위, 닫힌 범위, 배열 순회, enumerate 를 차례로 본다.

```rust
fn main() {
    for i in 0..5 {
        println!("range: {}", i);
    }

    for i in 1..=3 {
        println!("inclusive: {}", i);
    }

    let numbers = [10, 20, 30];
    for n in numbers {
        println!("value: {}", n);
    }

    for (i, n) in numbers.iter().enumerate() {
        println!("[{}] = {}", i, n);
    }
}
```
}

@Blank(id: for-ranges-blank, language: rust) {
인덱스와 값을 함께 얻는 호출과, 3을 포함하지 않는 범위를 채우자.

```rust
fn main() {
    let letters = ['a', 'b', 'c'];
    for (i, c) in letters.iter().___1___() {
        println!("{}{}", i, c);
    }

    for i in 0___2___3 {
        println!("n={}", i);
    }
}
```

@Answer(slot: 1) {
`enumerate`
}

@Answer(slot: 2) {
`..`
}
}

@Task(id: for-ranges-task, language: rust, starter: starters/rust-for-and-ranges.rs, tests: tests/rust-for-and-ranges.rs, solution: solutions/rust-for-and-ranges.rs) {
정수 세 개로 이루어진 배열을 받아 합을 구하는 함수 `sum_three` 를 작성하라. for 로 배열을 순회하며 더하라. `sum_three([1, 2, 3])` 은 `6` 을, `sum_three([0, 0, 0])` 은 `0` 을 돌려줘야 한다.

@Hint {
`for n in nums` 로 배열의 각 원소를 순서대로 받을 수 있다.
}

@Hint {
`let mut total = 0;` 로 시작해 반복마다 total 에 더하라.
}

@Hint {
마지막 줄에 total 만 남기면 그 값이 반환값이 된다.
}
}

@Quiz(id: for-ranges-quiz, answer: three-times-1-2-3) {
@Question {
`for i in 1..4` 를 실행하면 i 는 몇 번, 어떤 값들로 반복될까요?
}

@Choice(id: three-times-1-2-3) {
3번 — 1, 2, 3
}

@Choice(id: four-times-1-2-3-4) {
4번 — 1, 2, 3, 4
}

@Choice(id: three-times-2-3-4) {
3번 — 2, 3, 4
}

@Choice(id: four-times-0-1-2-3) {
4번 — 0, 1, 2, 3
}

@Explanation {
1..4 는 시작값 1은 포함하고 끝값 4는 포함하지 않는 반열림 범위라서 1, 2, 3 세 번만 반복한다. 4까지 포함하려면 1..=4 처럼 ..= 를 써야 하고, 0부터 시작하지도 않으므로 0을 포함하는 선택지도 틀렸다.
}
}

@Reflection(id: for-ranges-reflection) {
@Prompt(id: range-vs-manual-index) {
for 와 범위를 쓰는 것과 while 로 인덱스를 손수 늘리는 것을 비교했을 때, 어떤 실수가 구조적으로 사라지는지 적어 보세요.
}

@Prompt(id: when-need-enumerate) {
값만 필요할 때와 인덱스도 함께 필요할 때를 구분해서, enumerate 를 언제 써야 할지 예를 들어 보세요.
}
}
