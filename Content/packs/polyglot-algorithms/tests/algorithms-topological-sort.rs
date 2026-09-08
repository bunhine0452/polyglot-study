#[cfg(test)]
mod learnkit_tests {
    use super::*;

    fn is_valid_topo_order(adj: &Vec<Vec<usize>>, order: &Vec<usize>) -> bool {
        let mut pos = vec![0usize; adj.len()];
        for (i, &v) in order.iter().enumerate() {
            pos[v] = i;
        }
        for (u, neighbors) in adj.iter().enumerate() {
            for &v in neighbors {
                if pos[u] >= pos[v] {
                    return false;
                }
            }
        }
        true
    }

    #[test]
    fn 사이클이_없으면_위상_정렬_결과를_돌려준다() {
        let adj: Vec<Vec<usize>> = vec![vec![1, 2], vec![3], vec![3], vec![4], vec![]];
        let order = topo_sort(&adj).expect("사이클이 없으니 Some 이어야 한다");
        assert_eq!(order.len(), 5);
        assert!(is_valid_topo_order(&adj, &order));
    }

    #[test]
    fn 사이클이_있으면_없다고_한다() {
        let adj: Vec<Vec<usize>> = vec![vec![1], vec![2], vec![0]];
        assert_eq!(topo_sort(&adj), None);
    }

    #[test]
    fn 정점이_모두_들어있다() {
        let adj: Vec<Vec<usize>> = vec![vec![1, 2], vec![3], vec![3], vec![4], vec![]];
        let mut order = topo_sort(&adj).unwrap();
        order.sort();
        assert_eq!(order, vec![0, 1, 2, 3, 4]);
    }

    #[test]
    fn 독립된_정점도_포함된다() {
        // 0 -> 1, 2는 어디에도 연결되지 않은 독립된 정점
        let adj: Vec<Vec<usize>> = vec![vec![1], vec![], vec![]];
        let order = topo_sort(&adj).unwrap();
        assert!(is_valid_topo_order(&adj, &order));
        let mut sorted = order.clone();
        sorted.sort();
        assert_eq!(sorted, vec![0, 1, 2]);
    }

    #[test]
    fn 빈_그래프는_빈_순서다() {
        let adj: Vec<Vec<usize>> = vec![];
        assert_eq!(topo_sort(&adj), Some(vec![]));
    }
}
