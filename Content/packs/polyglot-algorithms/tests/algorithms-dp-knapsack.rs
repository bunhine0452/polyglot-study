#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 무게_다섯_배낭은_칠이다() {
        assert_eq!(knapsack_max_value(&[2, 3, 4, 5], &[3, 4, 5, 6], 5), 7);
    }

    #[test]
    fn 무게_일곱_배낭은_구다() {
        assert_eq!(knapsack_max_value(&[1, 3, 4, 5], &[1, 4, 5, 7], 7), 9);
    }

    #[test]
    fn 다_못_들어가면_0이다() {
        assert_eq!(knapsack_max_value(&[10, 20], &[60, 100], 5), 0);
    }

    #[test]
    fn 용량이_0이면_0이다() {
        assert_eq!(knapsack_max_value(&[1, 2, 3], &[10, 15, 40], 0), 0);
    }

    #[test]
    fn 물건이_없으면_0이다() {
        assert_eq!(knapsack_max_value(&[], &[], 10), 0);
    }
}
