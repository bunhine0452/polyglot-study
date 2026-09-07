#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 정상_나눗셈은_ok다() {
        assert_eq!(safe_divide_sum(&vec![2, 4, 6], 3), Ok(4));
    }

    #[test]
    fn 영으로_나누면_err다() {
        assert_eq!(
            safe_divide_sum(&vec![1, 2, 3], 0),
            Err(String::from("0으로 나눌 수 없습니다"))
        );
    }

    #[test]
    fn 빈_벡터는_합이_0이라_0을_돌려준다() {
        assert_eq!(safe_divide_sum(&vec![], 5), Ok(0));
    }

    #[test]
    fn 음수도_더해진다() {
        assert_eq!(safe_divide_sum(&vec![-2, -2], 2), Ok(-2));
    }
}
