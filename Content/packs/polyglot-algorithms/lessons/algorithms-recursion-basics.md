@Concept(id: recursion-basics-concept) {
재귀 함수는 자기 자신을 다시 부르는 함수다. 무한히 부르기만 하면 끝나지 않으니, 반드시 두 부분이 있어야 한다. **베이스 케이스**는 더 이상 자신을 부르지 않고 바로 답을 내는 가장 작은 경우다. **재귀 케이스**는 문제를 더 작은 같은 모양의 문제로 줄여서 자신을 다시 부르고, 그 결과를 이용해 지금 문제의 답을 만든다.

함수를 호출하면 그 호출은 콜 스택에 새 프레임으로 쌓인다. `sum_to(4)` 가 `sum_to(3)` 을 부르면 `sum_to(4)` 는 그 결과를 기다리며 스택에 남아 있고, `sum_to(3)` 이 다시 `sum_to(2)` 를 부르며 스택이 계속 쌓인다. 이 쌓임은 베이스 케이스(`sum_to(0)`)에 닿아야 멈춘다. 베이스 케이스가 값을 반환하면 그제서야 스택이 하나씩 풀리기 시작한다 — 가장 나중에 쌓인 호출부터 거꾸로 반환값을 돌려주며 원래 호출까지 거슬러 올라온다.

베이스 케이스가 빠지면 이 쌓임이 멈추지 않는다. 콜 스택의 크기는 고정돼 있어서, 반환 없이 호출만 계속 쌓이면 결국 공간이 바닥나 프로그램이 '스택 오버플로우'로 강제 종료된다. 재귀 함수를 짤 때 베이스 케이스부터 정하는 것이 그래서 중요하다.

@Visualize(id: recursion-basics, frames: visuals/recursion-basics.json) {
재귀가 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: recursion-basics-example, language: rust, expected: expected/algorithms-recursion-basics.txt) {
sum_to(4) 가 호출을 얼마나 쌓았다가 어떤 순서로 풀리는지, 들여쓰기로 깊이를 표시해 찍어 본다.

```rust
fn sum_to(n: u32, depth: usize) -> u32 {
    println!("{}sum_to({}) 호출", "  ".repeat(depth), n);
    if n == 0 {
        println!("{}베이스 케이스: 0", "  ".repeat(depth));
        return 0;
    }
    let rest = sum_to(n - 1, depth + 1);
    let result = n + rest;
    println!("{}sum_to({}) 반환: {}", "  ".repeat(depth), n, result);
    result
}

fn main() {
    let total = sum_to(4, 0);
    println!("합계: {}", total);
}
```
}

@Blank(id: recursion-basics-blank, language: rust) {
factorial(n) 이 더 이상 자신을 부르지 않고 바로 답을 내야 하는 가장 작은 경우는 n이 무엇일 때일까?

```rust
fn factorial(n: u64) -> u64 {
    if ___1___ {
        return 1;
    }
    n * factorial(n - 1)
}

fn main() {
    println!("{}", factorial(5));
}
```

@Answer(slot: 1) {
`n == 0`
}
}

@Task(id: recursion-basics-task, language: rust, starter: starters/algorithms-recursion-basics.rs, tests: tests/algorithms-recursion-basics.rs, solution: solutions/algorithms-recursion-basics.rs) {
`base` 의 `exp` 제곱을 재귀로 계산해 돌려주세요. 반복문(for, while) 없이 베이스 케이스와 재귀 케이스만으로 구현해야 합니다.

@Hint {
exp가 0일 때 결과가 무엇인지부터 정해라 — 그것이 베이스 케이스다.
}

@Hint {
power(base, exp) 는 base 를 exp번 곱한 것이다. power(base, exp - 1) 에 base 를 한 번 더 곱하면 된다.
}

@Hint {
재귀 케이스에서 exp를 그대로 넘기면 절대 0에 도달하지 못한다 — exp - 1 을 넘겨야 한다.
}
}

@Quiz(id: recursion-basics-quiz, answer: stack-overflow) {
@Question {
다음 함수에는 베이스 케이스가 없다: `fn factorial(n: i32) -> i32 { n * factorial(n - 1) }`. factorial(5) 를 호출하면 어떤 일이 일어날까?
}

@Choice(id: correct-result) {
5! = 120 을 계산하고 정상 종료한다
}

@Choice(id: stack-overflow) {
n이 음수로 끝없이 줄어들며 호출이 계속 쌓이다가 결국 스택 오버플로우로 크래시한다
}

@Choice(id: auto-stop) {
n이 0이 되는 순간 자동으로 멈춘다
}

@Explanation {
n == 0 을 확인하는 베이스 케이스가 없으므로 n은 0을 그냥 지나쳐 음수로 계속 줄어든다. 반환 없이 호출만 계속 쌓이므로 콜 스택이 결국 넘친다.
}
}

@Reflection(id: recursion-basics-reflection) {
@Prompt(id: base-case-first) {
재귀 함수를 짤 때 베이스 케이스를 가장 먼저 정하는 것이 왜 안전한 습관인지 적어 보세요.
}

@Prompt(id: trace-stack) {
sum_to(4) 호출을 손으로 그려보고(누가 누구를 부르는지), 어느 시점부터 호출이 쌓이기를 멈추고 반환값이 거슬러 올라오기 시작하는지 표시해 보세요.
}
}
