#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 사이클이_있으면_참이다() {
        let adj: Vec<Vec<usize>> = vec![vec![1], vec![2], vec![0]];
        assert!(has_cycle(&adj));
    }

    #[test]
    fn 사이클이_없으면_거짓이다() {
        // 0 -> 1, 0 -> 2, 1 -> 3, 2 -> 3 (다이아몬드 모양 DAG, 3은 두 경로로 도달하지만 사이클은 아니다)
        let adj: Vec<Vec<usize>> = vec![vec![1, 2], vec![3], vec![3], vec![]];
        assert!(!has_cycle(&adj));
    }

    #[test]
    fn 자기_자신을_가리키면_사이클이다() {
        let adj: Vec<Vec<usize>> = vec![vec![0]];
        assert!(has_cycle(&adj));
    }

    #[test]
    fn 서로_떨어진_그래프에서도_찾는다() {
        // 0 -> 1 (사이클 없음), 2 -> 3 -> 2 (사이클 있음)
        let adj: Vec<Vec<usize>> = vec![vec![1], vec![], vec![3], vec![2]];
        assert!(has_cycle(&adj));
    }

    #[test]
    fn 빈_그래프는_거짓이다() {
        let adj: Vec<Vec<usize>> = vec![];
        assert!(!has_cycle(&adj));
    }
}
