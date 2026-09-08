pub fn build_adjacency_list(n: usize, edges: &[(usize, usize)]) -> Vec<Vec<usize>> {
    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    for &(u, v) in edges.iter() {
        adj[u].push(v);
        adj[v].push(u);
    }
    for neighbors in adj.iter_mut() {
        neighbors.sort();
    }
    adj
}
