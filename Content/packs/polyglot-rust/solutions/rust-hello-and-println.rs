pub fn greeting(name: &str) -> String {
    if name.is_empty() {
        return String::from("안녕하세요, 이름 없음!");
    }
    format!("안녕하세요, {}!", name)
}
