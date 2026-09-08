#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 뒤섞인_배열을_정렬한다() {
        assert_eq!(merge_sort(&[5, 2, 4, 1, 3]), vec![1, 2, 3, 4, 5]);
    }

    #[test]
    fn 이미_정렬된_배열도_정렬된_채다() {
        assert_eq!(merge_sort(&[1, 2, 3, 4, 5]), vec![1, 2, 3, 4, 5]);
    }

    #[test]
    fn 중복값도_정렬한다() {
        assert_eq!(merge_sort(&[3, 1, 2, 3, 1]), vec![1, 1, 2, 3, 3]);
    }

    #[test]
    fn 빈_배열과_한_원소_배열도_처리한다() {
        assert_eq!(merge_sort(&[]), Vec::<i32>::new());
        assert_eq!(merge_sort(&[7]), vec![7]);
    }
}
