@Concept(id: selection-sort-concept) {
선택 정렬은 반대로 움직인다. 매 단계마다 아직 정렬되지 않은 구간 전체를 훑어 가장 작은 값을 찾고, 그 값을 구간의 맨 앞과 통째로 맞바꾼다. 정렬된 부분은 앞에서부터 한 칸씩 늘어난다.

비교 횟수는 버블 정렬과 같은 자릿수다 — 바깥 반복마다 안쪽에서 남은 구간을 다 훑으므로 여전히 대략 n * n / 2 번 비교해 O(n^2) 이다. 다른 것은 교환 횟수다. 버블 정렬은 순서가 바뀐 이웃을 볼 때마다 교환하니 한 패스에 최대 n번 교환할 수 있지만, 선택 정렬은 바깥 반복 한 번에 **딱 한 번만 교환한다** — 최솟값을 찾는 동안은 비교만 하고, 자리를 정할 때 한 번 맞바꾼다. 그래서 교환 비용이 비교 비용보다 훨씬 큰 상황(쓰기가 느린 저장 장치 등)에서는 선택 정렬이 유리하다.

이 '통째로 맞바꾸는' 방식 때문에 선택 정렬은 안정적이지 않을 수 있다. 값이 같은 두 원소가 있을 때, 뒤에 있던 최솟값이 앞으로 튀어오면서 그 사이에 있던 같은 값을 뛰어넘어 원래 순서를 뒤바꿀 수 있다. 예를 들어 [5a, 5b, 1] (5a 와 5b 는 값이 같지만 원래 순서를 구분하려고 붙인 표시다)을 정렬하면, 1을 맨 앞으로 옮기며 5a 와 1이 자리를 바꾸는 순간 5a 는 5b 뒤로 밀려난다 — 원래는 5a 가 먼저였는데 정렬 후에는 5b 가 먼저 온다.

@Visualize(id: selection-sort, frames: visuals/selection-sort.json) {
선택 정렬이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: selection-sort-example, language: rust, expected: expected/algorithms-selection-sort.txt) {
매 바깥 반복이 남은 구간에서 최솟값을 찾아 한 번만 교환하는 과정을 찍어 본다.

```rust
fn main() {
    let mut xs = [5, 2, 4, 1, 3];
    let n = xs.len();
    for i in 0..n {
        let mut min_idx = i;
        for j in (i + 1)..n {
            if xs[j] < xs[min_idx] {
                min_idx = j;
            }
        }
        xs.swap(i, min_idx);
        println!("{}번째 자리 확정: 최솟값 {} (원래 {}번 자리) -> {:?}", i + 1, xs[i], min_idx, xs);
    }
}
```
}

@Blank(id: selection-sort-blank, language: rust) {
남은 구간에서 더 작은 값을 만났을 때만 min_idx 를 갱신해야 한다. 그 조건은 무엇일까?

```rust
fn find_min_index(xs: &[i32], start: usize) -> usize {
    let mut min_idx = start;
    for j in (start + 1)..xs.len() {
        if xs[j] ___1___ xs[min_idx] {
            min_idx = j;
        }
    }
    min_idx
}

fn main() {
    let xs = [5, 2, 4, 1, 3];
    println!("{}", find_min_index(&xs, 0));
}
```

@Answer(slot: 1) {
`<`
}
}

@Task(id: selection-sort-task, language: rust, starter: starters/algorithms-selection-sort.rs, tests: tests/algorithms-selection-sort.rs, solution: solutions/algorithms-selection-sort.rs) {
`Vec<i32>` 를 오름차순으로 제자리 정렬하세요. i번째 자리를 정할 때 i 이후 구간에서 최솟값의 인덱스를 찾고, 그 자리와 i번 자리를 딱 한 번 교환해야 합니다 — 매 비교마다 교환하는 방식은 이 레슨의 답이 아닙니다.

@Hint {
min_idx 를 i로 시작해서, i+1부터 끝까지 훑으며 더 작은 값을 만나면 min_idx 를 갱신해라.
}

@Hint {
안쪽 반복이 끝난 뒤에야 xs.swap(i, min_idx) 를 한 번 호출해라 — 훑는 동안은 교환하지 않는다.
}

@Hint {
min_idx 가 i 그대로면 swap 은 제자리 교환이라 상관없다.
}
}

@Quiz(id: selection-sort-quiz, answer: jump-swap) {
@Question {
선택 정렬이 안정 정렬이 아닐 수 있는 이유로 가장 알맞은 것은?
}

@Choice(id: complexity) {
비교 횟수가 O(n^2)이라서
}

@Choice(id: jump-swap) {
최솟값을 찾은 뒤 먼 자리와 통째로 맞바꾸면서 같은 값의 원래 순서가 바뀔 수 있어서
}

@Choice(id: linked-list-only) {
배열이 아니라 연결 리스트에서만 동작해서
}

@Explanation {
최솟값을 맨 앞과 통째로 교환하는 과정에서, 그 사이에 있던 같은 값의 원소를 건너뛰며 순서가 뒤바뀔 수 있다. 이것이 불안정성의 원인이다.
}
}

@Reflection(id: selection-sort-reflection) {
@Prompt(id: expensive-swap) {
교환 비용이 비교 비용보다 훨씬 큰 상황을 하나 떠올리고, 그런 상황에서 선택 정렬이 버블 정렬보다 유리한 이유를 적어 보세요.
}

@Prompt(id: make-it-stable) {
선택 정렬을 안정적으로 만들려면 '통째로 교환' 대신 무엇을 해야 할지 생각해 보세요(힌트: 최솟값을 자리별로 한 칸씩 밀어 넣는 방법).
}
}
