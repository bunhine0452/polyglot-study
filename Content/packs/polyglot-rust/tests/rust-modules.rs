#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 합계는_이미_구현되어_있다() {
        assert_eq!(stats::total(&[1, 2, 3]), 6);
    }

    #[test]
    fn 평균을_구한다() {
        assert_eq!(stats::average(&[2, 4, 6]), 4.0);
    }

    #[test]
    fn 빈_목록의_평균은_0이다() {
        let empty: [i32; 0] = [];
        assert_eq!(stats::average(&empty), 0.0);
    }

    #[test]
    fn 원소가_하나면_그값이_평균이다() {
        assert_eq!(stats::average(&[7]), 7.0);
    }
}
