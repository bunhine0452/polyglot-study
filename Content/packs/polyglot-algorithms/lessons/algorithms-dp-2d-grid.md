@Concept(id: dp-2d-grid-concept) {
지금까지의 DP 표는 한 줄(1차원)이었다. 격자 위의 경로 문제는 두 축이 필요하다 — 몇 번째 행인지, 몇 번째 열인지. 그래서 표도 `dp[행][열]` 형태의 2차원이 된다.

왼쪽 위 `(0, 0)` 에서 오른쪽 아래로, 오른쪽이나 아래로만 움직일 수 있다고 하자. `(r, c)` 에 도착하는 마지막 걸음은 위칸 `(r-1, c)` 에서 내려왔거나 왼쪽칸 `(r, c-1)` 에서 왔거나 둘 중 하나다. 그래서 `dp[r][c]` 는 그 두 칸의 값만 보고 정해진다 — 경로 수를 센다면 `dp[r][c] = dp[r-1][c] + dp[r][c-1]`, 최소 비용을 구한다면 `dp[r][c] = min(dp[r-1][c], dp[r][c-1]) + cost[r][c]` 다.

1차원 DP가 "바로 앞 한두 칸" 을 참고했다면, 2차원 DP는 "바로 위 칸과 바로 왼쪽 칸" 이라는 두 방향을 참고한다 — 축이 두 개니까 이전 상태도 두 방향에서 온다. 첫 행(`r == 0`)은 위칸이 없으니 왼쪽에서만, 첫 열(`c == 0`)은 왼쪽칸이 없으니 위에서만 올 수 있다는 경계 처리만 따로 해주면 나머지는 규칙 하나로 끝난다.

표를 왼쪽 위부터 행 우선(또는 열 우선)으로 채워나가면, `dp[r][c]` 를 채울 때 필요한 `dp[r-1][c]` 와 `dp[r][c-1]` 은 이미 채워져 있다.
}

@Example(id: dp-2d-grid-example, language: rust, expected: expected/algorithms-dp-2d-grid.txt) {
격자의 각 칸에 도착하는 경로 수를 왼쪽 위부터 채우면서, 각 칸이 위 칸과 왼쪽 칸의 합이라는 것을 확인한다.

```rust
fn grid_paths(rows: usize, cols: usize) -> Vec<Vec<u64>> {
    let mut dp = vec![vec![0u64; cols]; rows];
    for r in 0..rows {
        for c in 0..cols {
            if r == 0 && c == 0 {
                dp[r][c] = 1;
            } else {
                let from_top = if r > 0 { dp[r - 1][c] } else { 0 };
                let from_left = if c > 0 { dp[r][c - 1] } else { 0 };
                dp[r][c] = from_top + from_left;
            }
            println!("dp[{}][{}] = {}", r, c, dp[r][c]);
        }
    }
    dp
}

fn main() {
    let dp = grid_paths(3, 4);
    println!();
    for row in &dp {
        println!("{:?}", row);
    }
    println!("경로 수: {}", dp[2][3]);
}
```
}

@Blank(id: dp-2d-grid-blank, language: rust) {
이 칸에 도착하는 경로는 위에서 내려온 경우와 왼쪽에서 온 경우, 둘을 어떻게 합쳐야 할까?

```rust
fn grid_paths(rows: usize, cols: usize) -> u64 {
    let mut dp = vec![vec![0u64; cols]; rows];
    for r in 0..rows {
        for c in 0..cols {
            if r == 0 && c == 0 {
                dp[r][c] = 1;
                continue;
            }
            let from_top = if r > 0 { dp[r - 1][c] } else { 0 };
            let from_left = if c > 0 { dp[r][c - 1] } else { 0 };
            dp[r][c] = ___1___;
        }
    }
    dp[rows - 1][cols - 1]
}

fn main() {
    println!("{}", grid_paths(3, 3));
}
```

@Answer(slot: 1) {
`from_top + from_left`
}
}

@Task(id: dp-2d-grid-task, language: rust, starter: starters/algorithms-dp-2d-grid.rs, tests: tests/algorithms-dp-2d-grid.rs, solution: solutions/algorithms-dp-2d-grid.rs) {
격자의 각 칸에 지나가는 비용 `grid[r][c]` 가 있습니다. 왼쪽 위 `(0, 0)` 에서 오른쪽 아래까지, 오른쪽이나 아래로만 움직여서 도착할 때 드는 **최소 비용**을 구하세요(시작 칸의 비용도 포함합니다).

@Hint {
dp[r][c]를 "(0,0)에서 (r,c)까지 오는 최소 비용" 으로 정의해라. dp[0][0] = grid[0][0] 이다.
}

@Hint {
첫 행(r == 0)은 왼쪽 칸에서만, 첫 열(c == 0)은 위 칸에서만 올 수 있다 — 나머지 칸은 두 방향 중 더 작은 쪽을 골라라.
}

@Hint {
dp[r][c] = min(dp[r-1][c], dp[r][c-1]) + grid[r][c] 다. 표를 행 순서대로(또는 열 순서대로) 채워야 필요한 값이 이미 채워져 있다.
}
}

@Quiz(id: dp-2d-grid-quiz, answer: two-axes) {
@Question {
2차원 DP에서 dp[r][c]를 채울 때 필요한 이전 상태가 왜 두 방향(위, 왼쪽)일까?
}

@Choice(id: two-axes) {
행과 열, 두 축을 따라 각각 한 칸씩 전진할 수 있어서 이전 상태도 두 방향에서 올 수 있기 때문이다
}

@Choice(id: diagonal-move) {
격자 문제는 항상 대각선으로도 이동할 수 있기 때문이다
}

@Choice(id: array-shape) {
2차원 배열은 원래 접근 방향이 두 개이기 때문이다
}

@Explanation {
이동이 오른쪽이나 아래로만 허용되므로, 어떤 칸에 도착하는 마지막 걸음은 위 칸에서 내려왔거나 왼쪽 칸에서 왔거나 둘 중 하나다. 이 두 가지가 이전 상태의 전부이기 때문에 dp[r][c]는 dp[r-1][c]와 dp[r][c-1]만 보면 된다.
}
}

@Reflection(id: dp-2d-grid-reflection) {
@Prompt(id: diagonal) {
대각선 이동도 허용된다면 점화식이 어떻게 바뀔지 적어 보세요.
}

@Prompt(id: obstacle) {
격자에 지나갈 수 없는 칸(장애물)이 있다면, 그 칸의 dp 값을 어떻게 처리해야 나머지 칸이 올바르게 채워질지 생각해 보세요.
}
}
