@Concept(id: dp-1d-problems-concept) {
지금까지의 1차원 DP는 표의 각 칸이 바로 앞 칸 하나 또는 두 칸만 참고했다. 이번에는 그 틀 안에서 "고르거나 건너뛴다" 는 선택이 들어간 문제 두 개를 본다.

계단 오르기: 한 번에 1칸 또는 2칸을 오를 수 있을 때 n칸짜리 계단을 오르는 방법의 수는 `dp[i] = dp[i-1] + dp[i-2]` 다 — i번째 칸에 도착하는 마지막 걸음이 1칸이었거나 2칸이었거나 둘 중 하나이기 때문이다. 피보나치와 점화식이 똑같다.

집 도둑: 일렬로 늘어선 집을 털 때 이웃한 두 집을 동시에 털 수 없다는 제약이 있다. `i`번째 집까지 봤을 때 최댓값은 두 가지 중 하나다 — **이 집을 안 턴다**(`dp[i-1]` 그대로), 또는 **이 집을 턴다**(`dp[i-2]` 에 이 집 값을 더함, 바로 앞 집은 건드릴 수 없으니까). 둘 중 큰 쪽을 고른다: `dp[i] = max(dp[i-1], dp[i-2] + values[i-1])`.

두 문제 모두 "이 칸의 답이 바로 앞 한두 칸에서 어떻게 나오는가" 를 점화식으로 세우는 게 전부다. 계단 오르기는 선택지를 **더하고**(경우의 수), 집 도둑은 선택지 중 **고른다**(최댓값) — 문제가 묻는 것이 "몇 가지냐" 인지 "최댓값이 얼마냐" 인지에 따라 점화식의 연산이 달라진다는 것이 이번 편의 핵심이다.

@Visualize(id: dp-1d-problems, frames: visuals/dp-1d-problems.json) {
1차원 DP 응용이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: dp-1d-problems-example, language: rust, expected: expected/algorithms-dp-1d-problems.txt) {
계단 오르기와 집 도둑, 두 1차원 DP 표가 채워지는 과정을 각각 확인한다. 집 도둑은 각 칸에서 안 턴 값과 턴 값을 비교하는 과정도 함께 찍는다.

```rust
fn climb_stairs(n: usize) -> Vec<u64> {
    let mut dp = vec![0u64; n + 1];
    dp[0] = 1;
    if n >= 1 {
        dp[1] = 1;
    }
    for i in 2..=n {
        dp[i] = dp[i - 1] + dp[i - 2];
    }
    dp
}

fn rob_houses(values: &[u64]) -> Vec<u64> {
    let n = values.len();
    let mut dp = vec![0u64; n + 1];
    dp[0] = 0;
    if n >= 1 {
        dp[1] = values[0];
    }
    for i in 2..=n {
        let skip = dp[i - 1];
        let take = dp[i - 2] + values[i - 1];
        dp[i] = skip.max(take);
        println!(
            "dp[{}] = max(안 턴다: dp[{}]={}, 턴다: dp[{}]+집{}={}+{}={}) = {}",
            i, i - 1, skip, i - 2, i, dp[i - 2], values[i - 1], take, dp[i]
        );
    }
    dp
}

fn main() {
    let stairs = climb_stairs(6);
    println!("계단 오르기 표: {:?}", stairs);
    println!("6칸을 오르는 방법: {}가지", stairs[6]);

    println!();
    let houses = [2, 7, 9, 3, 1];
    let dp = rob_houses(&houses);
    println!("집 도둑 표: {:?}", dp);
    println!("최대로 훔칠 수 있는 금액: {}", dp[houses.len()]);
}
```
}

@Blank(id: dp-1d-problems-blank, language: rust) {
이 집을 털 때와 안 털 때 중, 더 이득인 쪽을 골라야 한다면 두 값을 어떻게 비교해야 할까?

```rust
fn rob(values: &[u64]) -> u64 {
    let n = values.len();
    let mut dp = vec![0u64; n + 1];
    for i in 1..=n {
        if i == 1 {
            dp[1] = values[0];
            continue;
        }
        let skip = dp[i - 1];
        let take = dp[i - 2] + values[i - 1];
        dp[i] = ___1___;
    }
    dp[n]
}

fn main() {
    let houses = [3, 2, 5, 10, 7];
    println!("{}", rob(&houses));
}
```

@Answer(slot: 1) {
`skip.max(take)`
}
}

@Task(id: dp-1d-problems-task, language: rust, starter: starters/algorithms-dp-1d-problems.rs, tests: tests/algorithms-dp-1d-problems.rs, solution: solutions/algorithms-dp-1d-problems.rs) {
계단마다 오르는 비용 `cost[i]` 가 있습니다. 0번이나 1번 계단에서는 무료로 시작할 수 있고, 한 번에 한 칸 또는 두 칸을 오를 수 있습니다. 맨 위(마지막 계단보다 한 칸 더 위)까지 오르는 최소 비용을 구하세요.

@Hint {
dp[i]를 "i번째 계단(맨 위 포함)까지 오르는 데 드는 최소 비용" 으로 정의해라. dp[0] = dp[1] = 0 이다 — 둘 다 무료로 시작할 수 있으니까.
}

@Hint {
i번째 계단에 도착하는 마지막 걸음은 (i-1)번에서 한 칸을 오르거나, (i-2)번에서 두 칸을 오르거나 둘 중 하나다. 각 경우 그 계단을 밟는 비용을 더해야 한다.
}

@Hint {
dp[i] = min(dp[i-1] + cost[i-1], dp[i-2] + cost[i-2]) 이다. cost 배열의 인덱스가 dp보다 하나씩 밀려 있다는 것에 주의해라.
}
}

@Quiz(id: dp-1d-problems-quiz, answer: choose-better) {
@Question {
집 도둑 문제에서 dp[i] = max(dp[i-1], dp[i-2] + values[i-1]) 이라는 점화식이 뜻하는 것은?
}

@Choice(id: choose-better) {
i번째 집을 안 털 때와 털 때 중 더 큰 금액을 고른다
}

@Choice(id: always-take) {
항상 dp[i-2]에 i번째 집 값을 더한 쪽을 고른다
}

@Choice(id: always-together) {
i번째 집과 i-1번째 집을 항상 같이 턴다
}

@Explanation {
dp[i-1]은 i번째 집을 안 털었을 때(바로 앞 상태를 그대로 이어받음), dp[i-2] + values[i-1]은 i번째 집을 털었을 때(이웃 제약 때문에 i-1번째는 건너뛰고 그 앞 상태에 이 집 값을 더함)다. 두 경우 중 더 큰 쪽이 i번째 집까지의 최댓값이다.
}
}

@Reflection(id: dp-1d-problems-reflection) {
@Prompt(id: add-vs-max) {
계단 오르기는 경우의 수를 더하고, 집 도둑은 최댓값을 고릅니다. 같은 모양의 점화식(dp[i-1]과 dp[i-2] 참조)인데 왜 연산이 다른지, 문제가 묻는 것과 연결지어 설명해 보세요.
}

@Prompt(id: circular-houses) {
집 도둑 문제에서 집이 원형으로 늘어서 있어 첫 집과 마지막 집도 이웃이라면, 지금 풀이를 어떻게 바꿔야 할지 생각해 보세요.
}
}
