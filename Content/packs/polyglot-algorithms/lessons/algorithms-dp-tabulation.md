@Concept(id: dp-tabulation-concept) {
메모이제이션은 재귀를 그대로 두고 캐시만 끼워 넣었다. 타뷸레이션은 아예 재귀를 쓰지 않는다 — 가장 작은 부분 문제의 답부터 표에 채워 넣고, 그 값들을 이용해 한 칸씩 더 큰 문제의 답을 채워 올라간다. 이렇게 아래(작은 문제)에서 위(큰 문제)로 올라가는 방식이라 **상향식(bottom-up)** 이라 부른다.

점화식 자체는 메모이제이션과 똑같다. `fib` 라면 `table[i] = table[i-1] + table[i-2]` 다. 차이는 이 값을 재귀 호출로 얻는 게 아니라, 반복문으로 `i` 를 0부터 순서대로 늘려가며 **이미 채워진 이전 칸을 읽어서** 채운다는 것이다. `table[i]` 를 채울 차례가 됐을 때 `table[i-1]` 과 `table[i-2]` 는 이미 계산이 끝나 있다.

같은 문제를 두 방향에서 풀었을 뿐이니 결과는 메모이제이션과 정확히 같다. 다만 타뷸레이션은 재귀 호출이 없어서 **호출 스택이 쌓이지 않는다** — 아무리 큰 `n` 이어도 스택 오버플로우를 걱정할 필요가 없고, 함수 호출 오버헤드도 없다. 대신 표의 어떤 칸을 쓸지, 채우는 순서를 스스로 결정해야 한다는 점이 메모이제이션과 다르다.
}

@Example(id: dp-tabulation-example, language: rust, expected: expected/algorithms-dp-tabulation.txt) {
피보나치 표를 인덱스 2부터 순서대로 채우면서, 각 칸이 바로 이전 두 칸에서 어떻게 나오는지 확인한다.

```rust
fn fib_tabulation(n: usize) -> Vec<u64> {
    let mut table = vec![0u64; n + 1];
    if n >= 1 {
        table[1] = 1;
    }
    for i in 2..=n {
        table[i] = table[i - 1] + table[i - 2];
        println!("table[{}] = table[{}] + table[{}] = {} + {} = {}", i, i - 1, i - 2, table[i - 1], table[i - 2], table[i]);
    }
    table
}

fn main() {
    let table = fib_tabulation(10);
    println!("표 전체: {:?}", table);
    println!("fib(10) = {}", table[10]);
}
```
}

@Blank(id: dp-tabulation-blank, language: rust) {
table[i]가 바로 앞 칸(i-1)만으로는 부족하다면, 도미노를 세로로 놓는 경우까지 세려면 몇 칸 앞을 더 봐야 할까?

```rust
fn ways_tabulation(n: usize) -> u64 {
    let mut dp = vec![0u64; n + 1];
    dp[0] = 1;
    if n >= 1 {
        dp[1] = 1;
    }
    for i in 2..=n {
        dp[i] = dp[i - 1] + ___1___;
    }
    dp[n]
}

fn main() {
    for n in 0..=6 {
        println!("ways({}) = {}", n, ways_tabulation(n));
    }
}
```

@Answer(slot: 1) {
`dp[i - 2]`
}
}

@Task(id: dp-tabulation-task, language: rust, starter: starters/algorithms-dp-tabulation.rs, tests: tests/algorithms-dp-tabulation.rs, solution: solutions/algorithms-dp-tabulation.rs) {
정수 `n`을, 순서를 구분해서 1과 3과 4의 합으로 나타내는 방법의 수를 구하세요. 예를 들어 `4`는 `4`, `1+3`, `3+1`, `1+1+1+1`로 나타낼 수 있어 4가지입니다(순서가 다르면 다른 방법으로 셉니다). 재귀 없이 표를 아래에서부터 채우세요.

@Hint {
dp[0] = 1 이다 — 아무것도 더하지 않아도 합이 0이 되는 방법이 (공집합) 하나 있다고 본다.
}

@Hint {
dp[i]는 마지막에 1을 더한 경우(dp[i-1]), 3을 더한 경우(dp[i-3]), 4를 더한 경우(dp[i-4])의 수를 모두 더한 것이다 — 단, i가 그만큼 크지 않으면 그 항은 빼야 한다.
}

@Hint {
표를 인덱스 0부터 n까지 순서대로 채워라. dp[i]를 채울 때 dp[i-1], dp[i-3], dp[i-4]는 이미 다 채워져 있어야 한다.
}
}

@Quiz(id: dp-tabulation-quiz, answer: no-call-stack) {
@Question {
타뷸레이션이 메모이제이션과 비교해 갖는 가장 뚜렷한 이점은?
}

@Choice(id: no-call-stack) {
재귀 호출이 없어 호출 스택이 쌓이지 않는다
}

@Choice(id: simpler-recurrence) {
점화식이 더 단순해진다
}

@Choice(id: no-memory) {
캐시가 필요 없어 메모리를 전혀 안 쓴다
}

@Explanation {
타뷸레이션도 표라는 이름의 캐시를 그대로 쓴다 — 메모리 사용량은 메모이제이션과 비슷하다. 점화식도 똑같다. 달라지는 것은 재귀 호출 없이 반복문으로 표를 채운다는 것이고, 그래서 호출 스택이 전혀 쌓이지 않는다.
}
}

@Reflection(id: dp-tabulation-reflection) {
@Prompt(id: reverse-order) {
표를 채우는 순서를 거꾸로(n부터 0까지) 바꾸면 어떤 문제가 생길지 생각해 보세요.
}

@Prompt(id: when-memo-better) {
메모이제이션과 타뷸레이션 중 어떤 문제에는 메모이제이션이 오히려 더 유리할지, 예를 들어 설명해 보세요.
}
}
