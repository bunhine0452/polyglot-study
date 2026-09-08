pub fn longest_common_subsequence(a: &str, b: &str) -> String {
    // dp[i][j]를 "a의 앞 i글자와 b의 앞 j글자 사이 LCS 길이"로 정의해라.
    // a[i-1] == b[j-1] 이면 dp[i-1][j-1] + 1, 아니면 dp[i-1][j] 와 dp[i][j-1] 중 큰 값이다.
    // 표를 다 채운 뒤 (n, m)에서 (0, 0) 쪽으로 되짚어가며 실제 문자들을 모아라.
    unimplemented!("여기를 구현해라")
}
