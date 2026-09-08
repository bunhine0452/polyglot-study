use std::collections::HashMap;

pub fn top_words(text: &str, n: usize) -> Result<Vec<(String, i32)>, String> {
    if text.trim().is_empty() {
        return Err(String::from("입력이 비어 있습니다"));
    }
    if n == 0 {
        return Err(String::from("n은 1 이상이어야 합니다"));
    }

    let mut counts: HashMap<String, i32> = HashMap::new();
    for word in text.split_whitespace() {
        *counts.entry(word.to_string()).or_insert(0) += 1;
    }

    let mut pairs: Vec<(String, i32)> = counts.into_iter().collect();
    pairs.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    pairs.truncate(n);
    Ok(pairs)
}
