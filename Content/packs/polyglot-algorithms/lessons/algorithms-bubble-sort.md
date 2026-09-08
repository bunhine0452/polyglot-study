@Concept(id: bubble-sort-concept) {
버블 정렬은 이웃한 두 값을 비교해서, 순서가 바뀌어 있으면 맞바꾼다. 한 번 왼쪽에서 오른쪽까지 쭉 훑고 나면(한 패스) 그 구간에서 제일 큰 값이 이웃 교환을 거듭하며 맨 끝까지 밀려간다 — 마치 거품이 위로 뜨는 모양이라 버블 정렬이다.

한 패스가 끝나면 맨 끝 자리는 확정된다. 그래서 다음 패스는 그 앞자리까지만 보면 된다. 바깥 반복은 최대 n-1번 돌고, 각 바깥 반복마다 안쪽 반복이 최대 n-1번 비교한다. 곱하면 대략 n * n 번 비교이므로 O(n^2) 이다.

배열이 이미 정렬돼 있으면 어떤 패스에서도 교환이 한 번도 일어나지 않는다. 이 사실을 이용해 **한 패스 동안 교환이 없었으면 그 자리에서 멈추는 것**이 조기 종료다. 이미 정렬된 입력이면 딱 한 패스, O(n) 만에 끝난다 — 최선의 경우다.
}

@Example(id: bubble-sort-example, language: rust, expected: expected/algorithms-bubble-sort.txt) {
패스가 끝날 때마다 배열이 어떻게 바뀌는지, 그리고 교환이 멈추는 순간을 찍어 본다.

```rust
fn main() {
    let mut xs = [5, 2, 4, 1, 3];
    let n = xs.len();
    for i in 0..n {
        let mut swapped = false;
        for j in 0..n - 1 - i {
            if xs[j] > xs[j + 1] {
                xs.swap(j, j + 1);
                swapped = true;
            }
        }
        println!("{}번째 패스 후: {:?}", i + 1, xs);
        if !swapped {
            println!("교환 없음 — 조기 종료");
            break;
        }
    }
}
```
}

@Blank(id: bubble-sort-blank, language: rust) {
한 패스 동안 교환이 한 번도 없었다면 이미 정렬된 것이다. 그 사실을 어떤 조건으로 확인해서 반복을 멈춰야 할까?

```rust
fn bubble_sort_counted(xs: &mut Vec<i32>) -> u32 {
    let n = xs.len();
    let mut comparisons = 0u32;
    for i in 0..n {
        let mut swapped = false;
        for j in 0..n.saturating_sub(1 + i) {
            comparisons += 1;
            if xs[j] > xs[j + 1] {
                xs.swap(j, j + 1);
                swapped = true;
            }
        }
        if ___1___ {
            break;
        }
    }
    comparisons
}

fn main() {
    let mut xs = vec![1, 2, 3, 4, 5];
    let comparisons = bubble_sort_counted(&mut xs);
    println!("{:?} {}", xs, comparisons);
}
```

@Answer(slot: 1) {
`!swapped`
}
}

@Task(id: bubble-sort-task, language: rust, starter: starters/algorithms-bubble-sort.rs, tests: tests/algorithms-bubble-sort.rs, solution: solutions/algorithms-bubble-sort.rs) {
`Vec<i32>` 를 오름차순으로 제자리 정렬하세요. 이웃한 두 값을 비교·교환하는 방식이어야 하고, 한 패스 동안 교환이 없으면 더 돌지 않고 멈춰야 합니다.

@Hint {
바깥 반복 i가 한 번 끝날 때마다 배열 끝에서 i+1개는 이미 자리를 잡는다 — 안쪽 반복은 그 앞까지만 보면 된다.
}

@Hint {
xs.swap(j, j + 1) 로 이웃을 맞바꿀 수 있다.
}

@Hint {
한 패스 동안 swapped 가 한 번도 true 가 안 됐으면 이미 정렬된 것이다 — break 해라.
}
}

@Quiz(id: bubble-sort-quiz, answer: fortyfive) {
@Question {
원소 10개인 배열을 버블 정렬로 최악의 경우(계속 뒤섞여 조기 종료가 없는 경우) 정렬한다면 비교는 대략 몇 번 일어날까?
}

@Choice(id: ten) {
10번쯤
}

@Choice(id: fortyfive) {
45번쯤
}

@Choice(id: hundred) {
100번쯤
}

@Explanation {
안쪽 반복 횟수를 다 더하면 9+8+7+...+1 = 45다. 이것이 n(n-1)/2 이고, O(n^2) 이라고 해서 정확히 n^2(=100)번인 것은 아니다.
}
}

@Reflection(id: bubble-sort-reflection) {
@Prompt(id: sorted-vs-reversed) {
이미 정렬된 배열과 완전히 거꾸로 된 배열, 두 경우에 버블 정렬이 도는 패스 수가 어떻게 다른지 설명해 보세요.
}

@Prompt(id: worst-case-still-quadratic) {
조기 종료가 있는 버블 정렬도 최악의 경우엔 왜 여전히 O(n^2)인지 적어 보세요.
}
}
