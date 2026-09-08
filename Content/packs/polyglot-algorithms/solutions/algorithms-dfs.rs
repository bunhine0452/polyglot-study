pub fn dfs_order_iterative(n: usize, adj: &Vec<Vec<usize>>, start: usize) -> Vec<usize> {
    let mut visited = vec![false; n];
    let mut order = Vec::new();
    let mut stack = vec![start];
    while let Some(u) = stack.pop() {
        if visited[u] {
            continue;
        }
        visited[u] = true;
        order.push(u);
        for &v in adj[u].iter().rev() {
            if !visited[v] {
                stack.push(v);
            }
        }
    }
    order
}
