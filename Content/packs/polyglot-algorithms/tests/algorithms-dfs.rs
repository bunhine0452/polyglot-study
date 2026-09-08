#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 분기_있는_그래프에서_재귀와_같은_순서다() {
        let n = 7;
        let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        let edges = [(0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (5, 6)];
        for &(u, v) in edges.iter() {
            adj[u].push(v);
            adj[v].push(u);
        }
        assert_eq!(dfs_order_iterative(n, &adj, 0), vec![0, 1, 3, 4, 2, 5, 6]);
    }

    #[test]
    fn 선형_체인은_순서대로_방문한다() {
        let n = 5;
        let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        let edges = [(0, 1), (1, 2), (2, 3), (3, 4)];
        for &(u, v) in edges.iter() {
            adj[u].push(v);
            adj[v].push(u);
        }
        assert_eq!(dfs_order_iterative(n, &adj, 0), vec![0, 1, 2, 3, 4]);
    }

    #[test]
    fn 정점_하나짜리_그래프() {
        let n = 1;
        let adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        assert_eq!(dfs_order_iterative(n, &adj, 0), vec![0]);
    }

    #[test]
    fn 닿지_않는_정점은_방문하지_않는다() {
        let n = 4;
        let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        let edges = [(0, 1), (2, 3)];
        for &(u, v) in edges.iter() {
            adj[u].push(v);
            adj[v].push(u);
        }
        assert_eq!(dfs_order_iterative(n, &adj, 0), vec![0, 1]);
    }
}
