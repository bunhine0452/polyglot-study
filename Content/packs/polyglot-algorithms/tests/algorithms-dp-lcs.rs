#[cfg(test)]
mod learnkit_tests {
    use super::*;

    #[test]
    fn abcdgh_와_aedfhr_의_lcs는_adh다() {
        assert_eq!(longest_common_subsequence("ABCDGH", "AEDFHR"), "ADH");
    }

    #[test]
    fn aggtab_와_gxtxayb_의_lcs는_gtab다() {
        assert_eq!(longest_common_subsequence("AGGTAB", "GXTXAYB"), "GTAB");
    }

    #[test]
    fn 완전히_같은_문자열은_자기_자신이다() {
        assert_eq!(longest_common_subsequence("ABC", "ABC"), "ABC");
    }

    #[test]
    fn 공통_문자가_없으면_빈_문자열이다() {
        assert_eq!(longest_common_subsequence("ABC", "XYZ"), "");
    }

    #[test]
    fn 한쪽이_비어있으면_빈_문자열이다() {
        assert_eq!(longest_common_subsequence("", "ABC"), "");
    }
}
