pub fn knapsack_max_value(weights: &[u32], values: &[u32], capacity: u32) -> u32 {
    let n = weights.len();
    let capacity = capacity as usize;
    let mut dp = vec![vec![0u32; capacity + 1]; n + 1];

    for i in 1..=n {
        let w = weights[i - 1] as usize;
        let v = values[i - 1];
        for cap in 0..=capacity {
            let without = dp[i - 1][cap];
            dp[i][cap] = if w > cap {
                without
            } else {
                without.max(dp[i - 1][cap - w] + v)
            };
        }
    }

    dp[n][capacity]
}
