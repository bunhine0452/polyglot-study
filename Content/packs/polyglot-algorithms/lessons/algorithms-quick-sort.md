@Concept(id: quick-sort-concept) {
퀵 정렬도 분할정복이지만 순서가 다르다. 병합 정렬은 먼저 나누고 나중에 합치며 정렬 작업을 병합 단계에서 하는데, 퀵 정렬은 나누는 단계(분할, partition) 자체가 정렬 작업을 한다.

분할은 피벗 하나를 고르고, 나머지 값을 피벗보다 작은 값과 크거나 같은 값 두 무리로 나눈 뒤 피벗을 그 경계 자리에 놓는다. 여기서는 마지막 원소를 피벗으로 쓴다. `i` 는 '피벗보다 작은 값들의 경계'를 가리키고, `j` 로 배열을 훑으며 `xs[j]` 가 피벗보다 작으면 그 값을 `i` 자리와 맞바꾸고 `i` 를 한 칸 옮긴다. 다 훑고 나면 피벗을 `i` 자리와 바꿔, 피벗의 왼쪽엔 작은 값만, 오른쪽엔 크거나 같은 값만 남긴다. 이 과정은 배열 안에서 값을 맞바꾸며 진행되므로(병합 정렬처럼 새 배열을 만들지 않는다) 제자리(in-place) 정렬이다.

분할이 끝나면 피벗은 이미 최종 자리에 있다. 이제 피벗 왼쪽 구간과 오른쪽 구간을 각각 재귀로 정렬하면 전체가 정렬된다. 분할이 매번 절반씩 균형 있게 나뉘면 병합 정렬과 같은 이유로 평균 O(n log n) 이 된다.

문제는 분할이 한쪽으로 완전히 치우칠 때다. 이미 정렬된 배열에 마지막 원소를 피벗으로 고르면, 피벗은 항상 그 구간에서 가장 큰 값이라 모든 값이 피벗보다 작은 쪽에 몰린다 — 구간이 매번 1개씩만 줄어들어 n + (n-1) + ... + 1 번 비교하게 되고, 이것이 최악의 경우 O(n^2) 이다.

@Visualize(id: quick-sort, frames: visuals/quick-sort.json) {
퀵 정렬이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: quick-sort-example, language: rust, expected: expected/algorithms-quick-sort.txt) {
마지막 원소를 피벗으로 삼아 배열을 작은 값과 큰 값으로 나누는 분할 과정을 찍어 본다.

```rust
fn partition(xs: &mut [i32]) -> usize {
    let pivot = xs[xs.len() - 1];
    let mut i = 0;
    for j in 0..xs.len() - 1 {
        if xs[j] < pivot {
            xs.swap(i, j);
            println!("{}번 자리와 {}번 자리 교환 (xs[{}] < 피벗 {}): {:?}", i, j, j, pivot, xs);
            i += 1;
        }
    }
    xs.swap(i, xs.len() - 1);
    println!("피벗 {} 을 {}번 자리로: {:?}", pivot, i, xs);
    i
}

fn main() {
    let mut xs = [5, 2, 8, 1, 9, 3];
    let p = partition(&mut xs);
    println!("분할 결과: {:?}, 피벗 위치 {}", xs, p);
}
```
}

@Blank(id: quick-sort-blank, language: rust) {
피벗보다 작은 값을 만났을 때만 경계 자리 i와 교환해 왼쪽으로 옮겨야 한다. 그 조건은 무엇일까?

```rust
fn partition(xs: &mut [i32]) -> usize {
    let pivot = xs[xs.len() - 1];
    let mut i = 0;
    for j in 0..xs.len() - 1 {
        if xs[j] ___1___ pivot {
            xs.swap(i, j);
            i += 1;
        }
    }
    xs.swap(i, xs.len() - 1);
    i
}

fn main() {
    let mut xs = [5, 2, 8, 1, 9, 3];
    let p = partition(&mut xs);
    println!("{:?} {}", xs, p);
}
```

@Answer(slot: 1) {
`<`
}
}

@Task(id: quick-sort-task, language: rust, starter: starters/algorithms-quick-sort.rs, tests: tests/algorithms-quick-sort.rs, solution: solutions/algorithms-quick-sort.rs) {
`&mut [i32]` 를 오름차순으로 제자리 정렬하세요. 피벗을 기준으로 분할한 뒤 그 결과로 나뉜 두 구간을 각각 재귀로 정렬하는 방식이어야 합니다 — 새 Vec 을 만들어 병합하는 방식은 이 레슨의 답이 아닙니다.

@Hint {
길이가 0이나 1인 슬라이스는 이미 정렬된 것으로 보고 그냥 반환해라(베이스 케이스).
}

@Hint {
partition 은 피벗보다 작은 값들을 앞쪽에 모으고, 피벗을 그 경계 자리로 옮긴 뒤 그 자리의 인덱스를 반환한다.
}

@Hint {
partition 이 반환한 위치 p 를 기준으로 xs[..p] 와 xs[p+1..] 를 각각 재귀로 정렬해라 — 피벗 자기 자신(xs[p])은 이미 제자리다.
}
}

@Quiz(id: quick-sort-quiz, answer: worst-case) {
@Question {
마지막 원소를 피벗으로 고르는 퀵 정렬에 이미 오름차순으로 정렬된 배열을 넣으면 어떤 일이 벌어질까?
}

@Choice(id: avg-case) {
매번 절반씩 나뉘어 평균과 같은 O(n log n)이 나온다
}

@Choice(id: worst-case) {
매번 피벗이 그 구간의 최댓값이라 한쪽에만 나머지가 몰려 O(n^2)이 된다
}

@Choice(id: instant) {
이미 정렬돼 있으므로 분할 없이 즉시 끝나 O(1)이다
}

@Explanation {
정렬된 배열에서 마지막 원소는 항상 그 구간의 최댓값이다. 그래서 모든 값이 피벗보다 작은 쪽으로만 몰리고, 구간이 한 번에 1개씩만 줄어들어 n+(n-1)+...+1, 즉 O(n^2)이 된다.
}
}

@Reflection(id: quick-sort-reflection) {
@Prompt(id: in-place-benefit) {
퀵 정렬은 병합 정렬과 달리 정렬 결과를 담을 새 배열을 만들지 않는다. 이것이 메모리 사용에서 어떤 이점이 있는지 적어 보세요.
}

@Prompt(id: random-pivot) {
피벗을 항상 마지막 원소로 고르는 대신 무작위로 고르면 최악의 경우를 피하는 데 어떻게 도움이 될지 생각해 보세요.
}
}
