pub fn countdown_steps(n: i32) -> i32 {
    let mut remaining = n;
    let mut steps = 0;
    while remaining > 0 {
        remaining = remaining - 1;
        steps = steps + 1;
    }
    steps
}
