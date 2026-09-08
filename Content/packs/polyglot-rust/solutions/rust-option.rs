pub fn find_index(values: &Vec<i32>, target: i32) -> Option<usize> {
    for index in 0..values.len() {
        if values[index] == target {
            return Some(index);
        }
    }
    None
}
