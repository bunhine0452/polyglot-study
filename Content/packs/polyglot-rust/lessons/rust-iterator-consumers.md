@Concept(id: rust-iter-consumers-concept) {
`map`·`filter` 가 반복자를 반복자로 바꾸는 것과 달리, 이번에 볼 메서드들은 반복자를 값 하나로 **접는다**. 가장 단순한 둘은 `sum()` — 모든 원소를 더한 합계 — 과 `count()` — 원소의 개수 — 다. 둘 다 직접 for 루프로 짤 수도 있는 아주 흔한 패턴이라 언어가 이름을 붙여 준 것뿐이다.

`sum` 과 `count` 는 각각 딱 한 가지 방식으로만 접는다. 임의의 방식으로 접고 싶다면 `fold` 를 쓴다. `fold(초깃값, |누적값, 원소| 새_누적값)` 은 초깃값에서 시작해 원소를 하나씩 보며 누적값을 계속 새로 계산해 나간다 — 마지막에 남는 누적값이 fold 전체의 결과다. sum 은 사실 `fold(0, |acc, n| acc + n)` 과 같고, count 는 `fold(0, |acc, _| acc + 1)` 과 같다. fold 가 이 둘을 포함해 훨씬 넓은 범위의 계산을 표현할 수 있는 더 일반적인 도구인 셈이다.

`find` 와 `any` 는 조건에 맞는 원소를 찾는다는 점에서 비슷하지만 돌려주는 것이 다르다. `find` 는 조건에 맞는 **첫 원소 자체**를 `Option` 으로 돌려주고, `any` 는 그런 원소가 있는지 없는지 `bool` 로만 돌려준다. 원소의 값이 필요 없이 "있다/없다" 만 알면 될 때는 `any` 가, 찾은 값을 이어서 써야 할 때는 `find` 가 어울린다.

이 메서드들은 모두 반복자를 **소비**한다 — 한 번 sum 이나 find 를 호출하고 나면 그 반복자는 이미 끝까지 읽힌 상태라 다시 쓸 수 없다. 같은 데이터로 다른 계산을 또 하고 싶다면 `values.iter()` 를 다시 호출해 새 반복자를 만들어야 한다.
}

@Example(id: rust-iter-consumers-example, language: rust, expected: expected/rust-iterator-consumers.txt) {
같은 벡터에 대해 sum, count, fold, find, any 를 각각 새 반복자로 호출해 값 하나씩으로 접어 본다.

```rust
fn main() {
    let numbers = vec![1, 2, 3, 4, 5, 6];

    let total: i32 = numbers.iter().sum();
    println!("합계: {}", total);

    let count = numbers.iter().filter(|&&n| n % 2 == 0).count();
    println!("짝수 개수: {}", count);

    let product = numbers.iter().fold(1, |acc, n| acc * n);
    println!("곱: {}", product);

    match numbers.iter().find(|&&n| n > 4) {
        Some(value) => println!("4보다 큰 첫 값: {}", value),
        None => println!("없습니다"),
    }

    let has_negative = numbers.iter().any(|&n| n < 0);
    println!("음수가 있는가: {}", has_negative);
}
```
}

@Blank(id: rust-iter-consumers-blank, language: rust) {
합계를 구하는 소비자와, 조건을 만족하는 원소가 있는지 보는 소비자를 채워 완성하자.

```rust
fn main() {
    let numbers = vec![2, 4, 6];
    let total: i32 = numbers.iter().___1___();
    let has_big = numbers.iter().___2___(|&n| n > 5);
    println!("{} {}", total, has_big);
}
```

@Answer(slot: 1) {
`sum`
}

@Answer(slot: 2) {
`any`
}
}

@Task(id: rust-iter-consumers-task, language: rust, starter: starters/rust-iterator-consumers.rs, tests: tests/rust-iterator-consumers.rs, solution: solutions/rust-iterator-consumers.rs) {
정수 벡터 `values` 와 기본값 `default` 를 받아, `values` 가 비어 있으면 `default` 를, 그렇지 않으면 `values` 의 최댓값을 돌려주는 함수 `max_or_default` 를 `fold` 로 완성하라. 음수만 있는 벡터에서도 올바른 최댓값을 찾아야 한다.

@Hint {
values.is_empty() 로 먼저 빈 벡터를 걸러내고 default 를 돌려줘라.
}

@Hint {
fold 의 초깃값으로 values[0] 을 쓰면 첫 원소부터 비교를 시작할 수 있다.
}

@Hint {
fold 의 클로저에서는 매 원소마다 x 와 acc 중 더 큰 쪽을 다음 누적값으로 남겨라.
}
}

@Quiz(id: rust-iter-consumers-quiz, answer: value-vs-bool) {
@Question {
`find` 와 `any` 는 둘 다 조건에 맞는 원소를 찾는다는 점이 비슷하다. 이 둘의 핵심적인 차이는 무엇인가?
}

@Choice(id: value-vs-bool) {
find 는 조건에 맞는 첫 원소를 Option 으로 돌려주고, any 는 있는지 없는지만 bool 로 돌려준다
}

@Choice(id: count-vs-first) {
find 는 조건에 맞는 원소의 개수를, any 는 첫 원소를 돌려준다
}

@Choice(id: any-faster-claim) {
any 는 항상 컴파일 시점에 계산되지만 find 는 실행 중에 계산된다
}

@Choice(id: find-panics) {
조건에 맞는 원소가 없을 때 find 는 패닉하고 any 는 false 를 돌려준다
}

@Explanation {
find 는 조건을 만족하는 첫 원소 자체가 필요할 때 쓰고 Option<&T> 를 돌려준다 — 없으면 None 이다. any 는 원소 자체가 아니라 '그런 원소가 존재하는가' 라는 참/거짓만 필요할 때 쓴다. 개수를 세는 것은 count 의 역할이고, 없을 때 find 가 패닉을 일으키는 일도 없다 — 그 경우도 그냥 None 으로 표현된다.
}
}

@Reflection(id: rust-iter-consumers-reflection) {
@Prompt(id: fold-generality) {
sum과 count가 사실 fold의 특수한 경우라는 것을 배웠습니다. 항상 fold만 쓰지 않고 sum·count라는 이름이 따로 있는 이유가 무엇일지 생각해 보세요.
}

@Prompt(id: consumed-iterator) {
반복자가 한 번 소비되면 다시 쓸 수 없다는 것을 확인했습니다. 같은 벡터로 합계와 최댓값을 모두 구하고 싶다면 코드를 어떻게 짜야 할지 적어 보세요.
}
}
