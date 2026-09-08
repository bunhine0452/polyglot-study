@Concept(id: dp-lcs-concept) {
최장 공통 부분 수열(LCS)은 두 문자열에서 순서를 지키며(연속하지 않아도 됨) 공통으로 뽑을 수 있는 가장 긴 수열이다. 표의 두 축은 두 문자열의 길이다 — `dp[i][j]` 는 "첫 번째 문자열의 앞 `i`글자와 두 번째 문자열의 앞 `j`글자 사이의 LCS 길이" 다.

두 위치의 마지막 글자, 즉 `a[i-1]` 과 `b[j-1]` 을 비교한다. **같으면** 이 글자를 LCS에 넣을 수 있으니 두 문자열 모두 한 글자씩 줄인 부분 문제에 1을 더한다 — `dp[i][j] = dp[i-1][j-1] + 1` 이다. **다르면** 이 글자 쌍은 함께 쓸 수 없으니, 둘 중 하나만 포기한 두 부분 문제(`dp[i-1][j]`, `dp[i][j-1]`) 중 더 큰 쪽을 그대로 가져온다.

배낭 문제와 마찬가지로 대각선(`dp[i-1][j-1]`) 과 위·왼쪽(`dp[i-1][j]`, `dp[i][j-1]`) 세 칸만 보면 되고, 표를 왼쪽 위부터 채우면 필요한 값은 항상 먼저 채워져 있다.

길이만 구하는 것과 실제 문자열을 복원하는 것은 다르다. 표를 다 채운 뒤 오른쪽 아래(`dp[n][m]`) 에서 시작해 거꾸로 되짚어간다. `a[i-1] == b[j-1]` 이면 그 글자를 결과에 넣고 대각선(`i-1, j-1`) 으로 이동한다. 다르면 `dp[i-1][j]` 와 `dp[i][j-1]` 중 더 큰 값이 있던 방향으로 이동한다. `(0, 0)` 에 닿을 때까지 반복하고, 모아둔 글자를 뒤집으면 LCS 문자열이 된다.

@Visualize(id: dp-lcs, frames: visuals/dp-lcs.json) {
최장 공통 부분 수열(LCS)이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: dp-lcs-example, language: rust, expected: expected/algorithms-dp-lcs.txt) {
두 문자열의 LCS 표를 채운 뒤, 표를 거꾸로 되짚어 실제 LCS 문자열을 복원한다.

```rust
fn lcs_table(a: &[u8], b: &[u8]) -> Vec<Vec<u32>> {
    let n = a.len();
    let m = b.len();
    let mut dp = vec![vec![0u32; m + 1]; n + 1];

    for i in 1..=n {
        for j in 1..=m {
            if a[i - 1] == b[j - 1] {
                dp[i][j] = dp[i - 1][j - 1] + 1;
            } else {
                dp[i][j] = dp[i - 1][j].max(dp[i][j - 1]);
            }
        }
    }
    dp
}

fn reconstruct(a: &[u8], b: &[u8], dp: &[Vec<u32>]) -> Vec<u8> {
    let mut i = a.len();
    let mut j = b.len();
    let mut out = Vec::new();
    while i > 0 && j > 0 {
        if a[i - 1] == b[j - 1] {
            out.push(a[i - 1]);
            i -= 1;
            j -= 1;
        } else if dp[i - 1][j] >= dp[i][j - 1] {
            i -= 1;
        } else {
            j -= 1;
        }
    }
    out.reverse();
    out
}

fn main() {
    let a = b"ABCBDAB";
    let b = b"BDCABA";
    let dp = lcs_table(a, b);

    for row in &dp {
        println!("{:?}", row);
    }
    println!("LCS 길이: {}", dp[a.len()][b.len()]);

    let lcs = reconstruct(a, b, &dp);
    println!("LCS 문자열: {}", String::from_utf8(lcs).unwrap());
}
```
}

@Blank(id: dp-lcs-blank, language: rust) {
두 글자가 같을 때, 이 칸의 값은 그 글자를 포함하지 않는 대각선 칸에서 무엇을 더해야 할까?

```rust
fn lcs_length(a: &[u8], b: &[u8]) -> u32 {
    let n = a.len();
    let m = b.len();
    let mut dp = vec![vec![0u32; m + 1]; n + 1];
    for i in 1..=n {
        for j in 1..=m {
            if a[i - 1] == b[j - 1] {
                dp[i][j] = ___1___;
            } else {
                dp[i][j] = dp[i - 1][j].max(dp[i][j - 1]);
            }
        }
    }
    dp[n][m]
}

fn main() {
    println!("{}", lcs_length(b"ABCDGH", b"AEDFHR"));
}
```

@Answer(slot: 1) {
`dp[i - 1][j - 1] + 1`
}
}

@Task(id: dp-lcs-task, language: rust, starter: starters/algorithms-dp-lcs.rs, tests: tests/algorithms-dp-lcs.rs, solution: solutions/algorithms-dp-lcs.rs) {
두 문자열 `a`, `b`의 최장 공통 부분 수열을 실제 문자열로 반환하세요(순서를 지키되 연속하지 않아도 됩니다). 여러 정답이 가능한 경우가 있지만, 아래 테스트는 정답이 하나로 정해지는 입력만 씁니다.

@Hint {
먼저 dp[i][j]를 "a의 앞 i글자와 b의 앞 j글자 사이 LCS 길이" 로 채워라. a[i-1] == b[j-1]이면 dp[i-1][j-1] + 1, 아니면 dp[i-1][j]와 dp[i][j-1] 중 큰 값이다.
}

@Hint {
표를 다 채운 뒤 i = a.len(), j = b.len() 에서 시작해 i > 0 && j > 0 인 동안 되짚어라. a[i-1] == b[j-1]이면 그 글자를 모으고 i, j를 각각 하나씩 줄여라.
}

@Hint {
글자가 다르면 dp[i-1][j]와 dp[i][j-1] 중 더 큰 쪽 방향으로 이동해라. 다 모은 뒤에는 순서가 뒤집혀 있으니 reverse가 필요하다.
}
}

@Quiz(id: dp-lcs-quiz, answer: extend-diagonal) {
@Question {
LCS 표에서 a[i-1] == b[j-1] 일 때 dp[i][j] = dp[i-1][j-1] + 1 인 이유는?
}

@Choice(id: extend-diagonal) {
그 글자를 LCS에 포함시킬 수 있고, 나머지는 두 문자열에서 그 글자보다 앞쪽만 남은 부분 문제이기 때문이다
}

@Choice(id: diagonal-max) {
대각선 칸이 항상 가장 큰 값을 가지고 있기 때문이다
}

@Choice(id: strings-match) {
같은 글자가 나오면 항상 두 문자열이 그 지점부터 똑같아지기 때문이다
}

@Explanation {
a[i-1]과 b[j-1]이 같다면 이 글자 하나는 공통 부분 수열에 넣을 수 있다. 그러면 남은 문제는 이 글자 앞쪽, 즉 a의 앞 i-1글자와 b의 앞 j-1글자 사이의 LCS를 구하는 것이고, 거기에 방금 넣은 글자 하나(+1)를 더하면 된다.
}
}

@Reflection(id: dp-lcs-reflection) {
@Prompt(id: vs-knapsack) {
LCS와 배낭 문제는 둘 다 2차원 표를 쓰지만, 배낭은 위·왼쪽 두 칸을, LCS는 대각선까지 세 칸을 참고합니다. 이 차이가 어디서 나오는지 두 문제의 선택 구조로 설명해 보세요.
}

@Prompt(id: memory) {
두 문자열의 길이가 각각 수만 자라면 이 O(n*m) 표는 메모리를 많이 씁니다. 길이만 필요하고 문자열 복원이 필요 없다면 메모리를 어떻게 줄일 수 있을지 생각해 보세요.
}
}
