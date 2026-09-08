#[cfg(test)]
mod learnkit_tests {
    use super::*;

    fn sample() -> Vec<(String, i32)> {
        vec![
            (String::from("철수"), 80),
            (String::from("영희"), 95),
            (String::from("민수"), 60),
        ]
    }

    #[test]
    fn 점수_내림차순으로_상위_두명을_고른다() {
        assert_eq!(top_n_by_score(sample(), 2), vec!["영희", "철수"]);
    }

    #[test]
    fn n이_0이면_빈_목록이다() {
        assert_eq!(top_n_by_score(sample(), 0), Vec::<String>::new());
    }

    #[test]
    fn n이_전체보다_크면_전부_돌려준다() {
        assert_eq!(top_n_by_score(sample(), 10), vec!["영희", "철수", "민수"]);
    }

    #[test]
    fn 한_명뿐이어도_동작한다() {
        let one = vec![(String::from("단독"), 50)];
        assert_eq!(top_n_by_score(one, 1), vec!["단독"]);
    }
}
