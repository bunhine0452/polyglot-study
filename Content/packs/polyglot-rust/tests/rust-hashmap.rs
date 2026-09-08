#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn 등장_횟수를_센다() {
        let words = vec!["사과", "바나나", "사과"];
        assert_eq!(
            word_counts(&words),
            vec![
                (String::from("바나나"), 1),
                (String::from("사과"), 2),
            ]
        );
    }

    #[test]
    fn 사전순으로_정렬된다() {
        let words = vec!["포도", "가지", "감자"];
        assert_eq!(
            word_counts(&words),
            vec![
                (String::from("가지"), 1),
                (String::from("감자"), 1),
                (String::from("포도"), 1),
            ]
        );
    }

    #[test]
    fn 빈_목록은_빈_벡터다() {
        let words: Vec<&str> = vec![];
        assert_eq!(word_counts(&words), Vec::new());
    }

    #[test]
    fn 모두_같은_단어면_하나만_남는다() {
        let words = vec!["사과", "사과", "사과"];
        assert_eq!(word_counts(&words), vec![(String::from("사과"), 3)]);
    }
}
