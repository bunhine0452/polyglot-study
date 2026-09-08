pub fn binary_search(xs: &[i32], target: i32) -> Option<usize> {
    let mut lo = 0usize;
    let mut hi = xs.len();
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        if xs[mid] == target {
            return Some(mid);
        } else if xs[mid] < target {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    None
}
