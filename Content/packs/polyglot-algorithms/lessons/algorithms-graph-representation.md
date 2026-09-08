@Concept(id: graph-representation-concept) {
그래프는 정점(vertex) 과 정점을 잇는 간선(edge) 으로 이루어진다. 이걸 코드에서 다루려면 정점끼리 어떻게 연결돼 있는지를 자료구조로 표현해야 하는데, 흔히 쓰는 두 가지가 인접 리스트와 인접 행렬이다.

인접 리스트는 정점마다 '내 이웃이 누구인지' 목록을 들고 있는 방식이다 — `Vec<Vec<usize>>` 로 두면 인덱스가 정점 번호, 값이 이웃 정점 번호들이다. 간선이 E개면 무방향 그래프에서 이웃 목록에 총 2E개의 항목이 쌓이므로 메모리는 O(V + E) 다. 간선이 별로 없는 희소 그래프에서 유리하다.

인접 행렬은 정점 V개에 대해 V×V 크기의 표를 만들어 `mat[u][v]` 가 참이면 u와 v 사이에 간선이 있다는 뜻으로 쓰는 방식이다. 정점이 몇 개든 항상 V^2 칸을 차지하므로 메모리는 O(V^2) 다 — 간선이 얼마나 적든 상관없다. 대신 'u와 v 사이에 간선이 있는가' 를 묻는 질문에 표의 한 칸만 보면 되니 O(1) 이다. 인접 리스트로 같은 질문에 답하려면 u의 이웃 목록을 끝까지 훑어야 할 수 있어 O(degree(u)) 가 든다.

그래서 정점 수에 비해 간선이 적은 희소 그래프라면 인접 리스트가, 정점 수가 작거나 간선이 촘촘한 그래프이거나 간선 존재 여부를 자주 물어야 한다면 인접 행렬이 유리하다.

@Visualize(id: graph-representation, frames: visuals/graph-representation.json) {
그래프 표현이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: graph-representation-example, language: rust, expected: expected/algorithms-graph-representation.txt) {
간선 목록 하나로 인접 리스트와 인접 행렬을 둘 다 만들어 나란히 찍어 본다.

```rust
fn main() {
    let n = 6;
    let edges = [(0usize, 1usize), (0, 2), (1, 2), (3, 4)];

    let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
    for &(u, v) in edges.iter() {
        adj[u].push(v);
        adj[v].push(u);
    }
    for neighbors in adj.iter_mut() {
        neighbors.sort();
    }

    for (v, neighbors) in adj.iter().enumerate() {
        println!("{}: {:?}", v, neighbors);
    }

    let mut mat = vec![vec![false; n]; n];
    for &(u, v) in edges.iter() {
        mat[u][v] = true;
        mat[v][u] = true;
    }

    for row in mat.iter() {
        let line: String = row.iter().map(|&b| if b { 'O' } else { '.' }).collect();
        println!("{}", line);
    }
}
```
}

@Blank(id: graph-representation-blank, language: rust) {
무방향 그래프에서 mat[u][v] 를 참으로 두었다면, 대칭을 맞추기 위해 어느 칸도 참으로 둬야 할까?

```rust
fn build_matrix(n: usize, edges: &[(usize, usize)]) -> Vec<Vec<bool>> {
    let mut mat = vec![vec![false; n]; n];
    for &(u, v) in edges.iter() {
        mat[u][v] = true;
        ___1___ = true;
    }
    mat
}

fn main() {
    let mat = build_matrix(4, &[(0, 1), (1, 2)]);
    for row in mat.iter() {
        println!("{:?}", row);
    }
}
```

@Answer(slot: 1) {
`mat[v][u]`
}
}

@Task(id: graph-representation-task, language: rust, starter: starters/algorithms-graph-representation.rs, tests: tests/algorithms-graph-representation.rs, solution: solutions/algorithms-graph-representation.rs) {
정점 개수 `n` 과 간선 목록 `edges` 가 주어질 때, 무방향 그래프의 인접 리스트를 `Vec<Vec<usize>>` 로 돌려주세요. 정점은 0부터 n-1까지 번호가 매겨져 있고, 각 정점의 이웃 목록은 오름차순으로 정렬돼 있어야 합니다.

@Hint {
먼저 `vec![Vec::new(); n]` 으로 정점마다 빈 이웃 목록을 하나씩 만들어라.
}

@Hint {
무방향 그래프이므로 간선 (u, v) 하나는 adj[u]에도 adj[v]에도 흔적을 남겨야 한다.
}

@Hint {
순서를 보장하려면 채우는 걸 다 끝낸 다음 각 이웃 목록에 sort() 를 호출해라.
}
}

@Quiz(id: graph-representation-quiz, answer: list) {
@Question {
정점이 1000개, 간선이 2000개인 희소 그래프를 다룬다면 인접 리스트와 인접 행렬 중 메모리 면에서 어느 쪽이 유리할까?
}

@Choice(id: list) {
인접 리스트 — O(V+E) 라 정점·간선 수에 비례해서만 커진다
}

@Choice(id: matrix) {
인접 행렬 — O(V^2) 이라도 표라서 항상 더 작다
}

@Choice(id: same) {
둘 다 차이가 없다
}

@Explanation {
인접 행렬은 간선이 몇 개든 V^2 = 1,000,000 칸을 차지한다. 인접 리스트는 무방향이라 간선당 항목이 두 번씩 쌓여도 V + 2E = 1000 + 4000 = 5000 개 안팎이면 충분하다. 간선이 정점 수에 비해 적은 희소 그래프일수록 이 차이가 크게 벌어진다.
}
}

@Reflection(id: graph-representation-reflection) {
@Prompt(id: directed) {
이 레슨의 인접 리스트 구현은 간선 하나를 양쪽 정점에 다 넣어 무방향 그래프를 표현한다. 방향 그래프였다면 build_adjacency_list 의 코드가 어떻게 달라져야 할지 적어 보세요.
}

@Prompt(id: matrix-benefit) {
인접 행렬의 O(1) 간선 조회가 실제로 프로그램을 더 빠르게 만드는 상황은 어떤 경우일지, 반대로 그 이점이 크게 의미 없는 상황은 어떤 경우일지 생각해 보세요.
}
}
