pub fn average(nums: &[i32]) -> f64 {
    if nums.is_empty() {
        return 0.0;
    }
    let sum: i32 = nums.iter().sum();
    sum as f64 / nums.len() as f64
}
