use std::collections::HashMap;

pub fn binomial(n: u64, k: u64) -> u64 {
    // 캐시를 만들고, k == 0 이거나 k == n 이면 1이라는 베이스 케이스부터 처리해라.
    // 점화식은 C(n, k) = C(n-1, k-1) + C(n-1, k) 다.
    unimplemented!("여기를 구현해라")
}
