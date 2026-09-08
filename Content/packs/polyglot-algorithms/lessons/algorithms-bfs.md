@Concept(id: bfs-concept) {
그래프에서 시작 정점 하나로부터 도달할 수 있는 모든 정점을 훑고 싶을 때, 가까운 정점부터 순서대로 보고 싶다면 큐(FIFO)를 쓴다.

정점을 방문할 때마다 그 이웃을 큐에 넣는다. 큐는 먼저 들어온 것이 먼저 나가므로, 시작 정점의 이웃(거리 1)이 전부 큐에 들어간 다음에야 그 이웃의 이웃(거리 2)이 들어가기 시작한다. 그래서 큐에서 꺼내는 순서는 거리가 작은 정점부터 큰 정점 순서로 자연히 정렬된다 — 같은 거리 안에서는 순서가 뒤섞일 수 있어도, 거리가 커지는 방향 자체는 절대 거꾸로 가지 않는다.

방문 표시(Vec<bool>)는 정점을 큐에 넣는 그 순간 바로 해야 한다. 꺼낼 때 표시하면, 아직 큐 안에 있는 같은 정점이 다른 이웃을 처리하는 동안 또 큐에 들어갈 수 있다 — 결과적으로 같은 정점이 여러 번 방문되고, 사이클이 있는 그래프에서는 큐가 계속 불어나 끝나지 않는다.

인접 리스트에서 정점 하나의 이웃을 보는 데 걸리는 시간과, 각 간선을 정확히 두 번(양 끝에서 한 번씩) 보는 것을 합치면 전체 시간은 O(정점 수 + 간선 수)다.
}

@Example(id: bfs-example, language: rust, expected: expected/algorithms-bfs.txt) {
7개 정점짜리 그래프에서 0번 정점부터 BFS로 방문하며, 방문 순서와 그때까지의 거리를 함께 찍어본다.

```rust
fn main() {
    let n = 7;
    let adj: Vec<Vec<usize>> = vec![
        vec![1, 2],
        vec![0, 3],
        vec![0, 3, 4],
        vec![1, 2, 5],
        vec![2, 5],
        vec![3, 4, 6],
        vec![5],
    ];
    let start = 0;

    let mut visited = vec![false; n];
    let mut dist = vec![0usize; n];
    let mut queue = std::collections::VecDeque::new();
    visited[start] = true;
    queue.push_back(start);

    while let Some(u) = queue.pop_front() {
        println!("정점 {} 방문 (거리 {})", u, dist[u]);
        for &v in &adj[u] {
            if !visited[v] {
                visited[v] = true;
                dist[v] = dist[u] + 1;
                queue.push_back(v);
            }
        }
    }
}
```
}

@Blank(id: bfs-blank, language: rust) {
이웃 정점을 큐에 넣기 전에, 그 정점을 방문했다는 표시를 어디에 남겨야 할까?

```rust
fn main() {
    let n = 5;
    let adj: Vec<Vec<usize>> = vec![
        vec![1, 2],
        vec![0, 3],
        vec![0, 3],
        vec![1, 2, 4],
        vec![3],
    ];
    let start = 0;

    let mut visited = vec![false; n];
    let mut order = Vec::new();
    let mut queue = std::collections::VecDeque::new();
    visited[start] = true;
    queue.push_back(start);

    while let Some(u) = queue.pop_front() {
        order.push(u);
        for &v in &adj[u] {
            if !visited[v] {
                ___1___ = true;
                queue.push_back(v);
            }
        }
    }

    println!("{:?}", order);
}
```

@Answer(slot: 1) {
`visited[v]`
}
}

@Task(id: bfs-task, language: rust, starter: starters/algorithms-bfs.rs, tests: tests/algorithms-bfs.rs, solution: solutions/algorithms-bfs.rs) {
정점 수 `n` 과 인접 리스트 `adj`, 시작 정점 `start` 가 주어질 때, BFS로 방문한 정점을 방문한 순서 그대로 `Vec<usize>` 로 돌려주세요. `start` 에서 닿지 않는 정점은 결과에 나오면 안 됩니다.

@Hint {
visited 를 `Vec<bool>` 로 두고, `std::collections::VecDeque` 를 큐로 써라.
}

@Hint {
이웃을 `push_back` 할 때 바로 visited 를 true 로 만들어야 같은 정점이 큐에 여러 번 들어가지 않는다.
}

@Hint {
order 에는 큐에서 꺼낸 정점만 쌓인다 — 애초에 큐에 들어가지 않은 정점은 자연히 결과에서 빠진다.
}
}

@Quiz(id: bfs-quiz, answer: level-order) {
@Question {
그래프에서 BFS로 정점을 방문했을 때, 방문 순서와 시작 정점으로부터의 거리(레벨) 사이의 관계로 옳은 것은?
}

@Choice(id: level-order) {
레벨이 작은 정점부터 방문되며, 같은 레벨 안에서는 순서가 달라질 수 있지만 레벨이 커지는 방향 자체는 절대 거꾸로 가지 않는다.
}

@Choice(id: vertex-order) {
방문 순서는 항상 정점 번호가 작은 순서와 같다.
}

@Choice(id: reverse-level) {
레벨이 큰 정점일수록 먼저 방문된다.
}

@Explanation {
BFS는 정점을 큐에 넣은 순서대로 꺼낸다. 레벨 k 의 정점들이 전부 큐에 들어간 다음에야 레벨 k+1 의 정점들이 큐에 쌓이기 시작하므로, 방문 순서는 레벨이 커지는 방향으로만 진행된다. 같은 레벨 안의 순서는 인접 리스트에 이웃이 나열된 순서에 따라 달라질 수 있다.
}
}

@Reflection(id: bfs-reflection) {
@Prompt(id: mark-on-pop) {
방문 표시를 큐에 '넣을 때'가 아니라 큐에서 '꺼낼 때' 한다면 어떤 일이 벌어질지 생각해 보세요. 같은 정점이 큐에 몇 번 들어갈 수 있을까요?
}

@Prompt(id: stack-instead) {
큐(FIFO) 대신 스택(LIFO)을 쓰면, 즉 가장 나중에 넣은 정점을 먼저 꺼낸다면 방문 순서가 어떻게 달라질지 이 레슨의 그래프로 손으로 따라가며 예상해 보세요.
}
}
