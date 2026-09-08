@Concept(id: shortest-path-unweighted-concept) {
BFS는 방문 순서만으로도 쓸모가 있지만, 각 정점까지의 거리와 '누구를 거쳐서 왔는지'를 함께 기록하면 시작 정점에서 특정 목표 정점까지의 최단 경로 자체를 복원할 수 있다.

정점 v 를 처음 방문할 때(즉 dist[v] 를 처음 채울 때), 그 순간 큐에서 꺼낸 정점 u 를 `parent[v] = Some(u)` 로 남겨둔다. u 는 v 를 발견하게 만든 정점이다.

가중치가 없는 그래프에서는 이 방식이 항상 최단 경로를 준다. BFS는 레벨 0, 레벨 1, 레벨 2 순서로 정점을 하나도 빠짐없이 방문한 다음에야 다음 레벨로 넘어가기 때문에, 어떤 정점이 처음 방문되는 순간의 거리는 더 줄어들 수 없는 최솟값이다 — 나중에 다른 경로로 그 정점에 도달해도 거리가 같거나 더 길 수밖에 없으므로 이미 기록된 dist 와 parent 를 덮어쓸 필요가 없다.

목표 정점에서 parent 를 하나씩 거슬러 올라가면 시작 정점까지의 경로가 거꾸로 나온다. 이걸 뒤집으면 시작 정점부터 목표 정점까지의 순서가 된다.
}

@Example(id: shortest-path-unweighted-example, language: rust, expected: expected/algorithms-shortest-path-unweighted.txt) {
6개 정점짜리 그래프에서 0번 정점부터 BFS로 거리와 parent 를 기록하고, 5번 정점까지의 거리와 경로를 복원해본다.

```rust
fn main() {
    let n = 6;
    let adj: Vec<Vec<usize>> = vec![
        vec![1, 2],
        vec![0, 3],
        vec![0, 3, 4],
        vec![1, 2, 5],
        vec![2, 5],
        vec![3, 4],
    ];
    let start = 0;
    let goal = 5;

    let mut dist = vec![-1i32; n];
    let mut parent: Vec<Option<usize>> = vec![None; n];
    let mut queue = std::collections::VecDeque::new();
    dist[start] = 0;
    queue.push_back(start);

    while let Some(u) = queue.pop_front() {
        for &v in &adj[u] {
            if dist[v] == -1 {
                dist[v] = dist[u] + 1;
                parent[v] = Some(u);
                queue.push_back(v);
            }
        }
    }

    println!("{}에서 {}까지 거리: {}", start, goal, dist[goal]);

    let mut path = vec![goal];
    let mut cur = goal;
    while let Some(p) = parent[cur] {
        path.push(p);
        cur = p;
    }
    path.reverse();
    println!("경로: {:?}", path);
}
```
}

@Blank(id: shortest-path-unweighted-blank, language: rust) {
정점 v 를 처음 발견했을 때, v 의 parent 로 기록해야 할 것은 지금 큐에서 꺼낸 정점 중 무엇일까?

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

    let mut dist = vec![-1i32; n];
    let mut parent: Vec<Option<usize>> = vec![None; n];
    let mut queue = std::collections::VecDeque::new();
    dist[start] = 0;
    queue.push_back(start);

    while let Some(u) = queue.pop_front() {
        for &v in &adj[u] {
            if dist[v] == -1 {
                dist[v] = dist[u] + 1;
                parent[v] = Some(___1___);
                queue.push_back(v);
            }
        }
    }

    println!("{:?}", parent);
}
```

@Answer(slot: 1) {
`u`
}
}

@Task(id: shortest-path-unweighted-task, language: rust, starter: starters/algorithms-shortest-path-unweighted.rs, tests: tests/algorithms-shortest-path-unweighted.rs, solution: solutions/algorithms-shortest-path-unweighted.rs) {
정점 수 `n` 과 인접 리스트 `adj`, 시작 정점 `start`, 목표 정점 `goal` 이 주어질 때, `start` 부터 `goal` 까지의 최단 경로를 정점 순서 그대로 `Vec<usize>` 에 담아 `Some` 으로 돌려주세요. `goal` 에 닿을 수 없으면 `None` 을, `start` 와 `goal` 이 같으면 그 정점 하나만 담은 경로를 돌려주세요.

@Hint {
dist 와 parent 를 같이 채워야 한다 — dist 만으로는 경로를 복원할 수 없다.
}

@Hint {
u 를 큐에서 꺼내 이웃 v 를 처음 만나는 순간, 그 u 가 v 의 parent 다.
}

@Hint {
경로는 goal 에서 parent 를 따라 거슬러 올라간 다음 뒤집어야 start 부터 goal 순서가 된다.
}
}

@Quiz(id: shortest-path-unweighted-quiz, answer: level-by-level) {
@Question {
가중치가 없는 그래프에서 BFS로 찾은 경로가 항상 최단 경로인 이유는 무엇인가?
}

@Choice(id: level-by-level) {
BFS는 정점을 거리 순서로 한 겹씩 방문하므로, 어떤 정점을 처음 방문하는 순간의 거리가 곧 그 정점까지의 최단 거리이기 때문이다.
}

@Choice(id: vertex-order) {
BFS가 항상 정점 번호가 작은 순서로 방문하기 때문이다.
}

@Choice(id: compare-all) {
매 반복마다 시작점에서 목표까지의 모든 경로 길이를 비교해서 가장 짧은 것을 고르기 때문이다.
}

@Explanation {
BFS는 레벨 0, 레벨 1, 레벨 2 순서로 정점을 전부 방문한 다음에야 다음 레벨로 넘어간다. 그래서 어떤 정점이 큐에서 처음 꺼내지는 순간 기록되는 거리는 더 짧아질 수 없는 값이고, 그 순간의 parent 를 따라가면 최단 경로가 나온다. 모든 경로를 일일이 비교하지 않아도 된다.
}
}

@Reflection(id: shortest-path-unweighted-reflection) {
@Prompt(id: weighted-edges) {
간선마다 가중치가 다르다면, 이 BFS 방식으로 찾은 경로가 왜 더 이상 최단 경로임을 보장하지 못하는지 예를 들어 설명해 보세요.
}

@Prompt(id: multiple-shortest-paths) {
최단 경로가 여러 개 있을 수 있는 그래프에서, 지금처럼 parent 를 정점마다 하나씩만 기록하면 그중 하나만 복원됩니다. 모든 최단 경로를 다 구하려면 어떤 정보를 더 기록해야 할지 생각해 보세요.
}
}
