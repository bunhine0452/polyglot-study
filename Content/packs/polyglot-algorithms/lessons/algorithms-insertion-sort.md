@Concept(id: insertion-sort-concept) {
삽입 정렬은 배열의 앞부분이 이미 정렬돼 있다고 가정하고 시작한다(원소 하나짜리 앞부분은 당연히 정렬돼 있다). 그다음 값을 `key` 로 빼서 들고, 정렬된 앞부분을 오른쪽에서 왼쪽으로 훑으며 key 보다 큰 값들을 한 칸씩 뒤로 밀어낸다. key 보다 작거나 같은 값을 만나거나 맨 앞에 닿으면 그 자리에 key 를 끼워 넣는다.

최악의 경우(완전히 거꾸로 정렬된 입력)는 매번 앞부분 전체를 밀어야 해서 버블·선택 정렬과 같은 O(n^2) 이다. 하지만 **이미 정렬에 가까운 입력**이라면 다르다 — key 가 제자리 바로 앞에 있을 가능성이 높으니 `xs[j - 1] > key` 조건이 금방 거짓이 되어 안쪽 while 이 한두 번만 돌고 멈춘다. 입력이 완전히 정렬돼 있으면 안쪽 while 이 아예 한 번도 안 돌아서 O(n)이 된다. 입력의 정렬 상태에 따라 실제 걸리는 시간이 달라진다는 뜻에서 삽입 정렬을 적응 정렬(adaptive)이라고 부른다.

세 O(n^2) 정렬은 '다음에 무엇을 비교할지'가 다르다. 버블 정렬은 이웃 두 칸만 보고, 선택 정렬은 남은 구간 전체를 다 훑어야 다음 값을 정할 수 있고, 삽입 정렬은 이미 정렬된 앞부분과 비교하며 알맞은 자리를 찾는다. 이 차이가 이미 정렬된 입력을 만났을 때의 반응을 갈라놓는다.
}

@Example(id: insertion-sort-example, language: rust, expected: expected/algorithms-insertion-sort.txt) {
정렬된 앞부분에 다음 값을 밀어 넣는 과정을 한 번에 한 값씩 찍어 본다.

```rust
fn main() {
    let mut xs = [5, 2, 4, 1, 3];
    for i in 1..xs.len() {
        let key = xs[i];
        let mut j = i;
        while j > 0 && xs[j - 1] > key {
            xs[j] = xs[j - 1];
            j -= 1;
        }
        xs[j] = key;
        println!("{}번째 값 삽입 후: {:?}", i, xs);
    }
}
```
}

@Blank(id: insertion-sort-blank, language: rust) {
정렬된 앞부분에서 key 자리를 찾으려면, 앞 칸의 값이 key 보다 클 때만 밀어야 한다. 그 조건은 무엇일까?

```rust
fn insert_key(xs: &mut [i32], i: usize) {
    let key = xs[i];
    let mut j = i;
    while j > 0 && xs[j - 1] ___1___ key {
        xs[j] = xs[j - 1];
        j -= 1;
    }
    xs[j] = key;
}

fn main() {
    let mut xs = [5, 2, 4, 1, 3];
    for i in 1..xs.len() {
        insert_key(&mut xs, i);
    }
    println!("{:?}", xs);
}
```

@Answer(slot: 1) {
`>`
}
}

@Task(id: insertion-sort-task, language: rust, starter: starters/algorithms-insertion-sort.rs, tests: tests/algorithms-insertion-sort.rs, solution: solutions/algorithms-insertion-sort.rs) {
`Vec<i32>` 를 오름차순으로 제자리 정렬하세요. 정렬된 앞부분을 유지하면서 다음 값을 알맞은 자리까지 밀어 넣는 방식이어야 합니다.

@Hint {
i는 1부터 시작해라 — 원소 하나짜리 앞부분은 이미 정렬된 것으로 본다.
}

@Hint {
j를 i에서 시작해, xs[j-1] > key 인 동안 xs[j] = xs[j-1] 로 밀고 j를 줄여라.
}

@Hint {
while 조건에서 j > 0 을 먼저 확인해야 xs[j-1] 이 인덱스 밖으로 나가지 않는다.
}
}

@Quiz(id: insertion-sort-quiz, answer: near-linear) {
@Question {
이미 거의 정렬된 배열(뒤섞인 값이 거의 없는 배열)에 삽입 정렬을 돌리면 어떤 일이 일어날까?
}

@Choice(id: near-linear) {
안쪽 while 이 대부분 곧바로 멈춰서 O(n)에 가까워진다
}

@Choice(id: always-quadratic) {
정렬 여부와 상관없이 항상 O(n^2)이다
}

@Choice(id: fewer-outer) {
바깥 반복 횟수 자체가 줄어든다
}

@Explanation {
바깥 반복은 항상 n-1번 돈다. 달라지는 것은 안쪽 while 이 도는 횟수다 — 값이 제자리 근처에 있으면 xs[j-1] > key 가 금방 거짓이 되어 거의 밀지 않고 끝난다.
}
}

@Reflection(id: insertion-sort-reflection) {
@Prompt(id: compare-three) {
버블·선택·삽입 정렬이 각각 '다음에 무엇을 볼지' 정하는 방식이 어떻게 다른지 비교해 적어 보세요(이웃 비교 / 남은 구간 전체 스캔 / 정렬된 부분과의 비교).
}

@Prompt(id: adaptive-meaning) {
삽입 정렬이 '적응 정렬'이라는 말이 무슨 뜻인지, 왜 선택 정렬은 그렇지 않은지 설명해 보세요.
}
}
