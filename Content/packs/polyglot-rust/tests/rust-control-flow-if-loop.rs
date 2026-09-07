#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 다섯에서_다섯_번() {
        assert_eq!(countdown_steps(5), 5);
    }

    #[test]
    fn 영이면_한_번도_안_줄인다() {
        assert_eq!(countdown_steps(0), 0);
    }

    #[test]
    fn 하나에서_한_번() {
        assert_eq!(countdown_steps(1), 1);
    }

    #[test]
    fn 큰_수도_된다() {
        assert_eq!(countdown_steps(10), 10);
    }
}
