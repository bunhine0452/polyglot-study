pub struct Money {
    pub cents: i64,
}

impl std::fmt::Display for Money {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "${}.{:02}", self.cents / 100, self.cents % 100)
    }
}
