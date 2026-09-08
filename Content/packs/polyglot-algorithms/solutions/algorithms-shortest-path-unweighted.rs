pub fn shortest_path(n: usize, adj: &Vec<Vec<usize>>, start: usize, goal: usize) -> Option<Vec<usize>> {
    if start == goal {
        return Some(vec![start]);
    }
    let mut dist = vec![-1i32; n];
    let mut parent: Vec<Option<usize>> = vec![None; n];
    let mut queue = std::collections::VecDeque::new();
    dist[start] = 0;
    queue.push_back(start);

    while let Some(u) = queue.pop_front() {
        if u == goal {
            break;
        }
        for &v in &adj[u] {
            if dist[v] == -1 {
                dist[v] = dist[u] + 1;
                parent[v] = Some(u);
                queue.push_back(v);
            }
        }
    }

    if dist[goal] == -1 {
        return None;
    }

    let mut path = vec![goal];
    let mut cur = goal;
    while let Some(p) = parent[cur] {
        path.push(p);
        cur = p;
    }
    path.reverse();
    Some(path)
}
