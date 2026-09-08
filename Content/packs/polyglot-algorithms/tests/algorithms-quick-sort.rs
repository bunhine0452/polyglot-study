#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 뒤섞인_배열을_정렬한다() {
        let mut xs = [5, 2, 8, 1, 9, 3];
        quick_sort(&mut xs);
        assert_eq!(xs, [1, 2, 3, 5, 8, 9]);
    }

    #[test]
    fn 이미_정렬된_배열도_정렬된_채다() {
        let mut xs = [1, 2, 3, 4, 5];
        quick_sort(&mut xs);
        assert_eq!(xs, [1, 2, 3, 4, 5]);
    }

    #[test]
    fn 거꾸로_정렬된_배열도_정렬한다() {
        let mut xs = [5, 4, 3, 2, 1];
        quick_sort(&mut xs);
        assert_eq!(xs, [1, 2, 3, 4, 5]);
    }

    #[test]
    fn 빈_배열과_한_원소_배열도_처리한다() {
        let mut empty: [i32; 0] = [];
        quick_sort(&mut empty);
        assert_eq!(empty.len(), 0);

        let mut one = [7];
        quick_sort(&mut one);
        assert_eq!(one, [7]);
    }
}
