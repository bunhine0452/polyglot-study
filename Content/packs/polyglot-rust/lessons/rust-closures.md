@Concept(id: rust-closures-concept) {
클로저는 이름 없는 함수를 변수에 담아 쓰는 문법이다. `|x| x + 1` 처럼 매개변수를 세로 막대 사이에 적고 뒤에 몸체를 쓴다. 함수와 달리 클로저는 자신을 둘러싼 곳에 있는 변수를 몸체 안에서 그대로 쓸 수 있는데, 이를 **캡처**라 부른다. 방금 예로 든 `x + 1` 은 아무것도 캡처하지 않지만, 클로저 바깥에 있는 `threshold` 같은 변수를 몸체에서 참조하면 클로저가 그 변수를 캡처해 간직한다.

캡처는 기본적으로 필요한 만큼만 빌려 온다 — 클로저가 값을 읽기만 하면 참조로 캡처하므로, 클로저를 다 쓴 뒤에도 바깥 변수는 여전히 쓸 수 있다. 하지만 클로저가 나중에까지 그 값을 갖고 있어야 하는 상황(예: 함수 밖으로 클로저를 들고 나가는 경우)에서는 참조만으로 부족하다. 이때 `move` 키워드를 클로저 앞에 붙이면 캡처한 변수의 소유권을 클로저 안으로 통째로 옮긴다 — 그 뒤로는 바깥에서 그 변수를 쓸 수 없다.

클로저가 특히 자주 등장하는 자리 중 하나가 정렬이다. `Vec` 의 `sort_by_key` 는 각 원소에서 정렬 기준이 될 값(키)을 뽑아내는 클로저를 받는다. 예를 들어 `(이름, 나이)` 튜플의 목록을 나이 순으로 정렬하고 싶다면, `sort_by_key(|p| p.1)` 처럼 튜플에서 나이만 꺼내는 클로저를 넘기면 된다 — 비교 로직 전체를 새로 쓸 필요가 없다.

클로저와 함수의 본질적인 차이는 이 캡처 능력 하나다. 인자를 받고 값을 돌려주는 것은 똑같지만, 클로저만이 정의된 자리의 환경을 몸체 안으로 가져올 수 있다.
}

@Example(id: rust-closures-example, language: rust, expected: expected/rust-closures.txt) {
`add_one` 은 아무것도 캡처하지 않는 단순한 클로저다. `is_big` 은 `threshold` 를 참조로 캡처하는데, 참조라서 이후에도 `threshold` 를 그대로 쓸 수 있다. 마지막은 `sort_by_key` 에 클로저를 넘겨 나이순으로 정렬한다.

```rust
fn main() {
    let add_one = |x: i32| x + 1;
    println!("{}", add_one(4));

    let threshold = 10;
    let is_big = |n: &i32| *n > threshold;
    println!("{}", is_big(&15));
    println!("{}", is_big(&3));
    println!("문턱값은 여전히 {}", threshold);

    let mut people = vec![("철수", 25), ("영희", 19), ("민수", 31)];
    people.sort_by_key(|p| p.1);
    println!("{:?}", people);
}
```
}

@Blank(id: rust-closures-blank, language: rust) {
`name` 의 소유권을 클로저 안으로 옮기는 키워드와, `sort_by_key` 에 넘길 클로저를 채워라.

```rust
fn main() {
    let name = String::from("러스트");
    let greet = ___1___ || println!("안녕, {}", name);
    greet();

    let mut scores = vec![50, 10, 30];
    scores.sort_by_key(___2___);
    println!("{:?}", scores);
}
```

@Answer(slot: 1) {
`move`
}

@Answer(slot: 2) {
`|n| *n`
}
}

@Task(id: rust-closures-task, language: rust, starter: starters/rust-closures.rs, tests: tests/rust-closures.rs, solution: solutions/rust-closures.rs) {
`(이름, 점수)` 쌍의 목록과 개수 `n` 을 받아, 점수가 높은 순으로 상위 `n` 명의 이름만 `Vec<String>` 으로 돌려주는 `top_n_by_score` 를 완성하라. `n` 이 목록 길이보다 크면 있는 만큼만 돌려주고, `n` 이 0 이면 빈 목록을 돌려준다.

@Hint {
`sort_by_key(|p| p.1)` 로 점수 오름차순 정렬을 한 뒤 `reverse()` 를 부르면 내림차순이 된다.
}

@Hint {
`into_iter().take(n)` 으로 앞에서 n 개만 남길 수 있다.
}

@Hint {
`map(|p| p.0)` 으로 튜플에서 이름만 꺼내고 `collect()` 로 `Vec<String>` 을 만들어라.
}
}

@Quiz(id: rust-closures-quiz, answer: captures-environment) {
@Question {
클로저가 함수와 구별되는 가장 본질적인 특징은 무엇인가요?
}

@Choice(id: captures-environment) {
정의된 위치를 둘러싼 변수를 몸체 안에서 그대로 쓸 수 있다(캡처)
}

@Choice(id: same-scope-only) {
자신을 정의한 함수 안에서만 호출할 수 있다
}

@Choice(id: no-arguments) {
함수와 달리 인자를 받을 수 없다
}

@Choice(id: move-required) {
move 를 붙이지 않으면 바깥 변수를 전혀 쓸 수 없다
}

@Explanation {
클로저는 정의된 자리의 변수를 몸체 안에서 참조하면 그 변수를 캡처해 간직한다 — 이것이 함수에는 없는 능력이다. `move` 는 캡처 자체를 가능하게 하는 것이 아니라 캡처 방식을 참조에서 소유권 이전으로 바꾸는 것뿐이다. 클로저는 함수처럼 인자를 받고, 다른 함수에 값처럼 넘겨져 그 함수 안에서 호출될 수도 있다.
}
}

@Reflection(id: rust-closures-reflection) {
@Prompt(id: reference-capture) {
`is_big` 이 `threshold` 를 캡처한 뒤에도 `threshold` 를 계속 쓸 수 있었던 이유를 참조 캡처와 관련지어 설명해 보세요. `move` 를 붙였다면 무엇이 달라졌을까요?
}

@Prompt(id: sort-by-key-alternative) {
`top_n_by_score` 를 점수가 아니라 이름의 가나다순으로 정렬하도록 바꾸려면 `sort_by_key` 에 넘기는 클로저를 어떻게 고쳐야 할지 생각해 보세요.
}
}
