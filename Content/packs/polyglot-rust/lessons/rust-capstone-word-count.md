@Concept(id: rust-capstone-concept) {
단어 빈도 세기는 이 트랙에서 배운 것들이 자연스럽게 이어지는 자리다. 문자열을 단어로 나누는 데는 `split_whitespace` 를 쓴다 — 공백이 하나든 여러 개든 상관없이 단어 사이를 갈라 준다. 나뉜 단어를 셀 때는 익숙한 `HashMap` 의 `entry(word).or_insert(0)` 패턴이 그대로 쓰인다.

`HashMap` 은 순회 순서를 보장하지 않는다는 것을 기억할 것이다. 빈도 내림차순, 동점이면 단어 오름차순처럼 정해진 순서로 결과를 보여주려면 `HashMap` 의 항목들을 `Vec` 으로 옮긴 뒤 직접 정렬해야 한다. 이때 쓰는 것이 `sort_by` 다 — 클로저로 두 원소를 어떻게 비교할지 규칙을 직접 적어 준다. 빈도를 먼저 비교하고, 같으면 단어로 다시 비교하는 식으로 비교 규칙 두 개를 `then_with` 로 이어 붙일 수 있다.

입력이 비어 있거나 요청한 개수 `n` 이 0이면 정상적인 결과가 없다. 이런 상황은 값 대신 실패를 돌려주는 `Result` 로 표현한다 — 패닉으로 멈추는 대신 호출한 쪽이 `match` 나 `?` 로 실패를 자연스럽게 처리하게 한다.

새로 배우는 것은 `split_whitespace` 와 `sort_by` 뿐이고, 나머지는 전부 이미 다룬 도구를 조합하는 일이다. 복잡해 보이는 프로그램도 결국 알고 있는 조각들을 순서대로 이어 붙인 것이다.
}

@Example(id: rust-capstone-example, language: rust, expected: expected/rust-capstone-word-count.txt) {
문장을 단어로 나눠 빈도를 센 뒤, 빈도 내림차순·단어 오름차순으로 정렬해 찍는다. 빈 입력은 `Err` 로 처리된다.

```rust
use std::collections::HashMap;

fn word_counts(text: &str) -> Result<HashMap<String, i32>, String> {
    if text.trim().is_empty() {
        return Err(String::from("입력이 비어 있습니다"));
    }

    let mut counts = HashMap::new();
    for word in text.split_whitespace() {
        *counts.entry(word.to_string()).or_insert(0) += 1;
    }
    Ok(counts)
}

fn main() {
    let text = "the quick brown fox the lazy dog the fox";
    match word_counts(text) {
        Ok(counts) => {
            let mut pairs: Vec<(&String, &i32)> = counts.iter().collect();
            pairs.sort_by(|a, b| b.1.cmp(a.1).then_with(|| a.0.cmp(b.0)));
            for (word, count) in pairs {
                println!("{}: {}", word, count);
            }
        }
        Err(e) => println!("오류: {}", e),
    }

    match word_counts("") {
        Ok(_) => println!("비어 있지 않음"),
        Err(e) => println!("오류: {}", e),
    }
}
```
}

@Blank(id: rust-capstone-blank, language: rust) {
단어로 나누는 메서드, HashMap 에 개수를 세는 메서드, Vec 을 정렬하는 메서드를 채워라.

```rust
use std::collections::HashMap;

fn count(text: &str) -> HashMap<String, i32> {
    let mut counts = HashMap::new();
    for word in text.___1___() {
        *counts.___2___(word.to_string()).or_insert(0) += 1;
    }
    counts
}

fn main() {
    let counts = count("a b a c b a");
    let mut pairs: Vec<(&String, &i32)> = counts.iter().collect();
    pairs.___3___(|x, y| y.1.cmp(x.1));
    for (word, n) in pairs {
        println!("{}: {}", word, n);
    }
}
```

@Answer(slot: 1) {
`split_whitespace`
}

@Answer(slot: 2) {
`entry`
}

@Answer(slot: 3) {
`sort_by`
}
}

@Task(id: rust-capstone-task, language: rust, starter: starters/rust-capstone-word-count.rs, tests: tests/rust-capstone-word-count.rs, solution: solutions/rust-capstone-word-count.rs) {
`top_words` 를 완성하라. 텍스트를 단어로 나눠 빈도를 센 뒤, 빈도가 높은 순으로(동점이면 단어의 가나다·알파벳 오름차순으로) 정렬해 상위 `n` 개를 `(단어, 빈도)` 쌍의 목록으로 돌려준다. 입력이 공백뿐이거나 비어 있으면, 또는 `n` 이 0이면 `Err` 를 돌려준다. `n` 이 단어 종류 수보다 크면 있는 만큼만 돌려준다.

@Hint {
`text.trim().is_empty()` 로 빈 입력을 먼저 걸러내고 `Err` 를 돌려줘라 — `n == 0` 도 마찬가지다.
}

@Hint {
`counts.entry(word.to_string()).or_insert(0) += 1` 로 세고, `into_iter().collect()` 로 `Vec<(String, i32)>` 를 만들어라.
}

@Hint {
`sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)))` 로 빈도 내림차순, 동점이면 단어 오름차순 정렬을 한 번에 표현할 수 있다. 마지막에 `truncate(n)` 으로 자르는 것을 잊지 마라.
}
}

@Quiz(id: rust-capstone-quiz, answer: hashmap-no-order) {
@Question {
`HashMap` 에 모은 단어별 빈도를 정해진 순서(빈도 내림차순)로 출력하려면 왜 `Vec` 으로 옮겨 정렬해야 하나요?
}

@Choice(id: hashmap-no-order) {
HashMap 은 순회 순서를 보장하지 않으므로, 순서가 중요하면 Vec 으로 옮겨 직접 정렬해야 한다
}

@Choice(id: cannot-iterate-twice) {
HashMap 은 애초에 한 번만 순회할 수 있어서 정렬 전에 옮겨야 한다
}

@Choice(id: sort-by-on-hashmap) {
sort_by 는 HashMap 에도 바로 쓸 수 있으므로 사실 옮길 필요는 없다
}

@Choice(id: entry-auto-sorts) {
entry API 로 값을 넣으면 자동으로 알파벳순 정렬이 유지된다
}

@Explanation {
`HashMap` 은 내부적으로 해시값에 따라 항목을 배치하기 때문에 순회 순서가 실행마다 달라질 수 있다. 정해진 순서로 결과를 보여주려면 항목을 `Vec` 으로 옮겨 `sort_by` 같은 메서드로 직접 정렬해야 한다. `HashMap` 은 여러 번 순회할 수 있고, `sort_by` 는 `Vec` 같은 슬라이스에 쓰는 메서드이며, `entry` 는 정렬과 무관하게 값을 세거나 초기화하는 데만 쓰인다.
}
}

@Reflection(id: rust-capstone-reflection) {
@Prompt(id: track-concepts-used) {
`top_words` 를 완성하며 이 트랙에서 배운 개념들 — HashMap, 클로저, Result, 테스트 — 이 각각 어디에 쓰였는지 되짚어 정리해 보세요.
}

@Prompt(id: why-result-not-empty-vec) {
빈 입력이나 n=0 일 때 Err 대신 그냥 빈 Vec 을 돌려주는 설계였다면, 호출하는 쪽에서 어떤 문제를 놓치기 쉬웠을지 생각해 보세요.
}
}
