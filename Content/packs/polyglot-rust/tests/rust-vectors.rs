#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 값이_여러_번_나온다() {
        assert_eq!(count_value(&vec![1, 2, 2, 3, 2], 2), 3);
    }

    #[test]
    fn 값이_없으면_0이다() {
        assert_eq!(count_value(&vec![1, 2, 3], 9), 0);
    }

    #[test]
    fn 빈_벡터는_0이다() {
        assert_eq!(count_value(&vec![], 5), 0);
    }

    #[test]
    fn 음수도_셀_수_있다() {
        assert_eq!(count_value(&vec![-1, -1, 0, 1], -1), 2);
    }
}
