@Concept(id: rust-testing-concept) {
지금까지는 코드가 맞게 동작하는지 `println!` 으로 값을 찍어서 눈으로 확인했다. 러스트는 이 확인 과정을 언어 차원에서 지원한다. 함수 위에 `#[test]` 를 붙이면 그 함수는 "테스트" 로 표시되고, 테스트 실행기가 이런 함수들을 모아 하나씩 실행한 뒤 통과·실패를 모아 보고한다. 테스트 함수들은 보통 `#[cfg(test)] mod` 블록 안에 모아 두는데, `cfg(test)` 는 "테스트할 때만 이 코드를 포함하라" 는 조건이다 — 그래서 테스트 코드는 평소 프로그램을 빌드할 때는 아예 존재하지 않는 것처럼 빠지고, 테스트로 빌드할 때만 켜진다.

테스트 함수 안에서 값을 확인할 때는 `assert!` 와 `assert_eq!` 를 쓴다. `assert!(조건)` 은 조건이 거짓이면 그 자리에서 프로그램을 멈추고(패닉) 실패를 알린다. `assert_eq!(왼쪽, 오른쪽)` 도 결국 같은 일을 하지만, 단순히 "거짓" 이라고만 말하지 않고 실패했을 때 왼쪽 값과 오른쪽 값을 각각 보여준다 — 그래서 `assert!(결과 == 기대값)` 대신 `assert_eq!(결과, 기대값)` 을 쓰면 무엇이 왜 틀렸는지 훨씬 빨리 알 수 있다.

테스트가 실패하면 실행기는 어떤 테스트 함수가 실패했는지, 그리고 `assert_eq!` 라면 왼쪽(`left`)과 오른쪽(`right`) 에 각각 어떤 값이 들어 있었는지를 함께 보여준다. 이 둘을 나란히 놓고 비교하면 코드가 무엇을 계산했고 무엇을 기대했는지가 바로 드러난다 — 값을 하나하나 `println!` 으로 다시 찍어 보지 않아도 된다.

좋은 테스트는 평범한 입력 하나만 확인하지 않는다. 조건이 갈리는 경계(예: 등급이 나뉘는 정확한 점수) 를 스스로 하나 더 골라 테스트하면, 코드가 `>` 를 써야 할 자리에 실수로 `>=` 를 쓰는 것 같은 실수를 훨씬 잘 잡아낸다.
}

@Example(id: rust-testing-example, language: rust, expected: expected/rust-testing-with-assert.txt) {
`main` 안에서 `assert_eq!` 를 즉석 확인으로 써 본다. 아래의 `#[cfg(test)] mod tests` 는 이렇게 실행할 때는 존재하지 않는 것처럼 빠지고, `rustc --test` 로 빌드할 때만 켜진다.

```rust
fn classify_temperature(celsius: f64) -> &'static str {
    if celsius < 0.0 {
        "얼음"
    } else if celsius < 100.0 {
        "액체"
    } else {
        "기체"
    }
}

fn main() {
    let result = classify_temperature(50.0);
    println!("50도는 {}", result);

    // assert_eq! 는 println! 처럼 아무 곳에서나 쓸 수 있다.
    // 두 값이 다르면 여기서 프로그램이 즉시 멈추고 좌우 값을 보여준다.
    assert_eq!(classify_temperature(-5.0), "얼음");
    assert_eq!(classify_temperature(150.0), "기체");
    println!("모든 확인을 통과했다");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn 액체_구간을_확인한다() {
        assert_eq!(classify_temperature(50.0), "액체");
    }

    #[test]
    fn 경계값_0도는_액체다() {
        assert!(classify_temperature(0.0) == "액체");
    }
}
```
}

@Blank(id: rust-testing-blank, language: rust) {
테스트 모듈을 켜는 속성, 테스트 함수임을 표시하는 속성, 두 값을 비교하는 매크로를 채워라.

```rust
fn double(n: i32) -> i32 {
    n * 2
}

___1___
mod tests {
    use super::*;

    ___2___
    fn 두배를_확인한다() {
        ___3___(double(3), 6);
    }
}

fn main() {
    println!("{}", double(21));
}
```

@Answer(slot: 1) {
`#[cfg(test)]`
}

@Answer(slot: 2) {
`#[test]`
}

@Answer(slot: 3) {
`assert_eq!`
}
}

@Task(id: rust-testing-task, language: rust, starter: starters/rust-testing-with-assert.rs, tests: tests/rust-testing-with-assert.rs, solution: solutions/rust-testing-with-assert.rs) {
점수를 등급으로 바꾸는 `letter_grade` 를 완성하라. 90점 이상은 'A', 80점 이상은 'B', 70점 이상은 'C', 60점 이상은 'D', 그 미만은 'F' 다. 등급이 갈리는 경계 점수들이 어느 쪽에 속하는지 정확히 맞춰야 한다.

@Hint {
점수 구간은 90, 80, 70, 60 순서로 위에서부터 검사하면 편하다.
}

@Hint {
if - else if 사슬로 처음 만족하는 조건의 등급을 그대로 돌려주면 된다.
}

@Hint {
정확히 90점, 80점처럼 경계에 걸친 점수가 어느 등급인지 지시문을 다시 확인하라 — `>=` 와 `>` 중 무엇을 써야 하는지가 여기서 갈린다.
}
}

@Quiz(id: rust-testing-quiz, answer: shows-both-values) {
@Question {
`assert!(a == b)` 대신 `assert_eq!(a, b)` 를 쓰면 실패했을 때 무엇이 다른가요?
}

@Choice(id: shows-both-values) {
실제 값(left)과 기대한 값(right)을 각각 보여줘서 무엇이 왜 틀렸는지 바로 알 수 있다
}

@Choice(id: integers-only) {
assert_eq! 는 정수끼리 비교할 때만 쓸 수 있다
}

@Choice(id: test-fn-only) {
assert! 는 #[test] 함수 안에서만 쓸 수 있다
}

@Choice(id: does-not-stop) {
assert_eq! 는 실패해도 프로그램을 멈추지 않고 계속 진행한다
}

@Explanation {
`assert!(a == b)` 가 실패하면 그냥 "조건이 거짓이었다" 는 것만 알 수 있지만, `assert_eq!(a, b)` 는 실패 시 좌우 값을 각각 보여줘서 코드가 실제로 무엇을 계산했는지 바로 드러난다. `assert_eq!` 는 `Debug` 와 `PartialEq` 를 구현한 어떤 타입에도 쓸 수 있고, `assert!` 도 테스트 함수 밖에서 얼마든지 쓸 수 있으며, 둘 다 조건이 거짓이면 즉시 패닉으로 멈춘다.
}
}

@Reflection(id: rust-testing-reflection) {
@Prompt(id: reading-left-right) {
`assert_eq!` 가 실패했을 때 나오는 left·right 값을 어떻게 읽으면 되는지, 그것이 `assert!` 만 썼을 때보다 왜 디버깅에 유리한지 적어 보세요.
}

@Prompt(id: one-more-boundary) {
`letter_grade` 에 경계값 테스트를 스스로 하나 더 추가한다면 몇 점을 고를지, 그 점수가 왜 위험한 경계인지 생각해 보세요.
}
}
