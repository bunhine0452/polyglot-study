pub fn count_ways(n: u32) -> u64 {
    let n = n as usize;
    let mut dp = vec![0u64; n + 1];
    dp[0] = 1;
    for i in 1..=n {
        let mut total = dp[i - 1];
        if i >= 3 {
            total += dp[i - 3];
        }
        if i >= 4 {
            total += dp[i - 4];
        }
        dp[i] = total;
    }
    dp[n]
}
