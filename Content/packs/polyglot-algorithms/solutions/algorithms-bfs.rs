pub fn bfs_order(n: usize, adj: &Vec<Vec<usize>>, start: usize) -> Vec<usize> {
    let mut visited = vec![false; n];
    let mut order = Vec::new();
    let mut queue = std::collections::VecDeque::new();
    visited[start] = true;
    queue.push_back(start);
    while let Some(u) = queue.pop_front() {
        order.push(u);
        for &v in &adj[u] {
            if !visited[v] {
                visited[v] = true;
                queue.push_back(v);
            }
        }
    }
    order
}
