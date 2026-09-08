@Concept(id: rust-slices-concept) {
지금까지 벡터를 넘길 때는 `&Vec<i32>` 처럼 참조를 썼다. 그런데 이렇게 쓰면 그 함수는 딱 `Vec<i32>` 만 받을 수 있고, 배열이나 벡터의 일부 구간은 넘길 수 없다. 실제로는 값의 소유자가 무엇이든 상관없이 "연속된 값들을 잠깐 빌려 본다" 는 것만 중요한 경우가 많다 — 이때 쓰는 타입이 슬라이스 `&[T]` 다.

`&[T]` 는 시작 위치와 길이만 가진 얇은 참조라서, `Vec<T>` 든 배열 `[T; N]` 이든 그 일부 구간이든 모두 가리킬 수 있다. `Vec<T>` 참조가 필요한 자리에 `&[T]` 를 요구하는 함수를 넘겨도 컴파일러가 알아서 `&Vec<T>` 를 `&[T]` 로 바꿔 주는데, 이를 **deref 강제**라 부른다. `String` 과 `&str` 사이에도 같은 일이 일어난다 — `&str` 을 받는 함수에 `&String` 을 넘기면 자동으로 `&str` 로 바뀐다. 그래서 `&str` 을 받는 함수가 리터럴과 `String` 을 모두 받아들이는 것이다.

이 관계 때문에 함수 시그니처를 쓸 때는 소유 타입(`Vec<T>`, `String`)보다 빌린 타입(`&[T]`, `&str`)을 매개변수로 두는 쪽이 더 널리 쓰인다. 함수는 값을 읽기만 하면 되는데 굳이 `&Vec<T>` 를 요구하면, 호출하는 쪽이 배열이나 부분 구간만 가지고 있을 때 불필요하게 새 벡터를 만들어야 한다.

부분 슬라이스는 `v[1..3]` 처럼 범위 문법으로 얻는다. 앞에 `&` 를 붙이면 그 구간만 가리키는 `&[T]` 가 되고, 원본 벡터는 여전히 그대로 있다 — 복사가 아니라 빌림이기 때문이다.
}

@Example(id: rust-slices-example, language: rust, expected: expected/rust-slices-and-borrowed-params.txt) {
`sum` 은 `&[i32]` 를 받아 벡터·배열·부분 슬라이스를 모두 받아들인다. `shout` 은 `&str` 을 받아 `String` 값과 문자열 리터럴을 모두 받아들인다.

```rust
fn sum(nums: &[i32]) -> i32 {
    let mut total = 0;
    for n in nums {
        total += n;
    }
    total
}

fn shout(s: &str) -> String {
    let mut result = s.to_uppercase();
    result.push('!');
    result
}

fn main() {
    let v = vec![1, 2, 3, 4, 5];
    let arr = [10, 20, 30];

    println!("벡터 합: {}", sum(&v));
    println!("배열 합: {}", sum(&arr));
    println!("부분 슬라이스 합: {}", sum(&v[1..3]));

    let owned = String::from("rust");
    println!("{}", shout(&owned));
    println!("{}", shout("hello"));
}
```
}

@Blank(id: rust-slices-blank, language: rust) {
`&[i32]` 를 받는 함수 시그니처와, 벡터 전체·앞쪽 부분 슬라이스를 넘기는 호출을 채워라.

```rust
fn largest(nums: ___1___) -> i32 {
    let mut max = nums[0];
    for &n in nums {
        if n > max {
            max = n;
        }
    }
    max
}

fn main() {
    let v = vec![3, 7, 2, 9, 4];
    println!("{}", largest(___2___));
    println!("{}", largest(___3___));
}
```

@Answer(slot: 1) {
`&[i32]`
}

@Answer(slot: 2) {
`&v`
}

@Answer(slot: 3) {
`&v[..2]`
}
}

@Task(id: rust-slices-task, language: rust, starter: starters/rust-slices-and-borrowed-params.rs, tests: tests/rust-slices-and-borrowed-params.rs, solution: solutions/rust-slices-and-borrowed-params.rs) {
슬라이스 `&[i32]` 를 받아 평균을 `f64` 로 돌려주는 함수 `average` 를 완성하라. 슬라이스가 비어 있으면 `0.0` 을 돌려준다. 이 함수는 벡터 전체·배열·부분 슬라이스를 모두 받을 수 있어야 한다.

@Hint {
`nums.is_empty()` 로 빈 슬라이스를 가장 먼저 검사하라.
}

@Hint {
`nums.iter().sum::<i32>()` 로 합을 구할 수 있다.
}

@Hint {
정수 나눗셈이 되지 않도록 나누기 전에 분자와 분모를 모두 `as f64` 로 바꿔라.
}
}

@Quiz(id: rust-slices-quiz, answer: wider-callers) {
@Question {
함수 매개변수를 `&Vec<i32>` 대신 `&[i32]` 로 쓰면 얻는 가장 큰 이점은 무엇인가요?
}

@Choice(id: wider-callers) {
벡터뿐 아니라 배열과 부분 슬라이스를 넘기는 호출자도 받아들일 수 있다
}

@Choice(id: less-memory) {
런타임에 항상 더 적은 메모리를 사용한다
}

@Choice(id: auto-mut) {
참조가 자동으로 가변 참조가 된다
}

@Choice(id: faster-compile) {
컴파일 시간이 항상 더 짧아진다
}

@Explanation {
`&[i32]` 는 시작 위치와 길이만 가진 얇은 참조라서 `Vec<i32>`, 배열, 그리고 그 일부 구간까지 모두 가리킬 수 있다. 그래서 `&[i32]` 를 받는 함수는 `&Vec<i32>` 를 받는 함수보다 더 많은 호출자를 받아들인다. 메모리 사용량이나 컴파일 시간과는 관계가 없고, 가변성은 `&mut` 를 따로 붙여야 생긴다.
}
}

@Reflection(id: rust-slices-reflection) {
@Prompt(id: wider-callers-reflection) {
직접 만든 함수 하나를 떠올려 `&Vec<T>` 매개변수를 `&[T]` 로 바꾼다면 어떤 새로운 호출자가 가능해질지 적어 보세요.
}

@Prompt(id: deref-coercion-reflection) {
`&str` 을 받는 함수에 `String` 값을 그대로 넘길 수 있었던 이유를 이번 레슨에서 배운 대로 설명해 보세요.
}
}
