pub fn min_cost_climbing(cost: &[u32]) -> u32 {
    let n = cost.len();
    let mut dp = vec![0u32; n + 1];
    for i in 2..=n {
        let from_one_back = dp[i - 1] + cost[i - 1];
        let from_two_back = dp[i - 2] + cost[i - 2];
        dp[i] = from_one_back.min(from_two_back);
    }
    dp[n]
}
