pub fn insertion_sort(xs: &mut Vec<i32>) {
    for i in 1..xs.len() {
        let key = xs[i];
        let mut j = i;
        while j > 0 && xs[j - 1] > key {
            xs[j] = xs[j - 1];
            j -= 1;
        }
        xs[j] = key;
    }
}
