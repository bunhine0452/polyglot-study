#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 지수가_0이면_1이다() {
        assert_eq!(power(5, 0), 1);
        assert_eq!(power(0, 0), 1);
    }

    #[test]
    fn 거듭제곱을_계산한다() {
        assert_eq!(power(2, 10), 1024);
        assert_eq!(power(3, 4), 81);
    }

    #[test]
    fn 지수가_1이면_밑_그대로다() {
        assert_eq!(power(7, 1), 7);
    }

    #[test]
    fn 밑이_음수여도_계산한다() {
        assert_eq!(power(-2, 3), -8);
        assert_eq!(power(-2, 2), 4);
    }
}
