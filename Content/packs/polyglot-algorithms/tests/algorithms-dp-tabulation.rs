#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 빈_합은_한_가지다() {
        assert_eq!(count_ways(0), 1);
    }

    #[test]
    fn 하나와_둘은_한_가지뿐이다() {
        assert_eq!(count_ways(1), 1);
        assert_eq!(count_ways(2), 1);
    }

    #[test]
    fn 넷은_네_가지다() {
        assert_eq!(count_ways(4), 4);
    }

    #[test]
    fn 다섯은_여섯_가지다() {
        assert_eq!(count_ways(5), 6);
    }

    #[test]
    fn 열은_예순넷_가지다() {
        assert_eq!(count_ways(10), 64);
    }
}
