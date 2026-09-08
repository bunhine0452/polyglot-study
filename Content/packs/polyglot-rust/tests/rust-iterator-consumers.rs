#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 최댓값을_찾는다() {
        assert_eq!(max_or_default(&vec![3, 7, 2], 0), 7);
    }

    #[test]
    fn 빈_벡터는_기본값이다() {
        assert_eq!(max_or_default(&vec![], 99), 99);
    }

    #[test]
    fn 음수만_있어도_최댓값을_찾는다() {
        assert_eq!(max_or_default(&vec![-5, -1, -9], 0), -1);
    }

    #[test]
    fn 원소가_하나면_그_값이다() {
        assert_eq!(max_or_default(&vec![4], 0), 4);
    }
}
