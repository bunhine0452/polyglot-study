@Concept(id: sliding-window-concept) {
구간의 합을 매번 처음부터 더하면 구간 하나에 O(k) 가 든다. 구간을 하나씩 오른쪽으로 밀 때마다 다시 더하면 전체는 O(n*k) 가 된다. 그런데 옆으로 한 칸 민 구간은 이전 구간과 원소를 거의 다 공유한다 — 오른쪽 끝에 하나가 새로 들어오고 왼쪽 끝에서 하나가 빠질 뿐이다. 그러니 합을 통째로 다시 구하지 않고, 새로 들어온 값을 더하고 빠진 값을 빼기만 하면 구간 하나를 옮기는 데 O(1) 이면 충분하다. 이렇게 크기가 고정된 창(윈도우)을 오른쪽으로 한 칸씩 밀면서 훑으면 전체는 O(n) 이다.

창의 크기가 고정이 아니라 조건에 따라 늘었다 줄었다 해야 할 때도 있다. 예를 들어 '합이 target 이상이 되는 가장 짧은 구간'을 찾는다면, 오른쪽 끝을 늘려가며 조건을 만족할 때까지 원소를 더하고, 일단 만족하면 왼쪽 끝을 줄여가며 더 짧게 만들 수 있는지 본다. 오른쪽과 왼쪽 두 포인터가 각각 앞으로만 움직이므로 이것도 O(n) 이다.

이 가변 윈도우는 사실 투 포인터의 한 형태다 — 다만 두 포인터가 서로를 향해 좁혀오는 게 아니라 둘 다 오른쪽으로만 움직인다는 점이 다르다. 그리고 창 합을 더하고 빼며 갱신하는 것은 프리픽스 합 배열에서 prefix[r] - prefix[l] 을 매번 새로 계산하는 대신, 이전에 구해둔 값에 차이만 반영하는 것과 같은 생각이다.

@Visualize(id: sliding-window, frames: visuals/sliding-window.json) {
슬라이딩 윈도우가 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: sliding-window-example, language: rust, expected: expected/algorithms-sliding-window.txt) {
고정 크기 3인 창을 오른쪽으로 밀면서 매번 더하고 빼는 것만으로 구간 합을 갱신해 본다.

```rust
fn main() {
    let xs = [2, 1, 5, 1, 3, 2];
    let k = 3;

    let mut window_sum: i32 = xs[..k].iter().sum();
    let mut max_sum = window_sum;
    let mut max_start = 0;
    println!("시작 0: 합 {}", window_sum);

    for i in k..xs.len() {
        window_sum = window_sum + xs[i] - xs[i - k];
        let start = i - k + 1;
        println!("시작 {}: 합 {}", start, window_sum);
        if window_sum > max_sum {
            max_sum = window_sum;
            max_start = start;
        }
    }

    println!("최댓값 {} (시작 {})", max_sum, max_start);
}
```
}

@Blank(id: sliding-window-blank, language: rust) {
창이 한 칸 오른쪽으로 밀릴 때, 새로 들어온 xs[i] 를 더했다면 빠져나가는 값은 무엇을 빼야 할까?

```rust
fn window_sums(xs: &[i32], k: usize) -> Vec<i32> {
    let mut sums = Vec::new();
    let mut window_sum: i32 = xs[..k].iter().sum();
    sums.push(window_sum);
    for i in k..xs.len() {
        window_sum = window_sum + xs[i] - ___1___;
        sums.push(window_sum);
    }
    sums
}

fn main() {
    let xs = [2, 1, 5, 1, 3, 2];
    println!("{:?}", window_sums(&xs, 3));
}
```

@Answer(slot: 1) {
`xs[i - k]`
}
}

@Task(id: sliding-window-task, language: rust, starter: starters/algorithms-sliding-window.rs, tests: tests/algorithms-sliding-window.rs, solution: solutions/algorithms-sliding-window.rs) {
정렬되지 않은 양의 정수 배열 `xs` 와 목표값 `target` 이 주어질 때, 합이 target 이상이 되는 연속 부분 배열 중 가장 짧은 것의 길이를 `Option<usize>` 로 돌려주세요. 그런 구간이 없으면 `None` 입니다. 모든 원소는 양수라고 가정해도 됩니다.

@Hint {
합이 target 보다 작을 때는 right 를 늘려서 원소를 더 담아야 한다.
}

@Hint {
합이 target 이상이 되는 순간, 그 구간이 답의 후보다 — 여기서 곧장 left 를 줄이며 더 짧게 만들 수 있는지 봐라.
}

@Hint {
left 를 줄일 때마다 sum 에서 xs[left] 를 빼는 것을 잊지 마라. 빼지 않으면 합이 실제 구간과 어긋난다.
}
}

@Quiz(id: sliding-window-quiz, answer: each-forward) {
@Question {
가변 윈도우로 min_subarray_len 을 풀 때, left 와 right 두 포인터를 쓰는 데도 전체가 O(n) 인 이유는?
}

@Choice(id: each-forward) {
right 와 left 가 각각 배열을 한 번씩만 앞으로 훑고, 뒤로 되돌아가지 않기 때문이다
}

@Choice(id: restart-left) {
right 가 한 칸 움직일 때마다 left 가 처음부터 다시 훑기 때문이다
}

@Choice(id: sorted-first) {
구간을 보기 전에 배열을 정렬해 두기 때문이다
}

@Explanation {
right 는 0부터 n-1까지 한 번씩만 늘어나고, left 도 0부터 최대 n-1까지 한 번씩만 늘어난다. 둘 다 절대 되돌아가지 않으므로 두 포인터의 이동 횟수를 합쳐도 최대 2n 이다. 그래서 전체가 O(n) 이지 O(n^2) 가 아니다.
}
}

@Reflection(id: sliding-window-reflection) {
@Prompt(id: negative-numbers) {
배열에 음수가 섞여 있어도 이 가변 윈도우 알고리즘이 그대로 통할까? left 를 줄일지 말지를 결정하는 논리가 어떤 가정에 기대고 있는지, 그 가정이 음수 앞에서 왜 깨지는지 적어 보세요.
}

@Prompt(id: prefix-sum-alternative) {
고정 크기 윈도우의 최댓값을 구하는 문제를, 미리 만들어 둔 프리픽스 합 배열에서 매번 prefix[r] - prefix[l] 을 빼는 방식으로 풀면 시간이나 코드 면에서 어떤 점이 손해일지 생각해 보세요.
}
}
