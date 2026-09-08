#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 별_세개_붙이기() {
        let mut s = String::from("hi");
        pad_with_stars(&mut s, 3);
        assert_eq!(s, "hi***");
    }

    #[test]
    fn 개수가_영이면_그대로() {
        let mut s = String::from("hi");
        pad_with_stars(&mut s, 0);
        assert_eq!(s, "hi");
    }

    #[test]
    fn 별_하나만_붙이기() {
        let mut s = String::from("go");
        pad_with_stars(&mut s, 1);
        assert_eq!(s, "go*");
    }

    #[test]
    fn 다른_단어에도_적용된다() {
        let mut s = String::from("rust");
        pad_with_stars(&mut s, 5);
        assert_eq!(s, "rust*****");
    }
}
