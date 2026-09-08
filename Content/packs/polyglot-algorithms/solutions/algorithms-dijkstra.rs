pub fn dijkstra(adj: &Vec<Vec<(usize, u32)>>, start: usize) -> Vec<u32> {
    const INF: u32 = u32::MAX;
    let n = adj.len();
    let mut dist = vec![INF; n];
    let mut done = vec![false; n];
    dist[start] = 0;

    for _ in 0..n {
        let mut u = None;
        for v in 0..n {
            if !done[v] && (u.is_none() || dist[v] < dist[u.unwrap()]) {
                u = Some(v);
            }
        }
        let u = match u {
            Some(u) if dist[u] != INF => u,
            _ => break,
        };

        done[u] = true;
        for &(v, w) in &adj[u] {
            if !done[v] && dist[u] + w < dist[v] {
                dist[v] = dist[u] + w;
            }
        }
    }
    dist
}
