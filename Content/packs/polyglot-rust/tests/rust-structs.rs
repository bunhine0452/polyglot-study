#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 넓이를_계산한다() {
        let r = Rectangle::new(3, 4);
        assert_eq!(r.area(), 12);
    }

    #[test]
    fn 정사각형을_판별한다() {
        let r = Rectangle::new(5, 5);
        assert_eq!(r.is_square(), true);
    }

    #[test]
    fn 정사각형이_아니면_false다() {
        let r = Rectangle::new(2, 7);
        assert_eq!(r.is_square(), false);
    }

    #[test]
    fn 한_변이_0이어도_계산된다() {
        let r = Rectangle::new(0, 9);
        assert_eq!(r.area(), 0);
        assert_eq!(r.is_square(), false);
    }
}
