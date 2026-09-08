@Concept(id: binary-search-variants-concept) {
이진 탐색은 `xs[mid] == target` 이면 바로 멈춘다. 배열에 같은 값이 여러 번 있으면 그중 어느 자리를 돌려줄지는 우연이다 — 가장 먼저 나오는 자리인지 가장 나중 자리인지 보장이 없다.

첫 번째 자리를 원한다면 규칙을 바꾼다. `xs[mid] == target` 이어도 멈추지 않고 **왼쪽으로 계속 줄인다** — 더 이른 자리가 있는지 확인해야 하기 때문이다. `xs[mid] >= target` 이면 `hi = mid`, 아니면 `lo = mid + 1` 로 둔다. 이렇게 하면 `lo` 는 target 이상인 첫 자리(하한, lower bound)에서 멈춘다. 마지막 자리를 원한다면 반대로 `xs[mid] <= target` 일 때 `lo = mid + 1` 로 오른쪽을 밀어붙인다 — 이러면 target 보다 큰 첫 자리(상한, upper bound)가 나오고, 그 바로 앞자리가 마지막 자리다.

회전된 정렬 배열은 다르다. 오름차순 배열을 어느 지점에서 잘라 앞뒤를 바꿔 붙인 모양이라 전체는 정렬돼 있지 않지만 **끊긴 지점은 하나뿐**이다. 그래서 `lo` 와 `mid` 사이, 또는 `mid` 와 `hi` 사이 둘 중 하나는 반드시 정렬돼 있다. `xs[lo] <= xs[mid]` 면 왼쪽 절반이 정렬된 것이고, 아니면 오른쪽 절반이 정렬된 것이다. 정렬된 절반의 범위 안에 target 이 들어가면 그쪽을 계속 탐색하고, 아니면 반대쪽을 탐색한다 — 매번 후보가 절반으로 줄어드는 것은 똑같다.

@Visualize(id: binary-search-variants, frames: visuals/binary-search-variants.json) {
이진 탐색 응용이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: binary-search-variants-example, language: rust, expected: expected/algorithms-binary-search-variants.txt) {
중복된 값 3 중 첫 번째 자리를 찾는 과정을 찍어 본다. `xs[mid] == target` 이어도 멈추지 않고 왼쪽으로 계속 좁힌다.

```rust
fn main() {
    let xs = [1, 3, 3, 3, 5, 7, 9];
    let target = 3;

    let mut lo = 0usize;
    let mut hi = xs.len();
    let mut step = 1;

    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        println!("{}단계: 후보 [{}, {}), 가운데 xs[{}] = {}", step, lo, hi, mid, xs[mid]);
        if xs[mid] >= target {
            hi = mid;
        } else {
            lo = mid + 1;
        }
        step += 1;
    }

    if lo < xs.len() && xs[lo] == target {
        println!("첫 위치: {}번 자리", lo);
    } else {
        println!("없음");
    }
}
```
}

@Blank(id: binary-search-variants-blank, language: rust) {
마지막 자리를 찾으려면 예제와 반대로 움직여야 한다 — target 과 같거나 작을 때 어느 쪽으로 좁혀야 target 보다 큰 첫 자리(상한)에 닿을까?

```rust
fn last_position(xs: &[i32], target: i32) -> Option<usize> {
    let mut lo = 0usize;
    let mut hi = xs.len();
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        if xs[mid] ___1___ target {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    if lo == 0 || xs[lo - 1] != target {
        None
    } else {
        Some(lo - 1)
    }
}

fn main() {
    let xs = [1, 3, 3, 3, 5, 7, 9];
    println!("{:?}", last_position(&xs, 3));
}
```

@Answer(slot: 1) {
`<=`
}
}

@Task(id: binary-search-variants-task, language: rust, starter: starters/algorithms-binary-search-variants.rs, tests: tests/algorithms-binary-search-variants.rs, solution: solutions/algorithms-binary-search-variants.rs) {
한 번 회전된 정렬 배열(예: `[4,5,6,7,0,1,2]`, 원소는 모두 서로 다르다고 가정)에서 `target` 의 위치를 `Option<usize>` 로 돌려주세요. 배열을 복원해서 훑는 풀이는 이 레슨의 답이 아닙니다 — 매 반복마다 절반이 통째로 버려져야 합니다.

@Hint {
xs[lo] <= xs[mid] 면 왼쪽 절반 [lo, mid] 이 정렬돼 있다는 뜻이다.
}

@Hint {
정렬된 절반의 범위(xs[lo]..xs[mid] 또는 xs[mid]..xs[hi-1]) 안에 target 이 있으면 그 절반을 탐색하고, 아니면 반대쪽을 탐색해라.
}

@Hint {
정렬되지 않은 쪽이라도 걱정할 것 없다 — 끊긴 지점이 하나뿐이라 나머지 절반은 반드시 정렬돼 있다.
}
}

@Quiz(id: binary-search-variants-quiz, answer: left) {
@Question {
정렬된 배열 [1, 3, 3, 3, 5] 에서 값 3의 '첫 위치'를 찾는 이진 탐색이 xs[mid] == target 인 자리를 만났을 때 해야 할 일은?
}

@Choice(id: stop) {
바로 그 자리를 반환한다
}

@Choice(id: left) {
그 자리를 후보로 적어두고 hi = mid 로 왼쪽으로 계속 좁힌다
}

@Choice(id: right) {
그 자리를 후보로 적어두고 lo = mid + 1 로 오른쪽으로 계속 좁힌다
}

@Explanation {
더 이른 자리에 같은 값이 있을 수 있으므로 바로 멈추면 안 된다. hi = mid 로 왼쪽 절반(자기 자신 포함)을 계속 탐색해야 진짜 첫 자리에 닿는다.
}
}

@Reflection(id: binary-search-variants-reflection) {
@Prompt(id: rotated-duplicates) {
회전된 배열에 중복값이 있어서 xs[lo] == xs[mid] 인데도 어느 쪽이 정렬됐는지 판단할 수 없는 경우가 있습니다. 이런 입력에서 이 알고리즘이 왜 깨질 수 있는지 적어 보세요.
}

@Prompt(id: lower-upper-usage) {
하한(lower bound)과 상한(upper bound)을 각각 언제 쓰는지, '정렬된 배열에 값을 삽입할 자리를 찾는다'는 문제에 적용해 설명해 보세요.
}
}
