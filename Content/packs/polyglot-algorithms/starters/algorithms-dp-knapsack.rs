pub fn knapsack_max_value(weights: &[u32], values: &[u32], capacity: u32) -> u32 {
    // dp[i][cap]를 "앞의 i개 물건만 가지고 무게 한도 cap 안에서 담을 수 있는 최대 가치"로 정의해라.
    // i번째 물건을 안 담으면 dp[i-1][cap], 담으면 dp[i-1][cap - weights[i-1]] + values[i-1] 이다.
    // 물건이 cap보다 무거우면 담을 수 없다.
    unimplemented!("여기를 구현해라")
}
