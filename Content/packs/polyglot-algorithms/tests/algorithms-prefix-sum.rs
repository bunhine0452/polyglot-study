#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 단일_원소_구간() {
        let xs = [4, 2, 7, 1, 5];
        assert_eq!(range_sums(&xs, &[(2, 2)]), vec![7]);
    }

    #[test]
    fn 전체_구간() {
        let xs = [4, 2, 7, 1, 5];
        assert_eq!(range_sums(&xs, &[(0, 4)]), vec![19]);
    }

    #[test]
    fn 여러_질의를_한번에() {
        let xs = [4, 2, 7, 1, 5, 3, 8];
        assert_eq!(
            range_sums(&xs, &[(0, 2), (3, 5), (1, 6), (0, 6)]),
            vec![13, 9, 26, 30]
        );
    }

    #[test]
    fn 빈_질의_목록이면_빈_결과() {
        let xs = [1, 2, 3];
        assert_eq!(range_sums(&xs, &[]), Vec::<i64>::new());
    }

    #[test]
    fn 큰_값도_넘치지_않는다() {
        let xs = [1_000_000_000, 1_000_000_000, 1_000_000_000];
        assert_eq!(range_sums(&xs, &[(0, 2)]), vec![3_000_000_000i64]);
    }
}
