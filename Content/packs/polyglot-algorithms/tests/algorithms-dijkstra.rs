#[cfg(test)]
mod learnkit_tests {
    use super::*;

    const INF: u32 = u32::MAX;

    #[test]
    fn 시작점_거리는_0이다() {
        let adj: Vec<Vec<(usize, u32)>> = vec![vec![]];
        let dist = dijkstra(&adj, 0);
        assert_eq!(dist[0], 0);
    }

    #[test]
    fn 더_짧은_경로를_고른다() {
        let adj: Vec<Vec<(usize, u32)>> = vec![
            vec![(1, 4), (2, 1)],
            vec![(3, 1), (4, 7)],
            vec![(1, 2), (3, 5)],
            vec![(4, 3)],
            vec![],
        ];
        let dist = dijkstra(&adj, 0);
        // 0 -> 1 직접 가면 4, 0 -> 2 -> 1 로 돌아가면 1 + 2 = 3. 더 짧은 쪽을 골라야 한다.
        assert_eq!(dist, vec![0, 3, 1, 4, 7]);
    }

    #[test]
    fn 도달할_수_없는_정점은_무한대다() {
        // 0 -> 1 뿐이고, 2는 어디서도 이어지지 않는다.
        let adj: Vec<Vec<(usize, u32)>> = vec![vec![(1, 5)], vec![], vec![]];
        let dist = dijkstra(&adj, 0);
        assert_eq!(dist[0], 0);
        assert_eq!(dist[1], 5);
        assert_eq!(dist[2], INF);
    }

    #[test]
    fn 시작점이_0번이_아니어도_된다() {
        let adj: Vec<Vec<(usize, u32)>> = vec![vec![(1, 2)], vec![(2, 3)], vec![]];
        let dist = dijkstra(&adj, 1);
        assert_eq!(dist[0], INF);
        assert_eq!(dist[1], 0);
        assert_eq!(dist[2], 3);
    }

    #[test]
    fn 가중치가_0인_간선도_처리한다() {
        let adj: Vec<Vec<(usize, u32)>> = vec![vec![(1, 0)], vec![(2, 0)], vec![]];
        let dist = dijkstra(&adj, 0);
        assert_eq!(dist, vec![0, 0, 0]);
    }
}
