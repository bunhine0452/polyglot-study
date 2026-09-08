pub fn stable_sort_pairs(xs: &mut Vec<(i32, usize)>) {
    let n = xs.len();
    for i in 1..n {
        let key = xs[i];
        let mut j = i;
        while j > 0 && xs[j - 1].0 > key.0 {
            xs[j] = xs[j - 1];
            j -= 1;
        }
        xs[j] = key;
    }
}
