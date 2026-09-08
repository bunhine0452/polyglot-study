fn divide(a: i32, b: i32) -> Result<i32, String> {
    if b == 0 {
        Err(String::from("0으로 나눌 수 없습니다"))
    } else {
        Ok(a / b)
    }
}

pub fn safe_divide_sum(values: &Vec<i32>, divisor: i32) -> Result<i32, String> {
    // values 의 합을 구한 뒤 divide 로 나눠라. ? 로 오류를 그대로 전달한다.
    unimplemented!("여기를 구현해라")
}
