@Concept(id: rust-option-concept) {
많은 언어에는 "값이 없음" 을 나타내는 null 이 있고, null 인 걸 깜빡하고 다루다 프로그램이 터지는 일이 흔하다. 러스트에는 null 자체가 없다. 대신 값이 있을 수도 없을 수도 있는 상황을 `Option<T>` 라는 enum 하나로 표현한다 — 값이 있으면 `Some(값)`, 없으면 `None` 이다.

`Option<T>` 도 결국 enum 이므로 지난 레슨의 `match` 를 그대로 쓸 수 있다. 다만 관심 있는 경우가 `Some` 하나뿐이고 `None` 일 때는 별다른 처리 없이 넘어가도 될 때는 `if let Some(값) = 식 { ... }` 이 더 짧다. `if let` 은 "이 패턴에 맞으면 이 블록을 실행하고, 아니면 그냥 넘어간다" 는 뜻이다 — match 처럼 모든 경우를 다룰 필요가 없는 대신, None 쪽에서 뭔가 해야 한다면 `if let` 만으로는 부족하다.

`Option<T>` 를 반환하는 함수를 쓰면 호출하는 쪽은 컴파일러 때문에라도 "값이 없을 수도 있다" 는 사실을 무시할 수 없다. `i32` 를 그냥 반환했다면 호출자는 항상 값이 있다고 가정하고 코드를 짜겠지만, `Option<i32>` 를 반환하면 그 값을 실제로 쓰기 전에 반드시 `Some` 인지 `None` 인지 갈라야 한다 — 이 검사를 실행 전에 강제하는 것이 `Option` 의 핵심이다.

값이 없을 때 쓸 기본값이 이미 정해져 있다면 `unwrap_or(기본값)` 이 더 간단하다. `Some(x)` 면 x 를, `None` 이면 괄호 안의 기본값을 그대로 돌려준다. 다만 `unwrap()` 처럼 이름이 비슷한 다른 메서드는 `None` 일 때 프로그램을 그 자리에서 멈춰버린다는 점에서 전혀 다르다 — 이 트랙에서는 `unwrap()` 보다 `match`·`if let`·`unwrap_or` 처럼 None 을 명시적으로 다루는 쪽을 쓴다.
}

@Example(id: rust-option-example, language: rust, expected: expected/rust-option.txt) {
같은 Option<i32> 값을 match, if let, unwrap_or 세 가지 방식으로 각각 다뤄 본다.

```rust
fn find_first_even(numbers: &Vec<i32>) -> Option<i32> {
    for &n in numbers {
        if n % 2 == 0 {
            return Some(n);
        }
    }
    None
}

fn main() {
    let numbers = vec![1, 3, 4, 7];
    match find_first_even(&numbers) {
        Some(value) => println!("첫 짝수: {}", value),
        None => println!("짝수가 없습니다"),
    }

    let odds = vec![1, 3, 5];
    if let Some(value) = find_first_even(&odds) {
        println!("첫 짝수: {}", value);
    } else {
        println!("짝수가 없습니다");
    }

    let result = find_first_even(&odds).unwrap_or(-1);
    println!("기본값 포함: {}", result);
}
```
}

@Blank(id: rust-option-blank, language: rust) {
짝수면 절반을 Some 으로, 아니면 None 을 돌려주도록 채워 완성하자.

```rust
fn half_if_even(n: i32) -> Option<i32> {
    if n % 2 == 0 {
        ___1___(n / 2)
    } else {
        ___2___
    }
}

fn main() {
    if let Some(value) = half_if_even(10) {
        println!("절반: {}", value);
    }
}
```

@Answer(slot: 1) {
`Some`
}

@Answer(slot: 2) {
`None`
}
}

@Task(id: rust-option-task, language: rust, starter: starters/rust-option.rs, tests: tests/rust-option.rs, solution: solutions/rust-option.rs) {
정수 벡터 `values` 에서 `target` 과 같은 첫 원소의 인덱스를 찾는 함수 `find_index` 를 완성하라. 찾으면 그 인덱스를 `Some` 으로 감싸 돌려주고, 없거나 벡터가 비어 있으면 `None` 을 돌려준다. 같은 값이 여러 번 나오면 가장 먼저 나온 인덱스를 돌려준다.

@Hint {
0..values.len() 범위로 인덱스를 돌며 values[index] 를 target 과 비교하라.
}

@Hint {
일치하는 순간 return Some(index) 로 즉시 함수를 끝내라 — 그래야 '첫 번째' 일치가 보장된다.
}

@Hint {
루프가 끝날 때까지 못 찾았다면 함수 마지막에서 None 을 돌려준다.
}
}

@Quiz(id: rust-option-quiz, answer: default) {
@Question {
`find_first_even(&odds).unwrap_or(-1)` 에서 `find_first_even` 이 `None` 을 돌려줬다면 이 식의 값은 무엇인가?
}

@Choice(id: default) {
-1 — unwrap_or 에 적어 둔 기본값이 그대로 쓰인다
}

@Choice(id: panic) {
None 이므로 프로그램이 패닉을 일으키며 즉시 중단된다
}

@Choice(id: none-value) {
None 이라는 값 자체가 그대로 result 에 담긴다
}

@Choice(id: zero) {
항상 0 이 기본값으로 쓰인다
}

@Explanation {
unwrap_or(기본값) 은 Some(x) 면 x 를, None 이면 괄호 안에 적은 기본값을 돌려준다 — 여기서는 -1 이다. 패닉을 일으키는 것은 unwrap() 이지 unwrap_or 가 아니다. 그리고 result 의 타입은 Option<i32> 가 아니라 i32 이므로 None 이라는 값이 그대로 담길 수도 없고, 기본값은 0 이 아니라 우리가 직접 적어 준 -1 이다.
}
}

@Reflection(id: rust-option-reflection) {
@Prompt(id: no-null) {
null 이 있는 언어에서는 '이 값이 null 일 수도 있다' 는 사실이 문서나 팀의 관례로만 전해지는 경우가 많습니다. Option<T> 를 쓰면 이 정보가 어디에 어떻게 남는지, 그것이 왜 더 안전한지 적어 보세요.
}

@Prompt(id: match-vs-iflet) {
이번 예제에서 match 와 if let 은 결과적으로 같은 일을 했습니다. None 일 때 아무것도 하지 않아도 될 때와, None 일 때도 뭔가 다른 동작이 필요할 때 중 어느 쪽에 어느 문법이 더 어울릴지 생각해 보세요.
}
}
