#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 섭씨는_그대로다() {
        assert_eq!(to_celsius(&Temperature::Celsius(20)), 20);
    }

    #[test]
    fn 화씨_212는_섭씨_100이다() {
        assert_eq!(to_celsius(&Temperature::Fahrenheit(212)), 100);
    }

    #[test]
    fn 화씨_32는_섭씨_0이다() {
        assert_eq!(to_celsius(&Temperature::Fahrenheit(32)), 0);
    }

    #[test]
    fn 영하도_계산된다() {
        assert_eq!(to_celsius(&Temperature::Fahrenheit(-40)), -40);
    }
}
