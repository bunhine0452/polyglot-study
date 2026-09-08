pub mod stats {
    pub fn total(nums: &[i32]) -> i32 {
        nums.iter().sum()
    }

    pub fn average(nums: &[i32]) -> f64 {
        if nums.is_empty() {
            return 0.0;
        }
        total(nums) as f64 / nums.len() as f64
    }
}
