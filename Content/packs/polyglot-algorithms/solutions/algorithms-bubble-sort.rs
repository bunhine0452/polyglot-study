pub fn bubble_sort(xs: &mut Vec<i32>) {
    let n = xs.len();
    for i in 0..n {
        let mut swapped = false;
        for j in 0..n.saturating_sub(1 + i) {
            if xs[j] > xs[j + 1] {
                xs.swap(j, j + 1);
                swapped = true;
            }
        }
        if !swapped {
            break;
        }
    }
}
