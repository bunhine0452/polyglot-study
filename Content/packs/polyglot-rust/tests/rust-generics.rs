#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 정수_목록에서_최댓값을_찾는다() {
        assert_eq!(max_of(&[3, 7, 2, 9, 4]), Some(9));
    }

    #[test]
    fn 실수_목록에서도_동작한다() {
        assert_eq!(max_of(&[1.5, 2.5, 0.5]), Some(2.5));
    }

    #[test]
    fn 원소가_하나면_그값이_최댓값이다() {
        assert_eq!(max_of(&[42]), Some(42));
    }

    #[test]
    fn 빈_목록은_none이다() {
        let empty: [i32; 0] = [];
        assert_eq!(max_of(&empty), None);
    }
}
