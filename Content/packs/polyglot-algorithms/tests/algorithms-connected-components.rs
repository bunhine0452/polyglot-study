#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 컴포넌트가_여러_개면_번호가_나뉜다() {
        let n = 7;
        let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        let edges = [(0, 1), (1, 2), (3, 4), (5, 6)];
        for &(u, v) in edges.iter() {
            adj[u].push(v);
            adj[v].push(u);
        }
        assert_eq!(component_ids(n, &adj), vec![0, 0, 0, 1, 1, 2, 2]);
    }

    #[test]
    fn 전체가_하나로_연결되면_모두_같은_번호다() {
        let n = 4;
        let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        let edges = [(0, 1), (1, 2), (2, 3)];
        for &(u, v) in edges.iter() {
            adj[u].push(v);
            adj[v].push(u);
        }
        assert_eq!(component_ids(n, &adj), vec![0, 0, 0, 0]);
    }

    #[test]
    fn 간선이_없으면_모두_다른_번호다() {
        let n = 3;
        let adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        assert_eq!(component_ids(n, &adj), vec![0, 1, 2]);
    }

    #[test]
    fn 빈_그래프는_빈_벡터다() {
        let n = 0;
        let adj: Vec<Vec<usize>> = Vec::new();
        assert_eq!(component_ids(n, &adj), Vec::<usize>::new());
    }
}
