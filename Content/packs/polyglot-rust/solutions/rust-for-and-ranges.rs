pub fn sum_three(nums: [i32; 3]) -> i32 {
    let mut total = 0;
    for n in nums {
        total = total + n;
    }
    total
}
