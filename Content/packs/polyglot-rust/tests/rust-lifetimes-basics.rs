#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 뒤_문자열이_더_길면_그것을_돌려준다() {
        assert_eq!(longer("hi", "hello"), "hello");
    }

    #[test]
    fn 앞_문자열이_더_길면_그것을_돌려준다() {
        assert_eq!(longer("hello", "hi"), "hello");
    }

    #[test]
    fn 길이가_같으면_앞_문자열을_돌려준다() {
        assert_eq!(longer("abc", "xyz"), "abc");
    }

    #[test]
    fn 빈_문자열과_비교해도_동작한다() {
        assert_eq!(longer("", "a"), "a");
    }
}
