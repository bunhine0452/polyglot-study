pub fn top_n_by_score(mut people: Vec<(String, i32)>, n: usize) -> Vec<String> {
    people.sort_by_key(|p| p.1);
    people.reverse();
    people.into_iter().take(n).map(|p| p.0).collect()
}
