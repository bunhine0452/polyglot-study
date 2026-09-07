#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 빈도_내림차순으로_정렬한다() {
        let text = "the quick brown fox the lazy dog the fox";
        let result = top_words(text, 2).unwrap();
        assert_eq!(result, vec![(String::from("the"), 3), (String::from("fox"), 2)]);
    }

    #[test]
    fn 동점이면_단어_오름차순이다() {
        let text = "b a b a c c";
        let result = top_words(text, 3).unwrap();
        assert_eq!(
            result,
            vec![
                (String::from("a"), 2),
                (String::from("b"), 2),
                (String::from("c"), 2),
            ]
        );
    }

    #[test]
    fn n이_전체_단어_종류보다_크면_있는_만큼만_돌려준다() {
        let text = "one two two";
        let result = top_words(text, 10).unwrap();
        assert_eq!(result, vec![(String::from("two"), 2), (String::from("one"), 1)]);
    }

    #[test]
    fn 빈_입력은_오류다() {
        assert!(top_words("   ", 3).is_err());
    }

    #[test]
    fn n이_0이면_오류다() {
        assert!(top_words("hello world", 0).is_err());
    }
}
