pub fn max_or_default(values: &Vec<i32>, default: i32) -> i32 {
    if values.is_empty() {
        return default;
    }
    values.iter().fold(values[0], |acc, &x| if x > acc { x } else { acc })
}
