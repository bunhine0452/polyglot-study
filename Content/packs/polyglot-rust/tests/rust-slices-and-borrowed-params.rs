#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 벡터_평균을_구한다() {
        let v = vec![2, 4, 6];
        assert_eq!(average(&v), 4.0);
    }

    #[test]
    fn 배열도_받는다() {
        let arr = [10, 20, 30, 40];
        assert_eq!(average(&arr), 25.0);
    }

    #[test]
    fn 부분_슬라이스도_받는다() {
        let v = vec![1, 2, 3, 4];
        assert_eq!(average(&v[1..]), 3.0);
    }

    #[test]
    fn 빈_슬라이스는_0이다() {
        let empty: [i32; 0] = [];
        assert_eq!(average(&empty), 0.0);
    }
}
