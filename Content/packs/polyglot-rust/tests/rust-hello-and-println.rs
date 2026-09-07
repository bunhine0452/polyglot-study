#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 이름을_넣어_인사한다() {
        assert_eq!(greeting("세계"), "안녕하세요, 세계!");
    }

    #[test]
    fn 다른_이름도_된다() {
        assert_eq!(greeting("러스트"), "안녕하세요, 러스트!");
    }

    #[test]
    fn 빈_문자열은_이름_없음이다() {
        assert_eq!(greeting(""), "안녕하세요, 이름 없음!");
    }
}
