#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 회전된_배열에서_찾는다() {
        let xs = [4, 5, 6, 7, 0, 1, 2];
        assert_eq!(search_rotated(&xs, 0), Some(4));
        assert_eq!(search_rotated(&xs, 7), Some(3));
    }

    #[test]
    fn 없는_값은_None_이다() {
        let xs = [4, 5, 6, 7, 0, 1, 2];
        assert_eq!(search_rotated(&xs, 3), None);
    }

    #[test]
    fn 회전하지_않은_배열도_찾는다() {
        let xs = [1, 2, 3, 4, 5];
        assert_eq!(search_rotated(&xs, 3), Some(2));
    }

    #[test]
    fn 빈_배열에서도_패닉하지_않는다() {
        let xs: [i32; 0] = [];
        assert_eq!(search_rotated(&xs, 1), None);
    }
}
