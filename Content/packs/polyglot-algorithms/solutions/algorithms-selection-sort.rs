pub fn selection_sort(xs: &mut Vec<i32>) {
    let n = xs.len();
    for i in 0..n {
        let mut min_idx = i;
        for j in (i + 1)..n {
            if xs[j] < xs[min_idx] {
                min_idx = j;
            }
        }
        xs.swap(i, min_idx);
    }
}
