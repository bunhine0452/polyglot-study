pub fn range_sums(xs: &[i32], queries: &[(usize, usize)]) -> Vec<i64> {
    let mut prefix = vec![0i64; xs.len() + 1];
    for i in 0..xs.len() {
        prefix[i + 1] = prefix[i] + xs[i] as i64;
    }
    queries.iter().map(|&(l, r)| prefix[r + 1] - prefix[l]).collect()
}
