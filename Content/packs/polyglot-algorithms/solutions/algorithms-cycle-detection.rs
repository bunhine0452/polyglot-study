pub fn has_cycle(adj: &Vec<Vec<usize>>) -> bool {
    let n = adj.len();
    let mut state = vec![0u8; n];

    fn visit(u: usize, adj: &Vec<Vec<usize>>, state: &mut Vec<u8>) -> bool {
        state[u] = 1;
        for &v in &adj[u] {
            if state[v] == 1 {
                return true;
            }
            if state[v] == 0 && visit(v, adj, state) {
                return true;
            }
        }
        state[u] = 2;
        false
    }

    for start in 0..n {
        if state[start] == 0 && visit(start, adj, &mut state) {
            return true;
        }
    }
    false
}
