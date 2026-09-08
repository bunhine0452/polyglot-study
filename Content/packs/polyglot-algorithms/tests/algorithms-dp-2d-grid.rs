#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 삼바이삼_그리드는_칠이다() {
        let grid = vec![vec![1, 3, 1], vec![1, 5, 1], vec![4, 2, 1]];
        assert_eq!(min_path_sum(&grid), 7);
    }

    #[test]
    fn 이바이삼_그리드는_십이다() {
        let grid = vec![vec![1, 2, 3], vec![4, 5, 6]];
        assert_eq!(min_path_sum(&grid), 12);
    }

    #[test]
    fn 칸이_하나면_그_값이다() {
        let grid = vec![vec![5]];
        assert_eq!(min_path_sum(&grid), 5);
    }

    #[test]
    fn 한_줄짜리_그리드는_다_더한_값이다() {
        let grid = vec![vec![1, 2, 5]];
        assert_eq!(min_path_sum(&grid), 8);
        let grid2 = vec![vec![1], vec![2], vec![5]];
        assert_eq!(min_path_sum(&grid2), 8);
    }
}
