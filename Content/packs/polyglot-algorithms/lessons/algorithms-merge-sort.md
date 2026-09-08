@Concept(id: merge-sort-concept) {
병합 정렬은 분할정복이다. 배열을 반으로 나누고, 왼쪽과 오른쪽을 각각 재귀로 정렬한 뒤, 이미 정렬된 두 절반을 하나로 합친다(병합). 길이가 0이나 1인 배열은 이미 정렬된 것으로 보고 그대로 돌려주는 것이 베이스 케이스다.

병합은 두 정렬된 배열의 맨 앞끼리 비교하면서 진행한다. 더 작은 쪽을 결과에 넣고 그쪽 포인터만 한 칸 옮긴다 — 이 과정을 어느 한쪽이 바닥날 때까지 반복하고, 남은 쪽은 이미 정렬돼 있으니 통째로 뒤에 붙이면 된다. 두 배열의 원소를 합쳐 한 번씩만 보므로 병합은 O(n) 이다.

반으로 나누는 깊이는 log n 이다(n을 계속 절반으로 줄여 1까지 가려면 log n 번 나눠야 한다). 각 깊이에서는 그 깊이에 있는 모든 병합 호출이 처리하는 원소 수를 다 더하면 항상 n개다 — 즉 깊이 하나당 O(n) 이 든다. 깊이가 log n개니까 전체는 O(n log n) 이다.

병합할 때 왼쪽과 오른쪽 값이 같으면 **왼쪽을 먼저 고른다**(`<=`). 왼쪽 절반은 원래 배열에서 더 앞쪽에 있던 원소들이므로, 같은 값이면 항상 원래 순서대로 결과에 들어간다 — 그래서 병합 정렬은 안정 정렬이다.
}

@Example(id: merge-sort-example, language: rust, expected: expected/algorithms-merge-sort.txt) {
이미 정렬된 두 배열을 하나로 합치는 병합 과정을, 어느 쪽 값을 골랐는지 찍어 가며 본다.

```rust
fn merge(left: &[i32], right: &[i32]) -> Vec<i32> {
    let mut result = Vec::with_capacity(left.len() + right.len());
    let mut i = 0;
    let mut j = 0;
    while i < left.len() && j < right.len() {
        if left[i] <= right[j] {
            println!("왼쪽 {} 선택", left[i]);
            result.push(left[i]);
            i += 1;
        } else {
            println!("오른쪽 {} 선택", right[j]);
            result.push(right[j]);
            j += 1;
        }
    }
    result.extend_from_slice(&left[i..]);
    result.extend_from_slice(&right[j..]);
    result
}

fn main() {
    let left = [2, 5, 8];
    let right = [1, 6, 7];
    let merged = merge(&left, &right);
    println!("병합 결과: {:?}", merged);
}
```
}

@Blank(id: merge-sort-blank, language: rust) {
왼쪽과 오른쪽 값이 같을 때 어느 쪽을 먼저 골라야 원래 순서(왼쪽이 더 앞이었다는 사실)가 유지될까?

```rust
fn merge(left: &[i32], right: &[i32]) -> Vec<i32> {
    let mut result = Vec::with_capacity(left.len() + right.len());
    let mut i = 0;
    let mut j = 0;
    while i < left.len() && j < right.len() {
        if left[i] ___1___ right[j] {
            result.push(left[i]);
            i += 1;
        } else {
            result.push(right[j]);
            j += 1;
        }
    }
    result.extend_from_slice(&left[i..]);
    result.extend_from_slice(&right[j..]);
    result
}

fn main() {
    let left = [1, 3, 5];
    let right = [1, 2, 4];
    println!("{:?}", merge(&left, &right));
}
```

@Answer(slot: 1) {
`<=`
}
}

@Task(id: merge-sort-task, language: rust, starter: starters/algorithms-merge-sort.rs, tests: tests/algorithms-merge-sort.rs, solution: solutions/algorithms-merge-sort.rs) {
`&[i32]` 를 오름차순으로 정렬한 새 `Vec<i32>` 로 돌려주세요. 배열을 반으로 나눠 각각 재귀로 정렬한 뒤 병합하는 분할정복 방식이어야 합니다.

@Hint {
길이가 0이나 1인 배열은 이미 정렬된 것으로 보고 그대로 복사해 반환해라(베이스 케이스).
}

@Hint {
xs.len() / 2 를 기준으로 왼쪽 슬라이스와 오른쪽 슬라이스로 나눠 각각 merge_sort 를 재귀 호출해라.
}

@Hint {
두 재귀 호출의 결과(둘 다 정렬된 Vec)를 병합하는 보조 함수를 따로 만들어라 — 두 정렬된 배열을 합치는 로직이다.
}
}

@Quiz(id: merge-sort-quiz, answer: correct) {
@Question {
원소가 8개인 배열을 병합 정렬로 정렬하면 반으로 나누는 깊이는 몇 단계이고, 전체 시간복잡도는 어떻게 나올까?
}

@Choice(id: correct) {
깊이 3단계(2^3=8), 각 깊이의 병합 비용 합이 O(n) — 곱해서 O(n log n)
}

@Choice(id: linear-depth) {
깊이 8단계, 각 깊이마다 O(1) — 합쳐서 O(n)
}

@Choice(id: cubic) {
깊이 3단계, 각 깊이마다 O(n^2) — 합쳐서 O(n^3)
}

@Explanation {
8 = 2^3 이므로 절반씩 3번 나누면 크기 1이 된다. 각 깊이에서 그 깊이의 모든 병합 호출이 다루는 원소 수를 합치면 항상 n개이므로 깊이당 O(n), 총 O(n log n)이다.
}
}

@Reflection(id: merge-sort-reflection) {
@Prompt(id: not-in-place) {
병합 정렬이 제자리 정렬이 아니라는 것이 무슨 뜻인지, merge 함수가 새 Vec 을 만드는 부분을 근거로 설명해 보세요.
}

@Prompt(id: why-left-first) {
왼쪽과 오른쪽 값이 같을 때 왼쪽을 먼저 고르는 것이 왜 안정성을 보장하는지, 만약 오른쪽을 먼저 고르면 어떻게 될지 적어 보세요.
}
}
