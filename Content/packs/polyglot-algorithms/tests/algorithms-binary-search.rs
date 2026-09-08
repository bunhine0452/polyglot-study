#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 가운데_값을_찾는다() {
        let xs = [2, 5, 8, 12, 16, 23, 38];
        assert_eq!(binary_search(&xs, 12), Some(3));
    }

    #[test]
    fn 양끝도_찾는다() {
        let xs = [2, 5, 8, 12, 16, 23, 38];
        assert_eq!(binary_search(&xs, 2), Some(0));
        assert_eq!(binary_search(&xs, 38), Some(6));
    }

    #[test]
    fn 없는_값은_None_이다() {
        let xs = [2, 5, 8, 12, 16, 23, 38];
        assert_eq!(binary_search(&xs, 7), None);
        assert_eq!(binary_search(&xs, 100), None);
    }

    #[test]
    fn 빈_배열에서도_패닉하지_않는다() {
        let xs: [i32; 0] = [];
        assert_eq!(binary_search(&xs, 1), None);
    }
}
