#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 고립된_정점은_빈_리스트를_갖는다() {
        let adj = build_adjacency_list(3, &[]);
        assert_eq!(adj, vec![vec![], vec![], vec![]]);
    }

    #[test]
    fn 여러_간선이_모인_정점을_정렬해서_담는다() {
        let adj = build_adjacency_list(4, &[(0, 3), (0, 1), (0, 2)]);
        assert_eq!(adj[0], vec![1, 2, 3]);
        assert_eq!(adj[1], vec![0]);
        assert_eq!(adj[2], vec![0]);
        assert_eq!(adj[3], vec![0]);
    }

    #[test]
    fn 작은_그래프_전체를_비교한다() {
        let adj = build_adjacency_list(5, &[(0, 1), (1, 2), (2, 3), (3, 4), (0, 4)]);
        assert_eq!(
            adj,
            vec![
                vec![1, 4],
                vec![0, 2],
                vec![1, 3],
                vec![2, 4],
                vec![0, 3],
            ]
        );
    }
}
