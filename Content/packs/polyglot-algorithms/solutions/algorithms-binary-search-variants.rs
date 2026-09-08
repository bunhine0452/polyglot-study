pub fn search_rotated(xs: &[i32], target: i32) -> Option<usize> {
    let mut lo = 0usize;
    let mut hi = xs.len();
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        if xs[mid] == target {
            return Some(mid);
        }
        if xs[lo] <= xs[mid] {
            if xs[lo] <= target && target < xs[mid] {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        } else {
            if xs[mid] < target && target <= xs[hi - 1] {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
    }
    None
}
