pub fn power(base: i64, exp: u32) -> i64 {
    if exp == 0 {
        return 1;
    }
    base * power(base, exp - 1)
}
