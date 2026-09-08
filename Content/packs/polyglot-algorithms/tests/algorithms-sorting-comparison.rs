#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 키로_정렬한다() {
        let mut xs = vec![(3, 0), (1, 1), (2, 2)];
        stable_sort_pairs(&mut xs);
        assert_eq!(xs, vec![(1, 1), (2, 2), (3, 0)]);
    }

    #[test]
    fn 같은_키의_원래_순서를_지킨다() {
        let mut xs = vec![(5, 0), (3, 1), (5, 2), (1, 3)];
        stable_sort_pairs(&mut xs);
        assert_eq!(xs, vec![(1, 3), (3, 1), (5, 0), (5, 2)]);
    }

    #[test]
    fn 이미_정렬된_배열도_그대로다() {
        let mut xs = vec![(1, 0), (2, 1), (3, 2)];
        stable_sort_pairs(&mut xs);
        assert_eq!(xs, vec![(1, 0), (2, 1), (3, 2)]);
    }

    #[test]
    fn 빈_배열도_패닉하지_않는다() {
        let mut xs: Vec<(i32, usize)> = vec![];
        stable_sort_pairs(&mut xs);
        assert_eq!(xs, Vec::<(i32, usize)>::new());
    }
}
