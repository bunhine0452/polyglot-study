@Concept(id: dp-memoization-concept) {
재귀로 피보나치를 구하면 `fib(n) = fib(n-1) + fib(n-2)` 라는 점화식을 그대로 코드로 옮길 수 있다. 문제는 같은 입력이 여러 번 계산된다는 것이다 — `fib(5)` 는 `fib(3)` 을 두 번, `fib(30)` 은 작은 값들을 수백만 번 다시 계산하게 된다. 호출 트리를 그려보면 아래로 갈수록 같은 노드가 기하급수적으로 겹친다.

이걸 막는 방법은 간단하다. 함수에 들어가자마자 "이 입력, 이미 계산한 적 있나?" 를 캐시(맵이나 배열)에서 찾아본다. 있으면 그 값을 바로 돌려주고, 없으면 평소처럼 재귀로 계산한 뒤 **결과를 캐시에 저장하고 나서** 돌려준다. 이렇게 캐시를 곁들인 재귀를 **메모이제이션(memoization)** 이라 부른다.

메모이제이션은 여전히 위(큰 문제)에서 아래(작은 부분 문제)로 내려가는 방식이라 **하향식(top-down)** 이다. 재귀 구조는 그대로 두고 캐시만 끼워 넣는다는 점이 다음 편의 타뷸레이션과 다른 점이다.

캐시 덕분에 각 입력값은 딱 한 번만 실제로 계산된다. `fib(n)` 을 계산하는 서로 다른 입력은 `0` 부터 `n` 까지 `n + 1` 가지뿐이므로, 호출 횟수가 지수(대략 `2^n`)에서 선형(`O(n)`)으로 떨어진다.
}

@Example(id: dp-memoization-example, language: rust, expected: expected/algorithms-dp-memoization.txt) {
같은 `fib(n)` 을 순수 재귀와 메모이제이션 두 방식으로 계산하면서 함수가 실제로 몇 번 호출되는지 세어 본다.

```rust
use std::collections::HashMap;

fn fib_naive(n: u64, calls: &mut u32) -> u64 {
    *calls += 1;
    if n < 2 {
        return n;
    }
    fib_naive(n - 1, calls) + fib_naive(n - 2, calls)
}

fn fib_memo(n: u64, cache: &mut HashMap<u64, u64>, calls: &mut u32) -> u64 {
    *calls += 1;
    if n < 2 {
        return n;
    }
    if let Some(&v) = cache.get(&n) {
        return v;
    }
    let result = fib_memo(n - 1, cache, calls) + fib_memo(n - 2, cache, calls);
    cache.insert(n, result);
    result
}

fn main() {
    for n in [10u64, 20, 30] {
        let mut naive_calls = 0;
        let naive_result = fib_naive(n, &mut naive_calls);

        let mut cache = HashMap::new();
        let mut memo_calls = 0;
        let memo_result = fib_memo(n, &mut cache, &mut memo_calls);

        println!(
            "fib({}) = {} | 순수 재귀 호출 {}번, 메모이제이션 호출 {}번",
            n, naive_result, naive_calls, memo_calls
        );
        assert_eq!(naive_result, memo_result);
    }
}
```
}

@Blank(id: dp-memoization-blank, language: rust) {
결과를 계산한 뒤, 나중에 같은 n이 다시 들어왔을 때 재계산하지 않으려면 무엇을 해야 할까?

```rust
use std::collections::HashMap;

fn fib_memo(n: u64, cache: &mut HashMap<u64, u64>) -> u64 {
    if n < 2 {
        return n;
    }
    if let Some(&v) = cache.get(&n) {
        return v;
    }
    let result = fib_memo(n - 1, cache) + fib_memo(n - 2, cache);
    ___1___;
    result
}

fn main() {
    let mut cache = HashMap::new();
    println!("{}", fib_memo(15, &mut cache));
}
```

@Answer(slot: 1) {
`cache.insert(n, result)`
}
}

@Task(id: dp-memoization-task, language: rust, starter: starters/algorithms-dp-memoization.rs, tests: tests/algorithms-dp-memoization.rs, solution: solutions/algorithms-dp-memoization.rs) {
이항계수 `C(n, k)` (서로 다른 n개 중 k개를 고르는 경우의 수)를 재귀 점화식 `C(n, k) = C(n-1, k-1) + C(n-1, k)` 로 계산하세요. 베이스 케이스는 `k == 0` 이거나 `k == n` 일 때 `1` 입니다. 캐시를 써서 같은 `(n, k)` 쌍을 두 번 계산하지 않아야 합니다.

@Hint {
베이스 케이스(`k == 0` 또는 `k == n`)는 캐시를 보기도 전에 먼저 처리해라 — 캐시에 없는 값이니까.
}

@Hint {
캐시의 키는 `n` 하나가 아니라 `(n, k)` 쌍이다. `HashMap<(u64, u64), u64>` 같은 타입을 생각해봐라.
}

@Hint {
재귀 호출 두 개(`C(n-1, k-1)` 과 `C(n-1, k)`)의 결과를 더한 뒤에 캐시에 저장하고, 그다음에 반환해라.
}
}

@Quiz(id: dp-memoization-quiz, answer: cache-reuse) {
@Question {
메모이제이션이 순수 재귀보다 빠른 이유는 근본적으로 무엇 때문일까?
}

@Choice(id: cache-reuse) {
같은 입력에 대한 계산 결과를 캐시에서 재사용해 중복 계산을 없애기 때문이다
}

@Choice(id: loop-instead) {
재귀 대신 반복문을 쓰기 때문이다
}

@Choice(id: cheaper-calls) {
함수 호출 자체의 비용이 캐시 덕분에 줄어들기 때문이다
}

@Explanation {
메모이제이션은 재귀 구조 자체는 그대로 둔다 — 여전히 함수가 자신을 호출한다. 달라지는 것은 같은 입력이 다시 들어왔을 때 계산을 반복하지 않고 캐시에 저장된 값을 바로 돌려준다는 점이다. 그래서 서로 다른 입력의 가짓수만큼만 실제 계산이 일어난다.
}
}

@Reflection(id: dp-memoization-reflection) {
@Prompt(id: array-cache) {
캐시를 `HashMap` 대신 배열로 만들면 어떤 경우에 더 빠르고, 어떤 경우에 오히려 불편할지 생각해 보세요.
}

@Prompt(id: stack-depth) {
재귀 깊이가 아주 깊어지면(예: n이 수백만) 메모이제이션도 스택 오버플로우를 피하지 못합니다. 이 문제를 다음 편의 타뷸레이션이 어떻게 해결할지 미리 짐작해 보세요.
}
}
