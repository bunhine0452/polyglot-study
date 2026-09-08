pub enum Temperature {
    Celsius(i32),
    Fahrenheit(i32),
}

pub fn to_celsius(temp: &Temperature) -> i32 {
    match temp {
        Temperature::Celsius(value) => *value,
        Temperature::Fahrenheit(value) => (value - 32) * 5 / 9,
    }
}
