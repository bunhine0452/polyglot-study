#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 조건을_만족하는_최소_길이를_찾는다() {
        let xs = [2, 3, 1, 2, 4, 3];
        assert_eq!(min_subarray_len(&xs, 7), Some(2));
    }

    #[test]
    fn 전체_합도_모자라면_None_이다() {
        let xs = [1, 1, 1];
        assert_eq!(min_subarray_len(&xs, 10), None);
    }

    #[test]
    fn 전체_배열이_답인_경우() {
        let xs = [1, 1, 1, 1];
        assert_eq!(min_subarray_len(&xs, 4), Some(4));
    }

    #[test]
    fn 단일_원소가_이미_조건을_만족한다() {
        let xs = [10, 2, 3];
        assert_eq!(min_subarray_len(&xs, 7), Some(1));
    }
}
