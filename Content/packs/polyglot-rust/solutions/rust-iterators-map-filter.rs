pub fn square_evens(values: &Vec<i32>) -> Vec<i32> {
    values
        .iter()
        .filter(|&&n| n % 2 == 0)
        .map(|n| n * n)
        .collect()
}
