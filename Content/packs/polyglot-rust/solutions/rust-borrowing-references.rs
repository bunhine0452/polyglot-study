pub fn pad_with_stars(s: &mut String, count: i32) {
    let mut i = 0;
    while i < count {
        s.push_str("*");
        i = i + 1;
    }
}
