#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 짧은_단어() {
        assert_eq!(build_pair(String::from("Go")), "Go! / Go");
    }

    #[test]
    fn 다른_단어도_된다() {
        assert_eq!(build_pair(String::from("Rust")), "Rust! / Rust");
    }

    #[test]
    fn 빈_문자열도_된다() {
        assert_eq!(build_pair(String::from("")), "! / ");
    }

    #[test]
    fn 한_글자도_된다() {
        assert_eq!(build_pair(String::from("A")), "A! / A");
    }
}
