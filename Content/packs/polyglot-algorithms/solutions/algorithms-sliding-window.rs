pub fn min_subarray_len(xs: &[i32], target: i32) -> Option<usize> {
    let mut left = 0;
    let mut sum = 0;
    let mut best: Option<usize> = None;
    for right in 0..xs.len() {
        sum += xs[right];
        while sum >= target {
            let len = right - left + 1;
            best = Some(match best {
                Some(b) if b <= len => b,
                _ => len,
            });
            sum -= xs[left];
            left += 1;
        }
    }
    best
}
