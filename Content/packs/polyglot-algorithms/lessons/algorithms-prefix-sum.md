@Concept(id: prefix-sum-concept) {
구간 `[l, r]` 의 합을 구하는 질의가 여러 번 들어온다고 하자. 매번 `xs[l]` 부터 `xs[r]` 까지 새로 더하면 질의 하나에 O(n), q 번이면 O(n·q) 다.

누적합(prefix sum) 배열을 한 번 만들어 두면 이야기가 달라진다. `prefix[0] = 0`, `prefix[i + 1] = prefix[i] + xs[i]` 로 정의하면, `prefix[i]` 는 `xs[0..i]` 의 합이다 — 인덱스가 하나씩 밀려 있는 이유는 빈 구간(`prefix[0]`)도 표현하려는 것이다.

이제 구간 `[l, r]` (양끝 포함) 의 합은 `prefix[r + 1] - prefix[l]` 이다. `prefix[r + 1]` 은 `xs[0..=r]` 전체의 합이고 `prefix[l]` 은 그중 앞부분 `xs[0..l]` 의 합이므로, 빼면 딱 `xs[l..=r]` 만 남는다.

prefix 배열을 만드는 데 O(n), 이후 질의 하나는 뺄셈 한 번 O(1) 이다. 질의가 q 번이면 총 O(n + q) — 매번 새로 더하는 O(n·q) 보다 q 가 커질수록 압도적으로 유리하다.

@Visualize(id: prefix-sum, frames: visuals/prefix-sum.json) {
프리픽스 합이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: prefix-sum-example, language: rust, expected: expected/algorithms-prefix-sum.txt) {
prefix 배열을 만들고, 몇 개의 구간 합을 뺄셈으로 구해 본다.

```rust
fn main() {
    let xs = [4, 2, 7, 1, 5, 3, 8];

    let mut prefix = vec![0i64; xs.len() + 1];
    for i in 0..xs.len() {
        prefix[i + 1] = prefix[i] + xs[i] as i64;
    }
    println!("prefix = {:?}", prefix);

    let queries = [(0usize, 2usize), (3, 5), (1, 6), (0, 6)];
    for (l, r) in queries {
        let sum = prefix[r + 1] - prefix[l];
        println!("xs[{}..={}] 합 = {}", l, r, sum);
    }
}
```
}

@Blank(id: prefix-sum-blank, language: rust) {
`prefix[i + 1]` 은 `prefix[i]` 에 무엇을 더한 값일까?

```rust
fn build_prefix(xs: &[i32]) -> Vec<i64> {
    let mut prefix = vec![0i64; xs.len() + 1];
    for i in 0..xs.len() {
        prefix[i + 1] = prefix[i] + ___1___;
    }
    prefix
}

fn main() {
    let xs = [4, 2, 7, 1, 5];
    println!("{:?}", build_prefix(&xs));
}
```

@Answer(slot: 1) {
`xs[i] as i64`
}
}

@Task(id: prefix-sum-task, language: rust, starter: starters/algorithms-prefix-sum.rs, tests: tests/algorithms-prefix-sum.rs, solution: solutions/algorithms-prefix-sum.rs) {
`&[i32]` 와 구간 질의 목록 `&[(usize, usize)]` 을 받아, 각 `(l, r)` 에 대해 `xs[l..=r]` (양끝 포함) 의 합을 담은 `Vec<i64>` 를 돌려주세요. 질의마다 배열을 처음부터 다시 더하는 풀이는 테스트를 통과해도 이 레슨의 답이 아닙니다 — prefix 배열을 한 번만 만들고 각 질의는 뺄셈으로 답해야 합니다. 원소 값을 더한 합이 `i32` 범위를 넘을 수 있으니 prefix 는 `i64` 로 누적하세요.

@Hint {
prefix 배열의 길이는 `xs.len() + 1` 이다 — `prefix[0]` 은 항상 0.
}

@Hint {
`prefix[i + 1] = prefix[i] + xs[i] as i64` 로 한 번만 채워 두면 된다.
}

@Hint {
구간 `[l, r]` (양끝 포함) 의 합은 `prefix[r + 1] - prefix[l]` 이다.
}

@Hint {
`xs[i]` 는 `i32` 지만 prefix 는 `i64` 로 누적해야 합이 넘치지 않는다.
}
}

@Quiz(id: prefix-sum-quiz, answer: n-plus-q) {
@Question {
길이 n 인 배열에 구간 합 질의가 q 번 들어올 때, prefix 배열을 미리 만들어 두는 방식의 총 시간복잡도는?
}

@Choice(id: n-plus-q) {
O(n + q)
}

@Choice(id: n-times-q) {
O(n · q)
}

@Choice(id: n-log-n) {
O(n log n)
}

@Explanation {
prefix 배열을 만드는 데 O(n), 이후 질의 하나는 뺄셈 한 번이라 O(1) 이므로 q 번 질의는 O(q). 합쳐서 O(n + q) 다. 매번 구간을 새로 더하는 방식은 질의 하나에 O(n) 이 들어 O(n·q) 가 된다.
}
}

@Reflection(id: prefix-sum-reflection) {
@Prompt(id: mutable-array) {
배열의 원소 값이 질의 사이사이에 자주 바뀐다면 어떻게 될까요? prefix 배열은 원소 하나가 바뀔 때마다 그 뒤 전체를 다시 계산해야 합니다. 이런 상황에서 prefix sum 을 그대로 쓰면 어떤 손해가 생기는지 적어 보세요.
}

@Prompt(id: alternative) {
업데이트가 잦으면서도 구간 합을 빠르게 구해야 하는 상황이라면 어떤 자료구조나 접근이 필요할지 짐작해 보세요. (지금 정답을 알 필요는 없습니다 — 어떤 조건을 만족해야 하는지만 생각해 보세요.)
}
}
