@Concept(id: dfs-concept) {
그래프를 훑는 또 다른 방법은 한 방향으로 갈 수 있는 데까지 파고드는 것이다. 더 갈 곳이 없으면 되돌아와서(역추적, backtrack) 아직 안 가본 갈래가 있는지 살핀다. 이것이 깊이 우선 탐색(DFS) 이다.

재귀로 짜면 이 되돌아옴은 저절로 생긴다. `visit(u)` 가 이웃 `v` 를 만나 `visit(v)` 를 호출하면, `visit(v)` 가 완전히 끝나야 `visit(u)` 로 돌아와 다음 이웃을 본다. 즉 **함수 호출 스택이 곧 지금까지 내려온 경로**이고, 함수가 리턴하는 순간이 바로 역추적이다.

같은 일을 재귀 없이도 할 수 있다. 이번엔 `Vec` 을 스택처럼 써서 직접 관리한다. 큐 대신 스택을 쓴다는 것 말고는 BFS 와 골격이 비슷하다 — 다만 큐는 넣은 순서대로 꺼내고(FIFO), 스택은 넣은 것의 반대 순서로 꺼낸다(LIFO). 그 차이 하나가 방문 순서를 완전히 바꿔놓는다.

같은 정점에서 시작해도 BFS 는 가까운 정점부터 층층이 넓게 퍼지고, DFS 는 한 갈래를 끝까지 파고든 다음에야 옆 갈래로 넘어간다. 그래서 같은 그래프, 같은 시작점이라도 두 탐색이 정점을 만나는 순서는 보통 다르다.

@Visualize(id: dfs, frames: visuals/dfs.json) {
깊이 우선 탐색(DFS)이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: dfs-example, language: rust, expected: expected/algorithms-dfs.txt) {
가지가 갈라지는 작은 그래프에서, 재귀 DFS 가 한쪽 갈래를 끝까지 파고들었다가 돌아오는 모습을 들여쓰기로 찍어 본다.

```rust
fn visit(u: usize, adj: &Vec<Vec<usize>>, visited: &mut Vec<bool>, order: &mut Vec<usize>, depth: usize) {
    visited[u] = true;
    order.push(u);
    println!("{}정점 {} 방문", "  ".repeat(depth), u);
    for &v in &adj[u] {
        if !visited[v] {
            visit(v, adj, visited, order, depth + 1);
        }
    }
}

fn main() {
    let n = 7;
    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    let edges = [(0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (5, 6)];
    for &(u, v) in edges.iter() {
        adj[u].push(v);
        adj[v].push(u);
    }

    let mut visited = vec![false; n];
    let mut order = Vec::new();
    visit(0, &adj, &mut visited, &mut order, 0);
    println!("방문 순서: {:?}", order);
}
```
}

@Blank(id: dfs-blank, language: rust) {
이웃을 살피러 재귀 호출을 하기 전에, 지금 정점을 방문했다고 표시부터 해두지 않으면 무슨 일이 벌어질까?

```rust
fn visit(u: usize, adj: &Vec<Vec<usize>>, visited: &mut Vec<bool>, order: &mut Vec<usize>) {
    ___1___ = true;
    order.push(u);
    for &v in &adj[u] {
        if !visited[v] {
            visit(v, adj, visited, order);
        }
    }
}

fn main() {
    let n = 5;
    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    let edges = [(0, 1), (0, 2), (1, 3), (2, 4)];
    for &(u, v) in edges.iter() {
        adj[u].push(v);
        adj[v].push(u);
    }
    let mut visited = vec![false; n];
    let mut order = Vec::new();
    visit(0, &adj, &mut visited, &mut order);
    println!("{:?}", order);
}
```

@Answer(slot: 1) {
`visited[u]`
}
}

@Task(id: dfs-task, language: rust, starter: starters/algorithms-dfs.rs, tests: tests/algorithms-dfs.rs, solution: solutions/algorithms-dfs.rs) {
재귀를 쓰지 않고 `Vec` 을 스택으로 직접 관리해 DFS 방문 순서를 반환하는 `dfs_order_iterative(n, adj, start)` 를 작성하세요. 정점을 스택에 넣는 순서를 재귀 버전과 맞춰야 같은 방문 순서가 나옵니다 — 안 그러면 그래프는 맞게 훑어도 이 레슨이 보이려는 순서와 어긋납니다.

@Hint {
이웃을 스택에 넣을 때 순서 그대로 넣으면 나중에 pop 할 때 가장 큰 번호 이웃부터 나온다. 재귀 버전처럼 작은 번호부터 파고들게 하려면 이웃을 뒤집어서 넣어라.
}

@Hint {
push 할 때가 아니라 pop 한 직후에 방문 표시를 해라 — 한 정점이 서로 다른 이웃을 통해 스택에 두 번 들어갈 수 있다.
}

@Hint {
이미 방문한 정점을 pop 했다면 그냥 건너뛰고 다음 걸 pop 해라.
}
}

@Quiz(id: dfs-quiz, answer: stack-vs-queue) {
@Question {
같은 그래프, 같은 시작 정점이라도 DFS 와 BFS 의 방문 순서가 보통 다른 이유는 무엇일까?
}

@Choice(id: stack-vs-queue) {
DFS 는 스택(LIFO)으로 가장 최근에 만난 정점부터 파고들고, BFS 는 큐(FIFO)로 가장 먼저 만난 정점부터 넓게 퍼지기 때문이다
}

@Choice(id: different-graph) {
DFS 와 BFS 는 서로 다른 인접 리스트를 사용하기 때문이다
}

@Choice(id: random-order) {
두 탐색 모두 방문 순서가 무작위라서 매번 다르게 나오기 때문이다
}

@Explanation {
그래프와 시작점이 같으면 인접 리스트도 같다. 순서가 갈리는 건 자료구조 때문이다 — 스택은 방금 넣은 것부터 꺼내 한 갈래를 끝까지 파고들게 만들고(DFS), 큐는 먼저 넣은 것부터 꺼내 가까운 정점부터 층층이 퍼지게 만든다(BFS). 둘 다 결정적이라 같은 입력이면 항상 같은 순서가 나온다.
}
}

@Reflection(id: dfs-reflection) {
@Prompt(id: recursion-depth) {
정점이 수만 개인 아주 긴 체인 그래프에서 재귀 DFS를 그대로 쓰면 어떤 문제가 생길 수 있을까요? 명시적 스택으로 짠 버전은 왜 그 문제를 피할 수 있는지도 생각해 보세요.
}

@Prompt(id: backtrack-point) {
"역추적"이 이번 코드에서 정확히 어느 순간에 일어나는지 짚어 보세요. 재귀 버전과 스택 버전 각각에서 그 순간을 찾아 설명해 보세요.
}
}
