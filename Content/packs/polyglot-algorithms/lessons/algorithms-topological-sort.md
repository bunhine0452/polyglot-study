@Concept(id: topological-sort-concept) {
선행 관계가 있는 작업들 — 이 강의를 들으려면 저 강의를 먼저 들어야 한다, 이 부품을 조립하려면 저 부품이 먼저 있어야 한다 — 을 하나의 순서로 줄 세우고 싶다. 이런 선행 관계는 방향 그래프로 표현된다: A -> B 는 "A가 B보다 먼저"라는 뜻이다.

이 순서를 정하는 것이 위상 정렬(topological sort)이다. 그런데 A -> B -> A 처럼 순환하는 선행 관계가 있으면 애초에 순서를 매길 수 없다 — A가 B보다 먼저이면서 동시에 B가 A보다 먼저일 수는 없으니까. 그래서 위상 정렬은 **사이클이 없는 방향 그래프(DAG)** 에서만 가능하다. 지난 레슨의 사이클 탐지가 여기서 전제 조건이 되는 이유다.

만드는 방법은 뜻밖에 간단하다. DFS를 돌리면서 각 정점을 **완전히 다 방문한 순간**을 기록해 두자 — 이것이 후위 순서(postorder)다. 정점 u에서 v로 가는 간선이 있으면, v는 u보다 먼저 완료된다 (u는 v를 다 보고 나서야 자기 자신을 완료 처리하니까). 즉 후위 순서에서는 항상 **간선의 도착점이 출발점보다 먼저** 등장한다.

우리가 원하는 건 그 반대 — 출발점이 도착점보다 먼저 오는 순서다. 그러니 후위 순서를 통째로 뒤집으면 된다. 뒤집힌 순서에서는 모든 간선 u -> v 에 대해 u가 v보다 앞에 온다. 이게 위상 정렬이다.

같은 DAG라도 위상 정렬 결과가 하나만 있는 건 아니다. 서로 선행 관계가 없는 정점들 (둘 중 어느 쪽도 다른 쪽보다 먼저일 필요가 없는 경우) 은 어느 순서로 놓아도 된다. DFS가 어떤 이웃부터 방문하느냐에 따라 다른, 그러나 똑같이 유효한 순서가 나올 수 있다.

@Visualize(id: topological-sort, frames: visuals/topological-sort.json) {
위상 정렬이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: topological-sort-example, language: rust, expected: expected/algorithms-topological-sort.txt) {
정점을 완료할 때마다 후위 순서에 쌓고, 마지막에 뒤집어 위상 정렬 결과를 만든다.

```rust
fn main() {
    let adj: Vec<Vec<usize>> = vec![
        vec![1, 2],
        vec![3],
        vec![3],
        vec![4],
        vec![],
    ];
    let n = adj.len();
    let mut state = vec![0u8; n];
    let mut order = Vec::new();

    for start in 0..n {
        if state[start] == 0 {
            visit(start, &adj, &mut state, &mut order);
        }
    }

    println!("후위 순서: {:?}", order);
    order.reverse();
    println!("위상 정렬: {:?}", order);
}

fn visit(u: usize, adj: &Vec<Vec<usize>>, state: &mut Vec<u8>, order: &mut Vec<usize>) {
    state[u] = 1;
    for &v in &adj[u] {
        if state[v] == 0 {
            visit(v, adj, state, order);
        }
    }
    state[u] = 2;
    println!("완료: {}", u);
    order.push(u);
}
```
}

@Blank(id: topological-sort-blank, language: rust) {
후위 순서를 다 모았다. 이걸 위상 정렬 순서로 만들려면 Vec 에 어떤 연산을 해야 할까?

```rust
fn topo_order(adj: &Vec<Vec<usize>>) -> Vec<usize> {
    let n = adj.len();
    let mut visited = vec![false; n];
    let mut order = Vec::new();

    fn visit(u: usize, adj: &Vec<Vec<usize>>, visited: &mut Vec<bool>, order: &mut Vec<usize>) {
        visited[u] = true;
        for &v in &adj[u] {
            if !visited[v] {
                visit(v, adj, visited, order);
            }
        }
        order.push(u);
    }

    for start in 0..n {
        if !visited[start] {
            visit(start, adj, &mut visited, &mut order);
        }
    }

    order.___1___();
    order
}

fn main() {
    let adj: Vec<Vec<usize>> = vec![vec![1], vec![2], vec![]];
    println!("{:?}", topo_order(&adj));
}
```

@Answer(slot: 1) {
`reverse`
}
}

@Task(id: topological-sort-task, language: rust, starter: starters/algorithms-topological-sort.rs, tests: tests/algorithms-topological-sort.rs, solution: solutions/algorithms-topological-sort.rs) {
방향 그래프를 인접 리스트 `&Vec<Vec<usize>>` 로 받아, 위상 정렬 결과를 `Option<Vec<usize>>` 로 돌려주는 `topo_sort` 를 작성하세요. 사이클이 있으면 `None` 을 돌려줘야 합니다. 그래프는 여러 컴포넌트로 나뉘어 있을 수 있습니다.

@Hint {
지난 레슨의 사이클 탐지를 그대로 재사용할 수 있다 — state 로 방문 중인 정점을 다시 만나면 사이클이다.
}

@Hint {
정점을 완료 처리(state 를 방문 완료로 바꾸는 순간)할 때마다 결과 벡터에 그 정점을 추가해라.
}

@Hint {
사이클이 없다면, 모은 순서를 뒤집는 것만 남았다.
}
}

@Quiz(id: topological-sort-quiz, answer: v-first) {
@Question {
DFS 후위 순서(postorder)에서 간선 u -> v 가 있을 때, u와 v 중 어느 쪽이 먼저 완료 처리될까?
}

@Choice(id: v-first) {
v가 먼저다 — u는 v를 포함한 자식들을 다 본 뒤에야 완료되므로
}

@Choice(id: u-first) {
u가 먼저다 — DFS가 u에 먼저 도착하므로
}

@Choice(id: same-time) {
항상 동시에 완료된다
}

@Explanation {
u에서 v로 가는 간선을 따라 v를 방문하고 그 아래를 다 탐색해야 u의 방문도 끝난다. 그래서 후위 순서에서는 v가 항상 u보다 먼저 나오고, 이를 뒤집으면 u가 v보다 먼저 오는 위상 정렬 순서가 된다.
}
}

@Reflection(id: topological-sort-reflection) {
@Prompt(id: multiple-orders) {
선행 관계가 전혀 없는 독립된 작업이 여러 개 있는 DAG를 하나 떠올려 보세요. 위상 정렬 결과가 왜 하나로 고정되지 않는지, 어떤 순서들이 동시에 유효한지 설명해 보세요.
}

@Prompt(id: why-cycle-check) {
사이클이 있는 그래프에 후위 순서 뒤집기만 그대로 적용하면 어떤 일이 벌어질지 생각해 보세요. 왜 위상 정렬 전에 반드시 사이클 유무를 확인해야 할까요?
}
}
