pub fn range_sums(xs: &[i32], queries: &[(usize, usize)]) -> Vec<i64> {
    // prefix[0] = 0, prefix[i + 1] = prefix[i] + xs[i] 인 prefix 배열을 먼저 만들어라.
    // 이후 각 질의 (l, r) 은 prefix[r + 1] - prefix[l] 로 답할 수 있다.
    unimplemented!("여기를 구현해라")
}
