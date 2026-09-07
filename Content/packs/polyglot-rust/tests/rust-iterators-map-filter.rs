#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 짝수만_제곱한다() {
        assert_eq!(square_evens(&vec![1, 2, 3, 4, 5]), vec![4, 16]);
    }

    #[test]
    fn 짝수가_없으면_빈_벡터다() {
        assert_eq!(square_evens(&vec![1, 3, 5]), Vec::<i32>::new());
    }

    #[test]
    fn 빈_벡터는_빈_벡터다() {
        assert_eq!(square_evens(&vec![]), Vec::<i32>::new());
    }

    #[test]
    fn 음수_짝수도_제곱된다() {
        assert_eq!(square_evens(&vec![-2, -3, 0]), vec![4, 0]);
    }
}
