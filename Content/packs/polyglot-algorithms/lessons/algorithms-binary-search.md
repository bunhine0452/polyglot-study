@Concept(id: binary-search-concept) {
정렬된 배열에서 값을 찾을 때, 앞에서부터 하나씩 보는 것은 최악의 경우 원소 수만큼 비교한다. 정렬돼 있다는 사실을 쓰면 훨씬 적게 볼 수 있다.

가운데 값을 보자. 찾는 값보다 크면 **오른쪽 절반에는 답이 없다** — 그쪽은 전부 가운데보다 크기 때문이다. 작으면 왼쪽 절반이 통째로 사라진다. 한 번 비교할 때마다 후보가 절반이 된다.

후보 구간은 두 인덱스 `lo` 와 `hi` 로 들고 다닌다. 여기서는 `hi` 를 **끝 다음 자리**로 둔다 — 구간이 `lo..hi` 이고 `lo == hi` 면 비어 있다는 뜻이라 종료 조건이 `while lo < hi` 하나로 끝난다. `hi` 를 마지막 자리로 두면 `<=` 와 `hi = mid - 1` 이 되는데, `hi` 가 `usize` 일 때 0에서 1을 빼면 그 자리에서 패닉한다.

가운데는 `lo + (hi - lo) / 2` 로 구한다. `(lo + hi) / 2` 는 두 값이 클 때 덧셈이 먼저 넘칠 수 있다.

원소가 1000개면 열 번, 100만 개면 스무 번이면 끝난다. 이것이 O(log n) 이다.

@Visualize(id: binary-search, frames: visuals/binary-search.json) {
이진 탐색이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: binary-search-example, language: rust, expected: expected/algorithms-binary-search.txt) {
후보 구간이 매 반복 절반으로 줄어드는 것을 찍어 본다.

```rust
fn main() {
    let xs = [2, 5, 8, 12, 16, 23, 38, 56, 72, 91];
    let target = 16;

    let mut lo = 0usize;
    let mut hi = xs.len();
    let mut step = 1;

    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        println!("{}단계: 후보 {}개, 가운데 xs[{}] = {}", step, hi - lo, mid, xs[mid]);
        if xs[mid] == target {
            println!("찾았다: {}번 자리", mid);
            break;
        } else if xs[mid] < target {
            lo = mid + 1;
        } else {
            hi = mid;
        }
        step += 1;
    }
}
```
}

@Blank(id: binary-search-blank, language: rust) {
가운데 값이 찾는 값보다 작을 때, 후보 구간의 어느 쪽을 버려야 할까?

```rust
fn find(xs: &[i32], target: i32) -> Option<usize> {
    let mut lo = 0usize;
    let mut hi = xs.len();
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        if xs[mid] == target {
            return Some(mid);
        } else if xs[mid] < target {
            ___1___ = mid + 1;
        } else {
            hi = mid;
        }
    }
    None
}

fn main() {
    let xs = [2, 5, 8, 12, 16];
    println!("{:?}", find(&xs, 12));
}
```

@Answer(slot: 1) {
`lo`
}
}

@Task(id: binary-search-task, language: rust, starter: starters/algorithms-binary-search.rs, tests: tests/algorithms-binary-search.rs, solution: solutions/algorithms-binary-search.rs) {
정렬된 `&[i32]` 에서 `target` 의 위치를 `Option<usize>` 로 돌려주세요. 매 반복마다 후보 구간이 절반으로 줄어야 합니다 — 처음부터 훑는 풀이는 테스트를 통과해도 이 레슨의 답이 아닙니다.

@Hint {
`hi` 를 `xs.len()` 으로 두면 구간이 `lo..hi` 이고, 비었다는 것은 `lo == hi` 다.
}

@Hint {
`xs[mid]` 가 target 보다 작으면 mid 자리도 답이 아니다 — `lo = mid + 1` 이다.
}

@Hint {
빈 배열이면 `lo` 와 `hi` 가 둘 다 0이라 반복이 한 번도 돌지 않는다.
}
}

@Quiz(id: binary-search-quiz, answer: twenty) {
@Question {
원소가 100만 개인 정렬 배열에서 이진 탐색은 최악의 경우 몇 번쯤 비교할까?
}

@Choice(id: twenty) {
스무 번쯤
}

@Choice(id: thousand) {
천 번쯤
}

@Choice(id: million) {
백만 번쯤
}

@Explanation {
한 번 비교할 때마다 후보가 절반이 되므로 2를 몇 번 곱해야 100만이 되는지가 답이다. 2^20 이 약 100만이라 스무 번이면 후보가 하나로 줄어든다.
}
}

@Reflection(id: binary-search-reflection) {
@Prompt(id: unsorted) {
배열이 정렬돼 있지 않다면 이진 탐색을 쓸 수 없다. 그럴 때 정렬부터 하고 찾는 것과 그냥 훑는 것 중 어느 쪽이 나을지, 어떤 조건에서 갈리는지 적어 보세요.
}

@Prompt(id: overflow) {
가운데를 `(lo + hi) / 2` 로 구하면 무엇이 문제인지, 그리고 `lo + (hi - lo) / 2` 가 왜 그 문제를 피하는지 설명해 보세요.
}
}
