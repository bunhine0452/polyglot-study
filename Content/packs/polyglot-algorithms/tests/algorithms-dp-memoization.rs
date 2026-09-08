#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 다섯_중_둘은_열_가지다() {
        assert_eq!(binomial(5, 2), 10);
    }

    #[test]
    fn 여섯_중_셋은_스물_가지다() {
        assert_eq!(binomial(6, 3), 20);
    }

    #[test]
    fn 끝_경우는_하나다() {
        assert_eq!(binomial(10, 0), 1);
        assert_eq!(binomial(10, 10), 1);
        assert_eq!(binomial(0, 0), 1);
    }

    #[test]
    fn n_중_하나는_n_가지다() {
        assert_eq!(binomial(7, 1), 7);
        assert_eq!(binomial(100, 1), 100);
    }

    #[test]
    fn 큰_n도_빠르게_끝난다() {
        assert_eq!(binomial(30, 15), 155117520);
    }
}
