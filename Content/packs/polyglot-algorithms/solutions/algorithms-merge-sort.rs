pub fn merge_sort(xs: &[i32]) -> Vec<i32> {
    if xs.len() <= 1 {
        return xs.to_vec();
    }
    let mid = xs.len() / 2;
    let left = merge_sort(&xs[..mid]);
    let right = merge_sort(&xs[mid..]);
    merge(&left, &right)
}

fn merge(left: &[i32], right: &[i32]) -> Vec<i32> {
    let mut result = Vec::with_capacity(left.len() + right.len());
    let mut i = 0;
    let mut j = 0;
    while i < left.len() && j < right.len() {
        if left[i] <= right[j] {
            result.push(left[i]);
            i += 1;
        } else {
            result.push(right[j]);
            j += 1;
        }
    }
    result.extend_from_slice(&left[i..]);
    result.extend_from_slice(&right[j..]);
    result
}
