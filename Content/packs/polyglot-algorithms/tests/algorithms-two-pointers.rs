#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 중간에서_짝을_찾는다() {
        let xs = [1, 2, 4, 6, 8, 9, 12, 14, 17, 20];
        assert_eq!(two_sum_sorted(&xs, 16), Some((1, 7)));
    }

    #[test]
    fn 양끝이_짝이다() {
        let xs = [1, 2, 4, 6, 8, 9, 12, 14, 17, 20];
        assert_eq!(two_sum_sorted(&xs, 21), Some((0, 9)));
    }

    #[test]
    fn 짝이_없으면_None_이다() {
        let xs = [1, 2, 4, 6, 8, 9, 12, 14, 17, 20];
        assert_eq!(two_sum_sorted(&xs, 100), None);
    }

    #[test]
    fn 원소가_하나뿐이면_None_이다() {
        let xs = [5];
        assert_eq!(two_sum_sorted(&xs, 10), None);
    }

    #[test]
    fn 빈_배열이면_None_이다() {
        let xs: [i32; 0] = [];
        assert_eq!(two_sum_sorted(&xs, 0), None);
    }
}
