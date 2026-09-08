pub fn min_path_sum(grid: &[Vec<u32>]) -> u32 {
    let rows = grid.len();
    let cols = grid[0].len();
    let mut dp = vec![vec![0u32; cols]; rows];
    for r in 0..rows {
        for c in 0..cols {
            let cost = grid[r][c];
            dp[r][c] = if r == 0 && c == 0 {
                cost
            } else if r == 0 {
                dp[r][c - 1] + cost
            } else if c == 0 {
                dp[r - 1][c] + cost
            } else {
                dp[r - 1][c].min(dp[r][c - 1]) + cost
            };
        }
    }
    dp[rows - 1][cols - 1]
}
