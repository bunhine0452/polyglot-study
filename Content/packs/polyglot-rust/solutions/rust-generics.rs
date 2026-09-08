pub fn max_of<T: PartialOrd + Copy>(list: &[T]) -> Option<T> {
    if list.is_empty() {
        return None;
    }
    let mut result = list[0];
    for &item in list {
        if item > result {
            result = item;
        }
    }
    Some(result)
}
