@Concept(id: rust-hashmap-concept) {
벡터는 인덱스 0, 1, 2 처럼 위치로 값을 찾는다. 이름이나 단어처럼 임의의 값을 이름표 삼아 찾고 싶다면 `HashMap<K, V>` 를 쓴다. 키(key) 하나에 값(value) 하나가 짝지어지고, `insert` 로 짝을 넣고 `get` 으로 키에 해당하는 값을 꺼낸다. `get` 은 그 키가 없을 수도 있으므로 값 자체가 아니라 `Option<&V>` 를 돌려준다 — 지난 레슨에서 배운 Option 이 여기서도 그대로 쓰인다.

같은 키로 값을 여러 번 셀 때는 `entry` API 가 유용하다. `map.entry(key).or_insert(0)` 은 "이 키가 이미 있으면 그 값을 가리키는 가변 참조를 주고, 없으면 0 을 넣은 뒤 그 값을 가리키는 참조를 준다" 는 뜻이다. 그 참조에 `*count += 1` 처럼 더하면, 있던 키는 값이 늘고 없던 키는 0에서 시작해 1이 된다 — 키가 있는지 미리 확인하는 if 문이 필요 없어진다.

여기서 반드시 주의할 함정이 하나 있다. `HashMap` 은 키를 해시값 순서로 저장하지, 넣은 순서나 정렬된 순서로 저장하지 않는다. 그래서 `for (k, v) in &map` 으로 그냥 순회하면 **실행할 때마다 순서가 달라질 수 있다**. 화면에 찍거나 다른 값과 비교할 때 이 순서에 기대면 코드는 어떤 날은 맞고 어떤 날은 틀리는, 재현하기 어려운 버그가 된다.

그래서 출력 순서가 중요한 상황이라면 `HashMap` 을 직접 순회해 찍지 않고, 먼저 `Vec` 으로 옮겨 담은 뒤 `sort` 로 정렬하고 나서 찍는다. 해시맵은 "빠르게 찾기" 를 위한 자료구조이고 "순서를 기억하기" 위한 자료구조가 아니라는 점을 받아들이면, 순서가 필요할 때 정렬을 한 단계 끼워 넣는 습관이 자연스러워진다.
}

@Example(id: rust-hashmap-example, language: rust, expected: expected/rust-hashmap.txt) {
이름과 나이를 저장하고 get으로 찾아본 뒤, 단어 등장 횟수를 entry로 센 다음 Vec으로 옮겨 정렬해서 찍는다.

```rust
use std::collections::HashMap;

fn main() {
    let mut ages: HashMap<String, i32> = HashMap::new();
    ages.insert(String::from("눈송"), 3);
    ages.insert(String::from("바람"), 5);

    match ages.get("눈송") {
        Some(age) => println!("눈송의 나이: {}", age),
        None => println!("눈송을 찾을 수 없습니다"),
    }

    let words = vec!["사과", "바나나", "사과", "포도", "바나나", "사과"];
    let mut counts: HashMap<&str, i32> = HashMap::new();
    for &word in &words {
        let count = counts.entry(word).or_insert(0);
        *count += 1;
    }

    let mut pairs: Vec<(&&str, &i32)> = counts.iter().collect();
    pairs.sort();
    for (word, count) in pairs {
        println!("{}: {}", word, count);
    }
}
```
}

@Blank(id: rust-hashmap-blank, language: rust) {
entry 와 or_insert 를 채워, 키가 없으면 0에서 시작해 값을 더하도록 완성하자.

```rust
use std::collections::HashMap;

fn main() {
    let mut scores: HashMap<&str, i32> = HashMap::new();
    let entry = scores.___1___("눈송").___2___(0);
    *entry += 10;
    println!("{}", scores["눈송"]);
}
```

@Answer(slot: 1) {
`entry`
}

@Answer(slot: 2) {
`or_insert`
}
}

@Task(id: rust-hashmap-task, language: rust, starter: starters/rust-hashmap.rs, tests: tests/rust-hashmap.rs, solution: solutions/rust-hashmap.rs) {
문자열 슬라이스 벡터 `words` 를 받아, 각 단어가 몇 번 나오는지 `(단어, 횟수)` 쌍의 벡터로 돌려주는 함수 `word_counts` 를 완성하라. `HashMap` 의 `entry` API 로 횟수를 센 뒤, 결과는 **단어의 사전순으로 정렬**해서 돌려줘야 한다 — HashMap 을 그냥 순회하면 순서가 실행마다 달라지기 때문이다. `words` 가 비어 있으면 빈 벡터를 돌려준다.

@Hint {
먼저 HashMap<&str, i32> 를 만들고 entry(word).or_insert(0) 뒤 *count += 1 로 등장 횟수를 센다.
}

@Hint {
HashMap 을 다 센 뒤에는 for (word, count) in &counts 로 Vec<(String, i32)> 에 옮겨 담아라 — word.to_string() 으로 String 을 만들 수 있다.
}

@Hint {
옮겨 담은 벡터를 result.sort() 로 정렬한 뒤에 돌려줘야 순서가 항상 같다.
}
}

@Quiz(id: rust-hashmap-quiz, answer: order-varies) {
@Question {
`for (key, value) in &map` 으로 HashMap 을 순회해 그대로 println! 으로 찍으면 어떤 문제가 생길 수 있는가?
}

@Choice(id: order-varies) {
실행할 때마다 키가 출력되는 순서가 달라질 수 있다
}

@Choice(id: compile-fail) {
HashMap 은 for 로 순회할 수 없어 컴파일이 안 된다
}

@Choice(id: missing-keys) {
insert 한 키 중 일부가 무작위로 누락되어 출력된다
}

@Choice(id: always-sorted) {
항상 키를 넣은 순서대로 출력되어 문제가 없다
}

@Explanation {
HashMap 은 키를 해시값에 따라 저장하므로 순회 순서가 삽입 순서와도, 정렬 순서와도 다르며 실행마다 달라질 수 있다. 순회 자체는 정상적으로 되고 키가 누락되지도 않는다 — 다만 그 순서를 결과에 그대로 노출하면 같은 입력에도 실행마다 다른 출력이 나올 수 있다는 것이 문제다. 그래서 순서가 중요하면 Vec 으로 옮겨 정렬한 뒤에 출력한다.
}
}

@Reflection(id: rust-hashmap-reflection) {
@Prompt(id: why-unordered) {
HashMap 이 순서를 보장하지 않는 대신 얻는 이점은 무엇일지 생각해 보세요 (힌트: 키로 값을 찾는 속도).
}

@Prompt(id: entry-vs-if) {
entry API 없이 if map.contains_key(word) { ... } else { ... } 로 같은 단어 세기를 구현했다면 코드가 어떻게 달라졌을지 적어 보세요.
}
}
