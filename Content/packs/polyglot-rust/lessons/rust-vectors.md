@Concept(id: rust-vectors-concept) {
배열은 크기가 고정돼 있다. 원소를 몇 개 담을지 컴파일 시점에 정해야 하고, 하나를 더 넣고 싶어도 늘릴 수 없다. `Vec<T>` 는 크기가 실행 중에 자유롭게 늘고 주는 목록이다. 내부적으로는 힙에 원소들을 연속으로 저장해 두고, 공간이 모자라면 더 큰 메모리를 새로 할당해 옮기는 식으로 동작한다.

`Vec::new()` 로 빈 벡터를 만들고 `push` 로 하나씩 채울 수도 있고, 처음부터 값이 정해져 있다면 `vec![1, 2, 3]` 매크로가 더 짧다. 둘 다 결과는 같은 `Vec<T>` 다 — 어느 쪽을 쓸지는 값을 아는 시점의 문제일 뿐이다.

인덱스로 원소를 꺼낼 때는 `numbers[i]` 처럼 대괄호를 쓴다. 다만 `i` 가 벡터 길이 이상이면 컴파일이 아니라 **실행 중에 패닉**이 난다. 벡터의 길이는 실행 전에는 알 수 없는 값이라서 컴파일러가 미리 막아 줄 방법이 없기 때문이다. 배열의 고정 크기가 안전성의 대가로 유연함을 내주는 지점이 바로 여기다.

벡터를 `for` 로 순회할 때 `&scores` 처럼 참조로 돌면 각 원소를 빌리기만 하고 벡터의 소유권은 그대로 남는다. 그냥 `scores` 를 돌리면 반복이 끝난 뒤 벡터를 다시 쓸 수 없다 — 소유권이 이동해 버리기 때문이다. 합계를 구하는 것처럼 값을 읽기만 할 때는 거의 항상 참조로 순회한다.
}

@Example(id: rust-vectors-example, language: rust, expected: expected/rust-vectors.txt) {
vec! 로 만든 벡터를 인덱스로 읽고, Vec::new 와 push 로 채운 벡터의 길이를 확인한 뒤, 참조로 순회하며 합계를 구한다.

```rust
fn main() {
    let scores = vec![10, 20, 30];
    println!("첫 점수: {}", scores[0]);

    let mut names = Vec::new();
    names.push(String::from("눈송"));
    names.push(String::from("바람"));
    println!("이름 수: {}", names.len());

    let mut total = 0;
    for score in &scores {
        total += score;
    }
    println!("합계: {}", total);
}
```
}

@Blank(id: rust-vectors-blank, language: rust) {
벡터를 만드는 매크로와 원소를 더하는 메서드를 채워 완성하자.

```rust
fn main() {
    let mut numbers = ___1___![1, 2, 3];
    numbers.___2___(4);
    println!("마지막 원소: {}", numbers[3]);
}
```

@Answer(slot: 1) {
`vec`
}

@Answer(slot: 2) {
`push`
}
}

@Task(id: rust-vectors-task, language: rust, starter: starters/rust-vectors.rs, tests: tests/rust-vectors.rs, solution: solutions/rust-vectors.rs) {
정수 벡터 `values` 와 찾을 값 `target` 을 받아, `target` 과 같은 원소가 몇 번 나오는지 세어 돌려주는 함수 `count_value` 를 완성하라. `values` 가 비어 있거나 `target` 이 하나도 없으면 `0` 을 돌려준다. 음수도 그대로 셀 수 있어야 한다.

@Hint {
count 를 0 으로 시작해 for 로 values 를 순회하며 조건에 맞을 때마다 1 씩 늘려라.
}

@Hint {
`for &value in values` 처럼 & 패턴을 쓰면 value 가 i32 로 바로 나와 target 과 비교하기 쉽다.
}

@Hint {
끝까지 순회한 뒤 count 를 돌려주면 된다 — 일찍 반환할 필요는 없다.
}
}

@Quiz(id: rust-vectors-quiz, answer: panic) {
@Question {
벡터의 길이를 넘는 인덱스로 `numbers[i]` 를 읽으면 어떤 일이 일어나는가?
}

@Choice(id: panic) {
컴파일은 되지만 실행 중에 패닉이 나며 프로그램이 중단된다
}

@Choice(id: compile-error) {
컴파일 단계에서 바로 오류가 난다
}

@Choice(id: zero) {
0 이 기본값으로 채워져 반환된다
}

@Choice(id: silent-none) {
아무 값도 없이 조용히 넘어간다
}

@Explanation {
벡터의 길이는 실행 중에 바뀔 수 있는 값이라 컴파일러가 미리 알 수 없다. 그래서 범위를 벗어난 인덱스 접근은 컴파일 시점이 아니라 실행 중에 패닉으로 막힌다. 배열과 달리 벡터는 크기가 고정돼 있지 않기 때문에 이런 검사를 실행 시점으로 미룰 수밖에 없다 — 값을 채워 넣거나 조용히 넘어가면 잘못된 데이터를 진짜 값처럼 다루게 되므로 러스트는 그 대신 즉시 멈추는 쪽을 택한다.
}
}

@Reflection(id: rust-vectors-reflection) {
@Prompt(id: fixed-vs-growable) {
배열 대신 Vec 을 쓰면 크기 제한에서는 자유로워지지만 대가가 있습니다. 그 대가가 무엇일지 생각해 보세요 (힌트: 데이터가 어디에 저장되는가).
}

@Prompt(id: iterate-by-reference) {
합계를 구할 때 `for score in &scores` 처럼 참조로 순회했습니다. `&` 를 빼고 `for score in scores` 로 쓰면 무엇이 달라질지, 그리고 그 뒤에 scores 를 다시 쓰려고 하면 어떻게 될지 적어 보세요.
}
}
