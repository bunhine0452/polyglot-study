pub enum Temperature {
    Celsius(i32),
    Fahrenheit(i32),
}

pub fn to_celsius(temp: &Temperature) -> i32 {
    // Fahrenheit 면 (f - 32) * 5 / 9 로 변환하고, Celsius 면 그대로 돌려준다.
    unimplemented!("여기를 구현해라")
}
