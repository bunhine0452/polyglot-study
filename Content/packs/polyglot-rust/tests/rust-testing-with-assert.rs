#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 구십점_이상은_a다() {
        assert_eq!(letter_grade(95), 'A');
    }

    #[test]
    fn 경계값_구십점은_a다() {
        assert_eq!(letter_grade(90), 'A');
    }

    #[test]
    fn 경계값_팔십구점은_b다() {
        assert_eq!(letter_grade(89), 'B');
    }

    #[test]
    fn 육십점_미만은_f다() {
        assert_eq!(letter_grade(59), 'F');
    }

    #[test]
    fn 영점도_f다() {
        assert_eq!(letter_grade(0), 'F');
    }
}
