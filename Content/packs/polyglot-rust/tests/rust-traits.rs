#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 직사각형_넓이를_계산한다() {
        let r = Rectangle { width: 3.0, height: 4.0 };
        assert_eq!(r.area(), 12.0);
    }

    #[test]
    fn 정사각형_넓이를_계산한다() {
        let s = Square { side: 5.0 };
        assert_eq!(s.area(), 25.0);
    }

    #[test]
    fn 기본_구현으로_설명문을_만든다() {
        let r = Rectangle { width: 2.0, height: 6.0 };
        assert_eq!(r.describe(), "넓이는 12.00입니다");
    }

    #[test]
    fn 한변이_0이면_넓이도_0이다() {
        let s = Square { side: 0.0 };
        assert_eq!(s.area(), 0.0);
    }
}
