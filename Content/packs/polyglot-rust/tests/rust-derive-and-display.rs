#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 달러와_센트를_함께_보여준다() {
        let m = Money { cents: 250 };
        assert_eq!(m.to_string(), "$2.50");
    }

    #[test]
    fn 정확히_1달러다() {
        let m = Money { cents: 100 };
        assert_eq!(m.to_string(), "$1.00");
    }

    #[test]
    fn 센트가_0이면_00으로_채운다() {
        let m = Money { cents: 0 };
        assert_eq!(m.to_string(), "$0.00");
    }

    #[test]
    fn 한자리_센트도_두자리로_보여준다() {
        let m = Money { cents: 5 };
        assert_eq!(m.to_string(), "$0.05");
    }
}
