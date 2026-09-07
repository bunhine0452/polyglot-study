use std::collections::HashMap;

pub fn word_counts(words: &Vec<&str>) -> Vec<(String, i32)> {
    let mut counts: HashMap<&str, i32> = HashMap::new();
    for &word in words {
        let count = counts.entry(word).or_insert(0);
        *count += 1;
    }

    let mut result: Vec<(String, i32)> = Vec::new();
    for (word, count) in &counts {
        result.push((word.to_string(), *count));
    }
    result.sort();
    result
}
