fn divide(a: i32, b: i32) -> Result<i32, String> {
    if b == 0 {
        Err(String::from("0으로 나눌 수 없습니다"))
    } else {
        Ok(a / b)
    }
}

pub fn safe_divide_sum(values: &Vec<i32>, divisor: i32) -> Result<i32, String> {
    let mut total = 0;
    for &value in values {
        total += value;
    }
    let result = divide(total, divisor)?;
    Ok(result)
}
