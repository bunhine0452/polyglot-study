pub fn codename(word: &str) -> String {
    let prefix = &word[0..3];
    let mut result = String::from(prefix);
    result.push_str("-01");
    result
}
