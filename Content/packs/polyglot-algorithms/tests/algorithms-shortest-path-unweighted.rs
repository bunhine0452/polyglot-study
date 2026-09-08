#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn start_과_goal_이_같으면_자기_자신뿐이다() {
        let adj: Vec<Vec<usize>> = vec![
            vec![1, 2],
            vec![0, 3],
            vec![0, 3, 4],
            vec![1, 2, 5],
            vec![2, 5],
            vec![3, 4],
        ];
        assert_eq!(shortest_path(6, &adj, 0, 0), Some(vec![0]));
    }

    #[test]
    fn 일반적인_경로를_복원한다() {
        let adj: Vec<Vec<usize>> = vec![
            vec![1, 2],
            vec![0, 3],
            vec![0, 3, 4],
            vec![1, 2, 5],
            vec![2, 5],
            vec![3, 4],
        ];
        assert_eq!(shortest_path(6, &adj, 0, 5), Some(vec![0, 1, 3, 5]));
    }

    #[test]
    fn 닿을_수_없으면_None_이다() {
        let adj: Vec<Vec<usize>> = vec![vec![1], vec![0], vec![], vec![]];
        assert_eq!(shortest_path(4, &adj, 0, 2), None);
    }

    #[test]
    fn 인접한_경우_두_정점만_있다() {
        let adj: Vec<Vec<usize>> = vec![
            vec![1, 2],
            vec![0, 3],
            vec![0, 3, 4],
            vec![1, 2, 5],
            vec![2, 5],
            vec![3, 4],
        ];
        assert_eq!(shortest_path(6, &adj, 0, 1), Some(vec![0, 1]));
    }
}
