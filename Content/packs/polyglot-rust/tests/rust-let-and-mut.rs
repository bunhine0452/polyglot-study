#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 양수를_두_번_늘린다() {
        assert_eq!(bump_twice(5), 7);
    }

    #[test]
    fn 영에서_시작해도_늘어난다() {
        assert_eq!(bump_twice(0), 2);
    }

    #[test]
    fn 음수도_늘어난다() {
        assert_eq!(bump_twice(-3), -1);
    }
}
