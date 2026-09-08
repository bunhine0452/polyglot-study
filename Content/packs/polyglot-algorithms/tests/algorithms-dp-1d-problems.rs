#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 세_계단_예제는_십오다() {
        assert_eq!(min_cost_climbing(&[10, 15, 20]), 15);
    }

    #[test]
    fn 열_계단_예제는_육이다() {
        assert_eq!(min_cost_climbing(&[1, 100, 1, 1, 1, 100, 1, 1, 100, 1]), 6);
    }

    #[test]
    fn 비용이_전부_0이면_0이다() {
        assert_eq!(min_cost_climbing(&[0, 0]), 0);
    }

    #[test]
    fn 계단이_하나면_0이다() {
        assert_eq!(min_cost_climbing(&[5]), 0);
    }
}
