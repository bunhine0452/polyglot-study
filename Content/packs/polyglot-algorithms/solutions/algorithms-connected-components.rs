pub fn component_ids(n: usize, adj: &Vec<Vec<usize>>) -> Vec<usize> {
    let mut ids = vec![0usize; n];
    let mut visited = vec![false; n];
    let mut current = 0;
    for v in 0..n {
        if !visited[v] {
            let mut stack = vec![v];
            visited[v] = true;
            while let Some(u) = stack.pop() {
                ids[u] = current;
                for &w in &adj[u] {
                    if !visited[w] {
                        visited[w] = true;
                        stack.push(w);
                    }
                }
            }
            current += 1;
        }
    }
    ids
}
