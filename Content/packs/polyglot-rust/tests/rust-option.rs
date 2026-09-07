#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 있으면_인덱스를_찾는다() {
        assert_eq!(find_index(&vec![5, 8, 3], 8), Some(1));
    }

    #[test]
    fn 없으면_none이다() {
        assert_eq!(find_index(&vec![5, 8, 3], 9), None);
    }

    #[test]
    fn 빈_벡터는_none이다() {
        assert_eq!(find_index(&vec![], 1), None);
    }

    #[test]
    fn 첫_번째_일치를_돌려준다() {
        assert_eq!(find_index(&vec![4, 4, 4], 4), Some(0));
    }
}
