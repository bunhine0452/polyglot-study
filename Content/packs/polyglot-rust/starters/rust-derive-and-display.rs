pub struct Money {
    pub cents: i64,
}

impl std::fmt::Display for Money {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        // self.cents 를 100 으로 나눈 몫이 달러, 나머지가 센트다.
        // 센트가 한 자리면 앞에 0 을 채워 두 자리로 맞춰라 ({:02} 형식 지정자를 참고하라).
        unimplemented!("여기를 구현해라")
    }
}
