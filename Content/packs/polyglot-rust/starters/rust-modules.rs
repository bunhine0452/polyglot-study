pub mod stats {
    pub fn total(nums: &[i32]) -> i32 {
        nums.iter().sum()
    }

    pub fn average(nums: &[i32]) -> f64 {
        // total(nums) 를 활용해 합을 구하고, nums.len() 으로 나눠라.
        // nums 가 비어 있으면 0.0 을 돌려준다.
        unimplemented!("여기를 구현해라")
    }
}
