pub fn build_pair(word: String) -> String {
    let backup = word.clone();
    let mut combined = word;
    combined.push_str("!");
    format!("{} / {}", combined, backup)
}
