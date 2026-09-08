pub fn quick_sort(xs: &mut [i32]) {
    if xs.len() <= 1 {
        return;
    }
    let p = partition(xs);
    quick_sort(&mut xs[..p]);
    quick_sort(&mut xs[p + 1..]);
}

fn partition(xs: &mut [i32]) -> usize {
    let pivot = xs[xs.len() - 1];
    let mut i = 0;
    for j in 0..xs.len() - 1 {
        if xs[j] < pivot {
            xs.swap(i, j);
            i += 1;
        }
    }
    xs.swap(i, xs.len() - 1);
    i
}
