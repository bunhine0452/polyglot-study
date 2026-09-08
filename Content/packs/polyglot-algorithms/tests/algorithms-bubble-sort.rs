#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 뒤섞인_배열을_정렬한다() {
        let mut xs = vec![5, 2, 4, 1, 3];
        bubble_sort(&mut xs);
        assert_eq!(xs, vec![1, 2, 3, 4, 5]);
    }

    #[test]
    fn 이미_정렬된_배열도_정렬된_채다() {
        let mut xs = vec![1, 2, 3, 4, 5];
        bubble_sort(&mut xs);
        assert_eq!(xs, vec![1, 2, 3, 4, 5]);
    }

    #[test]
    fn 중복값도_정렬한다() {
        let mut xs = vec![3, 1, 2, 3, 1];
        bubble_sort(&mut xs);
        assert_eq!(xs, vec![1, 1, 2, 3, 3]);
    }

    #[test]
    fn 빈_배열도_패닉하지_않는다() {
        let mut xs: Vec<i32> = vec![];
        bubble_sort(&mut xs);
        assert_eq!(xs, Vec::<i32>::new());
    }
}
