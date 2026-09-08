pub fn topo_sort(adj: &Vec<Vec<usize>>) -> Option<Vec<usize>> {
    let n = adj.len();
    let mut state = vec![0u8; n];
    let mut order = Vec::new();
    let mut ok = true;

    fn visit(u: usize, adj: &Vec<Vec<usize>>, state: &mut Vec<u8>, order: &mut Vec<usize>, ok: &mut bool) {
        state[u] = 1;
        for &v in &adj[u] {
            if state[v] == 1 {
                *ok = false;
            } else if state[v] == 0 {
                visit(v, adj, state, order, ok);
            }
        }
        state[u] = 2;
        order.push(u);
    }

    for start in 0..n {
        if state[start] == 0 {
            visit(start, adj, &mut state, &mut order, &mut ok);
        }
    }

    if !ok {
        return None;
    }
    order.reverse();
    Some(order)
}
