@Concept(id: dp-knapsack-concept) {
배낭 문제는 무게 제한이 있는 배낭에 물건들을 담아 가치의 합을 최대로 만드는 문제다. 물건마다 무게와 가치가 있고, 각 물건은 **통째로 담거나 아예 안 담거나** 둘 중 하나다(쪼갤 수 없어서 0/1 배낭이라 부른다).

표의 두 축은 "몇 번째 물건까지 고려했는가" 와 "남은 무게 한도가 얼마인가" 다. `dp[i][cap]` 은 "앞의 `i`개 물건만 가지고 무게 한도 `cap` 안에서 담을 수 있는 최대 가치" 다.

`i`번째 물건을 처리할 때 두 선택지가 있다. **안 담으면** 가치는 `dp[i-1][cap]` 그대로다. **담으면** 그 물건의 무게만큼 한도가 줄어든 상태에서 나머지를 채운 값에 이 물건의 가치를 더한다 — `dp[i-1][cap - weight] + value` 다(단, 물건 무게가 `cap` 보다 크면 애초에 담을 수 없다). 둘 중 더 큰 값이 `dp[i][cap]` 이다.

여기서 순서가 중요하다. `dp[i][cap]` 이 참조하는 것은 항상 `dp[i-1][...]` — **한 줄 위**, 즉 이 물건을 아직 고려하지 않았던 상태다. 그래서 표를 물건 번호 순서(`i = 1, 2, 3, ...`)로 한 줄씩 채우면, 같은 물건을 두 번 담는 일이 생기지 않는다. 만약 표를 1차원으로 줄여서 같은 줄에서 갱신한다면 무게를 **큰 값에서 작은 값으로** 거꾸로 훑어야 하는데, 이 편에서는 2차원 표로 그 문제 자체를 피한다.
}

@Example(id: dp-knapsack-example, language: rust, expected: expected/algorithms-dp-knapsack.txt) {
물건을 하나씩 늘려가며 각 무게 한도에서 담을 수 있는 최대 가치가 어떻게 갱신되는지 표로 확인한다.

```rust
fn knapsack(weights: &[u32], values: &[u32], capacity: usize) -> Vec<Vec<u32>> {
    let n = weights.len();
    let mut dp = vec![vec![0u32; capacity + 1]; n + 1];

    for i in 1..=n {
        let w = weights[i - 1] as usize;
        let v = values[i - 1];
        for cap in 0..=capacity {
            let without = dp[i - 1][cap];
            if w > cap {
                dp[i][cap] = without;
            } else {
                let with = dp[i - 1][cap - w] + v;
                dp[i][cap] = without.max(with);
            }
        }
    }

    for i in 1..=n {
        println!("{}번 물건(무게 {}, 가치 {}) 처리 후: {:?}", i, weights[i - 1], values[i - 1], dp[i]);
    }
    dp
}

fn main() {
    let weights = [2, 3, 4];
    let values = [3, 4, 5];
    let capacity = 5;
    let dp = knapsack(&weights, &values, capacity);
    println!("최대 가치: {}", dp[weights.len()][capacity]);
}
```
}

@Blank(id: dp-knapsack-blank, language: rust) {
이 물건을 담을 수 있는 무게라면, 안 담았을 때와 담았을 때 중 어느 쪽이 나은지 어떻게 골라야 할까?

```rust
fn knapsack(weights: &[u32], values: &[u32], capacity: usize) -> u32 {
    let n = weights.len();
    let mut dp = vec![vec![0u32; capacity + 1]; n + 1];
    for i in 1..=n {
        let w = weights[i - 1] as usize;
        let v = values[i - 1];
        for cap in 0..=capacity {
            let without = dp[i - 1][cap];
            dp[i][cap] = if w > cap {
                without
            } else {
                ___1___
            };
        }
    }
    dp[n][capacity]
}

fn main() {
    let weights = [1, 3, 4];
    let values = [1, 4, 5];
    println!("{}", knapsack(&weights, &values, 4));
}
```

@Answer(slot: 1) {
`without.max(dp[i - 1][cap - w] + v)`
}
}

@Task(id: dp-knapsack-task, language: rust, starter: starters/algorithms-dp-knapsack.rs, tests: tests/algorithms-dp-knapsack.rs, solution: solutions/algorithms-dp-knapsack.rs) {
물건마다 무게(`weights`)와 가치(`values`)가 있습니다. 무게 한도 `capacity` 인 배낭에 물건을 담거나 안 담거나만 선택할 수 있을 때(0/1 배낭), 담을 수 있는 최대 가치를 구하세요.

@Hint {
dp[i][cap]를 "앞의 i개 물건만 가지고 한도 cap 안에서 담을 수 있는 최대 가치" 로 정의해라. dp[0][cap]는 물건이 하나도 없으니 항상 0이다.
}

@Hint {
i번째 물건(1-indexed)의 무게가 cap보다 크면 담을 수 없다 — 그 칸은 dp[i-1][cap] 그대로다.
}

@Hint {
담을 수 있다면 dp[i-1][cap] (안 담음) 과 dp[i-1][cap - weight] + value (담음) 중 큰 값을 골라라.
}
}

@Quiz(id: dp-knapsack-quiz, answer: no-double-count) {
@Question {
0/1 배낭 문제를 2차원 표로 풀 때, dp[i][cap]가 항상 dp[i-1][...]만 참조하게 만드는 이유는?
}

@Choice(id: no-double-count) {
같은 물건을 두 번 담는 일이 없도록, 아직 이 물건을 고려하지 않았던 상태에서만 값을 가져오기 위해서다
}

@Choice(id: syntax-rule) {
2차원 배열은 한 줄 위만 참조할 수 있게 문법이 정해져 있어서다
}

@Choice(id: save-memory) {
메모리를 아끼기 위해서다
}

@Explanation {
dp[i][cap]가 dp[i][cap - weight]처럼 같은 줄(i)을 참조한다면, 그 값이 이미 i번째 물건을 담은 상태를 반영하고 있을 수 있다 — 그러면 i번째 물건을 또 담는 셈이 된다. 한 줄 위(dp[i-1][...])만 참조하면 그 물건을 아직 고려하지 않은 상태라는 것이 보장된다.
}
}

@Reflection(id: dp-knapsack-reflection) {
@Prompt(id: d-reduction) {
표를 2차원이 아니라 1차원 배열 하나로 줄이려면 무게를 어느 방향으로 훑어야 안전할지, 그리고 왜 그런지 생각해 보세요.
}

@Prompt(id: unbounded) {
물건을 여러 번 담을 수 있는 배낭 문제(무한 배낭)라면 점화식이 어떻게 달라질지 적어 보세요.
}
}
