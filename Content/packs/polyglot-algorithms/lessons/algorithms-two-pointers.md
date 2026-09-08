@Concept(id: two-pointers-concept) {
정렬된 배열에서 합이 target 인 두 원소를 찾는다고 하자. 모든 쌍을 다 보면 O(n^2) 이다. 배열이 정렬돼 있다는 사실을 쓰면 훨씬 적게 볼 수 있다.

포인터 두 개를 양 끝에 둔다 — `lo = 0`, `hi = xs.len() - 1`. 두 값의 합을 본다.

합이 target 보다 크면, `hi` 자리는 너무 크다는 뜻이다. `lo` 를 그대로 두고 `hi` 를 하나 올려봐야(즉 `hi` 를 그대로 두고 `lo` 를 올려봐야) 배열이 정렬돼 있으므로 합은 지금보다 작아지거나 같을 수밖에 없다 — `lo` 를 올리는 건 답이 될 수도 있었던 조합을 시도해 보는 것이다. 반대로 `hi` 를 올리는 건 이미 너무 큰 값을 더 큰 값으로 바꾸는 것이라 절대 target 에 가까워지지 않는다. 그래서 합이 크면 `hi` 를 내리고, 작으면 `lo` 를 올린다.

왜 이렇게 옮겨도 답을 놓치지 않을까? `lo` 를 올리는 순간, `xs[lo]` 와 그보다 작거나 같은 인덱스를 가진 값들과 현재 `hi` 의 조합은 이미 다 확인했거나(더 큰 합이었거나) 애초에 불가능하다 — 정렬돼 있으므로 `xs[lo]` 보다 작은 값과 `xs[hi]` 를 더해봐야 지금 합보다 작거나 같아서 더더욱 target 에 못 미친다. 그래서 `lo` 를 그 자리에 버려도 안전하다. `hi` 를 내리는 것도 대칭적으로 안전하다.

매 반복마다 `lo` 가 오르거나 `hi` 가 내려가고, 두 포인터는 서로를 향해서만 움직이므로 전체 반복은 배열 길이를 넘지 않는다. O(n) 이다.

@Visualize(id: two-pointers, frames: visuals/two-pointers.json) {
투 포인터가 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: two-pointers-example, language: rust, expected: expected/algorithms-two-pointers.txt) {
두 포인터가 안쪽으로 좁혀지는 과정을 단계마다 찍어 본다.

```rust
fn main() {
    let xs = [1, 2, 4, 6, 8, 9, 12, 14, 17, 20];
    let target = 16;

    let mut lo = 0usize;
    let mut hi = xs.len() - 1;
    let mut step = 1;

    while lo < hi {
        let sum = xs[lo] + xs[hi];
        println!("{}단계: lo={}(xs[lo]={}) hi={}(xs[hi]={}) 합={}", step, lo, xs[lo], hi, xs[hi], sum);
        if sum == target {
            println!("찾았다: ({}, {})", lo, hi);
            break;
        } else if sum < target {
            lo += 1;
        } else {
            hi -= 1;
        }
        step += 1;
    }
}
```
}

@Blank(id: two-pointers-blank, language: rust) {
합이 target 보다 작을 때, 두 포인터 중 어느 쪽을 옮겨야 합이 커질 기회가 생길까?

```rust
fn find_pair(xs: &[i32], target: i32) -> Option<(usize, usize)> {
    if xs.len() < 2 {
        return None;
    }
    let mut lo = 0usize;
    let mut hi = xs.len() - 1;
    while lo < hi {
        let sum = xs[lo] + xs[hi];
        if sum == target {
            return Some((lo, hi));
        } else if sum < target {
            ___1___ += 1;
        } else {
            hi -= 1;
        }
    }
    None
}

fn main() {
    let xs = [1, 2, 4, 6, 8, 9, 12, 14, 17, 20];
    println!("{:?}", find_pair(&xs, 16));
}
```

@Answer(slot: 1) {
`lo`
}
}

@Task(id: two-pointers-task, language: rust, starter: starters/algorithms-two-pointers.rs, tests: tests/algorithms-two-pointers.rs, solution: solutions/algorithms-two-pointers.rs) {
오름차순으로 정렬된 `&[i32]` 에서 합이 `target` 인 두 원소의 인덱스 쌍을 `Option<(usize, usize)>` 로 돌려주세요. 원소가 2개 미만이면 `None` 입니다. 중첩 반복으로 모든 쌍을 확인하는 풀이는 테스트를 통과해도 이 레슨의 답이 아닙니다 — 두 포인터를 양 끝에서 좁혀가야 합니다.

@Hint {
`lo` 와 `hi` 를 배열의 양 끝에 두고, `lo < hi` 인 동안 반복해라.
}

@Hint {
합이 target 보다 크면 `hi` 자리 값이 너무 크다는 뜻이다 — `hi` 를 하나 내려라.
}

@Hint {
합이 target 보다 작으면 `lo` 자리 값이 너무 작다는 뜻이다 — `lo` 를 하나 올려라.
}

@Hint {
`xs.len() < 2` 인 경우를 맨 먼저 걸러내라. 그러지 않으면 `xs.len() - 1` 에서 언더플로가 날 수 있다.
}
}

@Quiz(id: two-pointers-quiz, answer: wrong) {
@Question {
배열이 정렬돼 있지 않은데 이 투 포인터 코드를 그대로 돌리면 어떻게 될까?
}

@Choice(id: wrong) {
정답이 있어도 못 찾거나 엉뚱한 쌍을 답이라고 내놓을 수 있다
}

@Choice(id: slow) {
느려질 뿐 정답은 항상 맞게 나온다
}

@Choice(id: panic) {
반드시 실행 중 패닉이 난다
}

@Explanation {
합이 클 때 hi 를 내리고 작을 때 lo 를 올리는 이동은 '정렬돼 있으니 이 방향으로 가면 합이 이렇게 변한다'는 가정에 기대고 있다. 정렬이 깨져 있으면 그 가정이 틀리므로 실제로는 답인 쌍을 건너뛰고 지나갈 수 있다 — 패닉은 안 나지만 조용히 틀린 결과(혹은 None)를 낸다.
}
}

@Reflection(id: two-pointers-reflection) {
@Prompt(id: hashmap-alternative) {
같은 '두 수의 합' 문제는 해시맵으로도 정렬 없이 O(n) 에 풀 수 있습니다. 투 포인터 방식과 비교해 각각 무엇을 더 쓰고(메모리) 무엇을 덜 쓰는지, 어느 쪽 코드가 더 이해하기 쉬운지 적어 보세요.
}

@Prompt(id: sort-cost) {
배열이 애초에 정렬돼 있지 않다면 투 포인터를 쓰기 전에 정렬부터 해야 하고, 정렬 자체가 O(n log n) 입니다. 이 비용까지 합치면 해시맵 방식과 비교해 어느 쪽이 더 유리할지, 어떤 조건에서 답이 달라질지 생각해 보세요.
}
}
