#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 긴_단어의_코드네임() {
        assert_eq!(codename("Falcon"), "Fal-01");
    }

    #[test]
    fn 정확히_세_글자면_그대로_쓴다() {
        assert_eq!(codename("Sky"), "Sky-01");
    }

    #[test]
    fn 다른_긴_단어도_된다() {
        assert_eq!(codename("Rustacean"), "Rus-01");
    }

    #[test]
    fn 소문자로_시작해도_된다() {
        assert_eq!(codename("falcon"), "fal-01");
    }
}
