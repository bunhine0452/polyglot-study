@Concept(id: connected-components-concept) {
그래프가 항상 한 덩어리로 이어져 있는 건 아니다. 어떤 정점에서 아무리 간선을 따라가도 닿을 수 없는 정점들이 따로 뭉쳐 있을 수 있다. 이렇게 서로 갈라진 덩어리 하나하나를 연결 요소(connected component) 라고 부른다.

연결 요소를 세는 방법은 간단하다. 정점을 0번부터 순서대로 훑다가, 아직 아무 탐색도 방문하지 않은 정점을 만나면 거기서 BFS 든 DFS 든 새로 탐색을 시작한다. 그 탐색이 닿는 정점 전부가 하나의 연결 요소다. 그러고 나서 계속 훑다가 또 미방문 정점을 만나면 또 새로 시작한다. 이렇게 새로 시작한 횟수가 곧 연결 요소의 개수다.

BFS로 하든 DFS로 하든 나오는 개수와 각 정점이 속하는 그룹은 똑같다. 한 정점에서 출발해 간선을 따라 도달할 수 있는 정점의 집합은 탐색 순서와 무관하게 그래프 구조 자체로 정해지는 값이기 때문이다 — 큐를 쓰든 스택을 쓰든 "이 정점에서 갈 수 있는 곳"이라는 사실은 바뀌지 않는다.

전체 시간은 얼마나 걸릴까? 여러 번 탐색을 새로 시작해도, 이미 방문한 정점은 다시 열어보지 않는다. 그러니 모든 연결 요소를 합쳐도 결국 정점 하나와 간선 하나를 딱 한 번씩만 들여다본다 — O(V + E) 다.
}

@Example(id: connected-components-example, language: rust, expected: expected/algorithms-connected-components.txt) {
서로 갈라진 세 덩어리로 이루어진 그래프에서, 정점을 0번부터 훑으며 아직 안 가본 정점을 만날 때마다 새로 탐색을 시작해 본다.

```rust
fn visit(u: usize, adj: &Vec<Vec<usize>>, visited: &mut Vec<bool>, comp: &mut Vec<usize>) {
    visited[u] = true;
    comp.push(u);
    for &v in &adj[u] {
        if !visited[v] {
            visit(v, adj, visited, comp);
        }
    }
}

fn main() {
    let n = 7;
    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    let edges = [(0, 1), (1, 2), (3, 4), (5, 6)];
    for &(u, v) in edges.iter() {
        adj[u].push(v);
        adj[v].push(u);
    }

    let mut visited = vec![false; n];
    let mut count = 0;
    for v in 0..n {
        if !visited[v] {
            count += 1;
            let mut comp = Vec::new();
            visit(v, &adj, &mut visited, &mut comp);
            println!("컴포넌트 {}: {:?}", count, comp);
        }
    }
    println!("연결 요소 {}개", count);
}
```
}

@Blank(id: connected-components-blank, language: rust) {
바깥 반복문이 정점 `v` 를 하나씩 볼 때, 언제 새로 탐색을 시작해야 할까?

```rust
fn visit(u: usize, adj: &Vec<Vec<usize>>, visited: &mut Vec<bool>, comp: &mut Vec<usize>) {
    visited[u] = true;
    comp.push(u);
    for &w in &adj[u] {
        if !visited[w] {
            visit(w, adj, visited, comp);
        }
    }
}

fn main() {
    let n = 5;
    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    let edges = [(0, 1), (2, 3)];
    for &(u, v) in edges.iter() {
        adj[u].push(v);
        adj[v].push(u);
    }
    let mut visited = vec![false; n];
    let mut count = 0;
    for v in 0..n {
        if ___1___ {
            count += 1;
            let mut comp = Vec::new();
            visit(v, &adj, &mut visited, &mut comp);
        }
    }
    println!("연결 요소 {}개", count);
}
```

@Answer(slot: 1) {
`!visited[v]`
}
}

@Task(id: connected-components-task, language: rust, starter: starters/algorithms-connected-components.rs, tests: tests/algorithms-connected-components.rs, solution: solutions/algorithms-connected-components.rs) {
정점 `i` 가 몇 번째 연결 요소에 속하는지를 담은 길이 `n` 벡터를 반환하는 `component_ids(n, adj)` 를 작성하세요. 컴포넌트 번호는 0부터 시작하고, 정점을 0번부터 순서대로 훑다가 처음 발견되는 순서대로 매깁니다.

@Hint {
정점을 0부터 순서대로 보다가, 아직 번호가 없는 정점을 만나면 거기서부터 새로 퍼뜨려야 한다.
}

@Hint {
한 번 시작한 탐색이 끝나기 전까지 만나는 모든 정점은 같은 번호를 받는다 — 탐색이 끝난 뒤에야 번호를 하나 올려라.
}

@Hint {
n 이 0이면 반복문이 한 번도 돌지 않는다는 것을 기억해라.
}
}

@Quiz(id: connected-components-quiz, answer: v-plus-e) {
@Question {
정점 V개, 간선 E개인 그래프에서 모든 연결 요소를 찾는 전체 시간복잡도는 얼마일까?
}

@Choice(id: v-plus-e) {
O(V + E) — 연결 요소가 몇 개든 모든 정점과 간선을 합쳐서 딱 한 번씩만 본다
}

@Choice(id: v-times-e) {
O(V * E) — 컴포넌트마다 그래프 전체를 처음부터 다시 훑어야 하니 훨씬 느려진다
}

@Choice(id: v-squared) {
O(V^2) — 모든 정점 쌍이 서로 연결돼 있는지 확인해야 한다
}

@Explanation {
탐색을 여러 번 새로 시작하더라도 이미 방문한 정점은 다시 열어보지 않는다. 그러니 컴포넌트 개수와 상관없이, 모든 탐색을 합치면 결국 정점 하나와 간선 하나를 딱 한 번씩만 보게 된다 — O(V + E) 다.
}
}

@Reflection(id: connected-components-reflection) {
@Prompt(id: bfs-vs-dfs-same-count) {
이번 예제는 DFS로 짰습니다. 같은 그래프를 BFS로 탐색해도 연결 요소의 개수와 각 정점이 속하는 그룹이 똑같이 나오는 이유를 스스로 설명해 보세요.
}

@Prompt(id: dynamic-edges) {
그래프에 간선이 실시간으로 계속 추가되는 상황이라면, 간선이 하나 추가될 때마다 이 방식대로 전체를 처음부터 다시 훑는 건 왜 비효율적일 수 있을까요? 어떤 대안이 있을지 이름을 몰라도 괜찮으니 자유롭게 생각해 보세요.
}
}
