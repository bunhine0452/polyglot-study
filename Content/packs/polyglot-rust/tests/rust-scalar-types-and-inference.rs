#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 두_양수의_평균() {
        assert_eq!(average(4, 5), 4.5);
    }

    #[test]
    fn 둘_다_영이면_영() {
        assert_eq!(average(0, 0), 0.0);
    }

    #[test]
    fn 음수와_양수가_섞이면() {
        assert_eq!(average(-1, 2), 0.5);
    }

    #[test]
    fn 둘_다_음수여도_된다() {
        assert_eq!(average(-3, -5), -4.0);
    }
}
