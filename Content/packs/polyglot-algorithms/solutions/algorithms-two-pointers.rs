pub fn two_sum_sorted(xs: &[i32], target: i32) -> Option<(usize, usize)> {
    if xs.len() < 2 {
        return None;
    }
    let mut lo = 0usize;
    let mut hi = xs.len() - 1;
    while lo < hi {
        let sum = xs[lo] + xs[hi];
        if sum == target {
            return Some((lo, hi));
        } else if sum < target {
            lo += 1;
        } else {
            hi -= 1;
        }
    }
    None
}
