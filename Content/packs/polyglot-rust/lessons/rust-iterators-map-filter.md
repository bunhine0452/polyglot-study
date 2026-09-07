@Concept(id: rust-iter-mapfilter-concept) {
지금까지 벡터의 각 원소를 바꾸거나 골라내려면 빈 벡터를 만들고 `for` 로 돌며 하나씩 `push` 하는 식으로 썼다. 반복자(iterator)는 이 패턴을 한 단계 더 추상화한 것이다. `values.iter()` 는 벡터를 한 번에 하나씩 내주는 반복자를 만들고, 그 위에 `map`·`filter` 같은 메서드를 이어 붙여 "각 원소를 어떻게 바꿀지", "어떤 원소만 남길지" 를 선언적으로 적을 수 있다.

`map(|n| n * 2)` 처럼 세로줄 사이에 매개변수를 적은 뒤 바로 식을 쓰는 것은 이름 없는 짧은 함수를 그 자리에서 만드는 문법이다. `map` 은 반복자의 각 원소에 이 함수를 적용한 새 반복자를 만든다. `filter` 는 함수 대신 `true`/`false` 를 돌려주는 조건을 받아, 그 조건이 `true` 인 원소만 통과시킨 새 반복자를 만든다.

여기서 중요한 성질이 하나 있다 — `map`, `filter` 는 그 자체로는 아무 것도 계산하지 않는다. "이런 규칙으로 변환하겠다" 는 계획만 반복자에 쌓일 뿐, 실제로 하나씩 꺼내 계산이 실행되는 것은 그 반복자를 최종적으로 **소비**하는 순간이다. 이런 성질을 게으르다(lazy)고 부른다. `collect()` 가 바로 그 소비자 중 하나로, 쌓아 둔 변환 규칙을 실제로 하나씩 적용해 그 결과를 `Vec` 같은 구체적인 자료구조로 모아 담는다.

`collect()` 는 어떤 자료구조로 모을지 스스로 알 수 없어서 대부분 `let doubled: Vec<i32> = ...` 처럼 타입 표기가 필요하다. 타입 표기가 없으면 컴파일러가 "무엇으로 모아야 할지 모르겠다" 는 오류를 낸다 — collect 를 쓸 때 타입 오류를 만나면 가장 먼저 변수에 타입을 적어 뒀는지부터 확인하면 된다.
}

@Example(id: rust-iter-mapfilter-example, language: rust, expected: expected/rust-iterators-map-filter.txt) {
map으로 모든 원소를 두 배로 만들고, filter로 짝수만 남기고, 둘을 이어 붙여 짝수만 두 배로 만든 결과를 각각 확인한다.

```rust
fn main() {
    let numbers = vec![1, 2, 3, 4, 5, 6];

    let doubled: Vec<i32> = numbers.iter().map(|n| n * 2).collect();
    println!("{:?}", doubled);

    let evens: Vec<i32> = numbers.iter().filter(|&&n| n % 2 == 0).map(|n| *n).collect();
    println!("{:?}", evens);

    let even_doubled: Vec<i32> = numbers
        .iter()
        .filter(|&&n| n % 2 == 0)
        .map(|n| n * 2)
        .collect();
    println!("{:?}", even_doubled);
}
```
}

@Blank(id: rust-iter-mapfilter-blank, language: rust) {
각 원소를 제곱해 Vec으로 모으도록 map과 collect를 채워 완성하자.

```rust
fn main() {
    let numbers = vec![1, 2, 3, 4];
    let squared: Vec<i32> = numbers.iter().___1___(|n| n * n).___2___();
    println!("{:?}", squared);
}
```

@Answer(slot: 1) {
`map`
}

@Answer(slot: 2) {
`collect`
}
}

@Task(id: rust-iter-mapfilter-task, language: rust, starter: starters/rust-iterators-map-filter.rs, tests: tests/rust-iterators-map-filter.rs, solution: solutions/rust-iterators-map-filter.rs) {
정수 벡터 `values` 에서 짝수만 남기고, 남은 짝수를 각각 제곱한 값을 새 벡터로 돌려주는 함수 `square_evens` 를 완성하라. `iter`·`filter`·`map`·`collect` 를 이어 붙여 구현한다. 짝수가 하나도 없거나 벡터가 비어 있으면 빈 벡터를 돌려준다. 음수 짝수도 제곱해서 남겨야 한다.

@Hint {
values.iter() 로 반복자를 만든 뒤 filter(|&&n| n % 2 == 0) 로 짝수만 남겨라.
}

@Hint {
filter 뒤에 .map(|n| n * n) 을 이어 붙이면 남은 원소마다 제곱을 적용한다.
}

@Hint {
마지막에 .collect() 를 붙이고, 반환 타입이 이미 Vec<i32> 로 정해져 있으니 별도 타입 표기는 필요 없다.
}
}

@Quiz(id: rust-iter-mapfilter-quiz, answer: nothing-runs) {
@Question {
`numbers.iter().map(|n| n * 2)` 라는 줄만 있고 그 결과를 `collect()` 하거나 다른 방식으로 쓰지 않는다면 무슨 일이 일어나는가?
}

@Choice(id: nothing-runs) {
map 에 넘긴 계산이 실제로는 실행되지 않는다
}

@Choice(id: runs-anyway) {
collect 가 없어도 map 의 계산은 즉시 실행된다
}

@Choice(id: compile-error-required) {
collect 가 없으면 반드시 컴파일 오류가 난다
}

@Choice(id: prints-nothing) {
아무 값도 없이 빈 반복자가 만들어져 이후 사용이 불가능해진다
}

@Explanation {
map 과 filter 는 게으르다 — 반복자에 변환 규칙을 쌓아 둘 뿐, 실제로 각 원소를 꺼내 계산하는 일은 collect 같은 소비자가 호출될 때 비로소 일어난다. 소비되지 않은 반복자는 컴파일 경고(사용하지 않는 값)는 낼 수 있어도 반드시 컴파일 오류가 나는 것은 아니고, 계산이 미리 실행되지도 않는다. 반복자 자체가 쓸모없어지는 것도 아니다 — 나중에 소비하면 그때 계산된다.
}
}

@Reflection(id: rust-iter-mapfilter-reflection) {
@Prompt(id: lazy-benefit) {
map과 filter가 즉시 계산하지 않고 계획만 쌓아 두는 것이 어떤 상황에서 유리할지 생각해 보세요 (힌트: 아주 긴 체인을 이어 붙이거나, 중간에 결과가 필요 없어질 수도 있는 경우).
}

@Prompt(id: for-loop-vs-chain) {
이번 과제를 for 루프와 빈 Vec, push 로 구현했다면 코드가 몇 줄이나 됐을지, iter().filter().map().collect() 체인과 비교했을 때 어느 쪽이 '무엇을 하는지' 더 잘 드러내는지 적어 보세요.
}
}
