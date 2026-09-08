use std::collections::HashMap;

pub fn top_words(text: &str, n: usize) -> Result<Vec<(String, i32)>, String> {
    // 1) text.trim() 이 비어 있으면 Err 를 돌려준다.
    // 2) n 이 0 이면 Err 를 돌려준다.
    // 3) split_whitespace 로 단어를 나누고 HashMap 의 entry().or_insert(0) 로 빈도를 센다.
    // 4) Vec 으로 옮겨 빈도 내림차순, 동점이면 단어 오름차순으로 정렬한다.
    // 5) truncate(n) 으로 앞의 n 개만 남기고 Ok 로 감싸 돌려준다.
    unimplemented!("여기를 구현해라")
}
