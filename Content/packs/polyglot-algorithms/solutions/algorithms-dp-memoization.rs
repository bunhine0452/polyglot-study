use std::collections::HashMap;

pub fn binomial(n: u64, k: u64) -> u64 {
    let mut cache = HashMap::new();
    binomial_memo(n, k, &mut cache)
}

fn binomial_memo(n: u64, k: u64, cache: &mut HashMap<(u64, u64), u64>) -> u64 {
    if k == 0 || k == n {
        return 1;
    }
    if let Some(&v) = cache.get(&(n, k)) {
        return v;
    }
    let result = binomial_memo(n - 1, k - 1, cache) + binomial_memo(n - 1, k, cache);
    cache.insert((n, k), result);
    result
}
