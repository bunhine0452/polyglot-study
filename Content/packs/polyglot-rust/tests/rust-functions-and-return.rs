#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 어는점() {
        assert_eq!(celsius_to_fahrenheit(0.0), 32.0);
    }

    #[test]
    fn 끓는점() {
        assert_eq!(celsius_to_fahrenheit(100.0), 212.0);
    }

    #[test]
    fn 섭씨와_화씨가_같아지는_점() {
        assert_eq!(celsius_to_fahrenheit(-40.0), -40.0);
    }

    #[test]
    fn 스무도() {
        assert_eq!(celsius_to_fahrenheit(20.0), 68.0);
    }
}
