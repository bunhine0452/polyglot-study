pub fn count_value(values: &Vec<i32>, target: i32) -> i32 {
    let mut count = 0;
    for &value in values {
        if value == target {
            count += 1;
        }
    }
    count
}
