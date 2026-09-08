#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 선형_체인에서_순서대로_방문한다() {
        let adj = vec![vec![1], vec![0, 2], vec![1, 3], vec![2, 4], vec![3]];
        assert_eq!(bfs_order(5, &adj, 0), vec![0, 1, 2, 3, 4]);
    }

    #[test]
    fn 분기가_있으면_레벨_순서로_방문한다() {
        let adj: Vec<Vec<usize>> = vec![
            vec![1, 2],
            vec![0, 3],
            vec![0, 3, 4],
            vec![1, 2, 5],
            vec![2, 5],
            vec![3, 4, 6],
            vec![5],
        ];
        assert_eq!(bfs_order(7, &adj, 0), vec![0, 1, 2, 3, 4, 5, 6]);
    }

    #[test]
    fn 닿지_않는_정점은_결과에_없다() {
        let adj: Vec<Vec<usize>> = vec![vec![1], vec![0, 2], vec![1], vec![]];
        assert_eq!(bfs_order(4, &adj, 0), vec![0, 1, 2]);
    }

    #[test]
    fn 정점이_하나면_자기_자신만_방문한다() {
        let adj: Vec<Vec<usize>> = vec![vec![]];
        assert_eq!(bfs_order(1, &adj, 0), vec![0]);
    }
}
