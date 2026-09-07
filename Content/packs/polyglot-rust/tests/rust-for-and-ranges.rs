#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 양수_세_개() {
        assert_eq!(sum_three([1, 2, 3]), 6);
    }

    #[test]
    fn 전부_영이면_영() {
        assert_eq!(sum_three([0, 0, 0]), 0);
    }

    #[test]
    fn 양수와_음수가_섞이면() {
        assert_eq!(sum_three([-1, 1, 0]), 0);
    }

    #[test]
    fn 전부_음수여도_된다() {
        assert_eq!(sum_three([-5, -5, -5]), -15);
    }
}
