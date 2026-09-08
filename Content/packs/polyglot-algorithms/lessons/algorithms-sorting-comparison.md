@Concept(id: sorting-comparison-concept) {
지금까지 만든 다섯 정렬을 나란히 놓고 보면 언제 무엇을 써야 할지 판단할 수 있다.

| 정렬 | 최선 | 평균 | 최악 | 안정 | 추가 메모리 |
|---|---|---|---|---|---|
| 버블 | O(n) | O(n^2) | O(n^2) | 안정 | O(1) |
| 선택 | O(n^2) | O(n^2) | O(n^2) | 불안정 | O(1) |
| 삽입 | O(n) | O(n^2) | O(n^2) | 안정 | O(1) |
| 병합 | O(n log n) | O(n log n) | O(n log n) | 안정 | O(n) |
| 퀵 | O(n log n) | O(n log n) | O(n^2) | 불안정 | O(log n)(호출 스택) |

최선의 경우가 갈리는 이유는 조기 종료와 적응성에 있다. 버블과 삽입은 이미 정렬된 입력을 한 번 훑고 멈추거나 아예 안쪽 반복을 건너뛰어 O(n)까지 내려가지만, 선택 정렬은 매번 남은 구간 전체를 훑어야 최솟값을 확신할 수 있어 정렬 상태와 상관없이 항상 O(n^2)이다.

안정성은 같은 값이 여러 개일 때만 드러난다. 예를 들어 학생을 '반'으로 한 번 정렬하고, 그 결과를 다시 '점수'로 정렬한다고 하자. 안정 정렬이면 점수가 같은 학생들은 반 순서를 그대로 유지한 채 점수 순으로만 다시 정렬된다. 불안정 정렬(선택·퀵)을 쓰면 그 보장이 없다 — 결과는 맞지만 동점자 안에서의 순서는 뒤섞일 수 있다.

추가 메모리도 차이가 크다. 버블·선택·삽입·퀵은 원본 배열 안에서 값을 맞바꾸며 정렬하는 제자리(in-place) 정렬이라 추가 배열이 거의 필요 없다(퀵은 재귀 호출 스택만큼은 쓴다). 병합 정렬은 두 절반을 합칠 때마다 새 Vec 을 만들기 때문에 O(n) 만큼의 추가 메모리가 항상 필요하다 — 메모리가 빠듯한 환경에서는 이 점이 병합 정렬을 불리하게 만든다.

정리하면: 입력이 작거나(n이 수십 개 이하) 이미 정렬에 가깝다면 삽입 정렬이 구현도 간단하고 실제로 빠르다. 입력이 크고 정렬 상태를 모른다면 O(n log n)을 보장하는 병합 정렬이나 퀵 정렬을 쓴다. 안정성이 꼭 필요하면(동점자 순서를 지켜야 하면) 병합 정렬을, 추가 메모리를 아끼고 평균 성능이 중요하면 퀵 정렬을 고른다.

@Visualize(id: sorting-comparison, frames: visuals/sorting-comparison.json) {
정렬 다섯 가지 비교가 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: sorting-comparison-example, language: rust, expected: expected/algorithms-sorting-comparison.txt) {
같은 배열을 버블 정렬과 선택 정렬로 각각 돌려, 교환 횟수가 실제로 얼마나 다른지 세어 본다.

```rust
fn bubble_swaps(xs: &mut Vec<i32>) -> u32 {
    let n = xs.len();
    let mut swaps = 0u32;
    for i in 0..n {
        let mut swapped = false;
        for j in 0..n.saturating_sub(1 + i) {
            if xs[j] > xs[j + 1] {
                xs.swap(j, j + 1);
                swaps += 1;
                swapped = true;
            }
        }
        if !swapped {
            break;
        }
    }
    swaps
}

fn selection_swaps(xs: &mut Vec<i32>) -> u32 {
    let n = xs.len();
    let mut swaps = 0u32;
    for i in 0..n {
        let mut min_idx = i;
        for j in (i + 1)..n {
            if xs[j] < xs[min_idx] {
                min_idx = j;
            }
        }
        if min_idx != i {
            xs.swap(i, min_idx);
            swaps += 1;
        }
    }
    swaps
}

fn main() {
    let original = vec![5, 2, 4, 6, 1, 3];
    let mut a = original.clone();
    let mut b = original.clone();
    let bs = bubble_swaps(&mut a);
    let ss = selection_swaps(&mut b);
    println!("버블 정렬 교환 횟수: {}", bs);
    println!("선택 정렬 교환 횟수: {}", ss);
    println!("두 결과 모두 정렬됨: {:?} {:?}", a, b);
}
```
}

@Blank(id: sorting-comparison-blank, language: rust) {
제자리(in-place) 정렬인 퀵 정렬은 병합 정렬과 달리 별도의 배열을 만들지 않는다. 그 사실을 match 의 어느 가지에 넣어야 할까?

```rust
fn needs_extra_array(sort_name: &str) -> bool {
    match sort_name {
        "병합 정렬" => true,
        "버블 정렬" | "선택 정렬" | "삽입 정렬" | ___1___ => false,
        _ => false,
    }
}

fn main() {
    println!("{}", needs_extra_array("병합 정렬"));
    println!("{}", needs_extra_array("퀵 정렬"));
}
```

@Answer(slot: 1) {
`"퀵 정렬"`
}
}

@Task(id: sorting-comparison-task, language: rust, starter: starters/algorithms-sorting-comparison.rs, tests: tests/algorithms-sorting-comparison.rs, solution: solutions/algorithms-sorting-comparison.rs) {
`(키, 원래 순서)` 쌍의 목록을 키 기준으로 오름차순 정렬하되, 키가 같은 원소들의 원래 순서는 그대로 유지해야 합니다 — 즉 안정 정렬이어야 합니다. 이전 레슨의 삽입 정렬 방식을 그대로 가져오되 비교 대상만 키로 바꾸면 됩니다.

@Hint {
삽입 정렬 방식을 그대로 쓰되, 비교 대상은 튜플의 .0 (키) 이다.
}

@Hint {
xs[j-1].0 > key.0 일 때만 밀어라 — 같으면(>=가 아니라 >) 밀지 않아야 원래 순서가 유지된다.
}

@Hint {
밀기를 멈춘 j 자리에 key 를 넣는 것은 이전 레슨의 삽입 정렬과 같다.
}
}

@Quiz(id: sorting-comparison-quiz, answer: merge) {
@Question {
데이터가 100만 건이고, 동점자의 원래 순서를 반드시 지켜야 한다면 다섯 정렬 중 가장 알맞은 것은?
}

@Choice(id: selection) {
선택 정렬 — 구현이 간단하다
}

@Choice(id: quick) {
퀵 정렬 — 평균은 빠르지만 안정적이지 않다
}

@Choice(id: merge) {
병합 정렬 — O(n log n)을 보장하면서 안정적이다
}

@Explanation {
100만 건이면 O(n^2) 정렬(버블·선택·삽입)은 너무 느리다. O(n log n) 을 보장하는 병합·퀵 정렬 중, 동점자 순서를 지켜야 하므로 안정 정렬인 병합 정렬이 알맞다.
}
}

@Reflection(id: sorting-comparison-reflection) {
@Prompt(id: embedded-memory) {
메모리가 아주 빠듯한 임베디드 환경에서 병합 정렬 대신 퀵 정렬이나 삽입 정렬을 고를 수 있는 이유를 적어 보세요.
}

@Prompt(id: stdlib-sort) {
지금까지 만든 다섯 정렬 중 실무 코드에서 가장 적게 손으로 구현하게 될 것 같은 정렬이 무엇일지, 표준 라이브러리가 대신 해주는 것과 관련지어 생각해 보세요.
}
}
