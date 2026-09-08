@Concept(id: dijkstra-concept) {
BFS는 간선에 가중치가 없을 때 최단 거리를 구했다 — 간선 하나가 곧 거리 1이니, 먼저 꺼낸 정점이 항상 더 가까운 정점이었다. 간선마다 비용(가중치)이 다르면 이 전제가 무너진다. 간선 하나만 건너도 비용이 10일 수 있고, 세 번을 건너도 합쳐서 4일 수 있다. 먼저 도달했다고 더 가까운 게 아니다.

다익스트라는 여기서 **탐욕적 선택**을 한다. 아직 거리가 확정되지 않은 정점들 중, 지금까지 알려진 거리가 가장 짧은 정점을 고른다. 그 정점의 거리는 이제 더 줄어들 수 없다고 확정한다 — 왜냐하면 다른 어떤 미확정 정점을 거쳐 오더라도, 그 경유지까지 가는 데만도 이미 지금 고른 정점보다 먼 거리가 들기 때문이다. 이 논리가 성립하려면 **모든 가중치가 0 이상**이어야 한다. 음수 간선이 있으면 나중에 확정된 줄 알았던 거리가 음수 간선을 거쳐 더 줄어들 수 있어서 탐욕적 선택이 깨진다.

구체적으로는 이렇게 진행한다. 시작 정점의 거리를 0, 나머지는 무한대로 둔다. 매 라운드마다 미확정 정점 중 거리가 가장 짧은 정점 u를 고르고 확정한다. 그다음 u의 이웃 v마다, u를 거쳐 가는 거리(dist[u] + 가중치)가 지금까지 알려진 dist[v]보다 짧으면 갱신한다 — 이것이 거리 갱신(relaxation)이다.

우선순위 큐를 쓰면 가장 짧은 정점을 매번 로그 시간에 고를 수 있지만, 아직 배우지 않았다. 여기서는 매 라운드마다 미확정 정점을 처음부터 끝까지 훑어 최솟값을 찾는다 — 라운드당 O(V), 정점이 V개니 전체 O(V²)다. 정점 수가 많지 않다면 이걸로 충분하다.
}

@Example(id: dijkstra-example, language: rust, expected: expected/algorithms-dijkstra.txt) {
정점을 확정할 때마다, 그리고 거리를 갱신할 때마다 찍어서 다익스트라가 어떻게 진행되는지 본다.

```rust
const INF: u32 = u32::MAX;

fn main() {
    // (이웃 정점, 가중치) 쌍의 인접 리스트. 가중치는 모두 0 이상이어야 한다.
    let adj: Vec<Vec<(usize, u32)>> = vec![
        vec![(1, 4), (2, 1)],
        vec![(3, 1), (4, 7)],
        vec![(1, 2), (3, 5)],
        vec![(4, 3)],
        vec![],
    ];
    let n = adj.len();
    let start = 0;

    let mut dist = vec![INF; n];
    let mut done = vec![false; n];
    dist[start] = 0;

    for _ in 0..n {
        // 미확정 정점 중 거리가 가장 짧은 정점을 매번 훑어서 고른다 (O(V)).
        let mut u = None;
        for v in 0..n {
            if !done[v] && (u.is_none() || dist[v] < dist[u.unwrap()]) {
                u = Some(v);
            }
        }
        let u = match u {
            Some(u) if dist[u] != INF => u,
            _ => break, // 남은 정점이 모두 도달 불가능하다
        };

        done[u] = true;
        println!("확정: {} (거리 {})", u, dist[u]);

        for &(v, w) in &adj[u] {
            if !done[v] && dist[u] + w < dist[v] {
                dist[v] = dist[u] + w;
                println!("  거리 갱신: {} -> {} = {}", u, v, dist[v]);
            }
        }
    }

    print!("최종 거리:");
    for v in 0..n {
        print!(" {}", dist[v]);
    }
    println!();
}
```
}

@Blank(id: dijkstra-blank, language: rust) {
u를 거쳐 v로 가는 거리(dist[u] + w)가 지금까지 알려진 v의 거리보다 짧을 때만 갱신해야 한다. 무엇과 비교해야 할까?

```rust
const INF: u32 = u32::MAX;

fn shortest_distances(adj: &Vec<Vec<(usize, u32)>>, start: usize) -> Vec<u32> {
    let n = adj.len();
    let mut dist = vec![INF; n];
    let mut done = vec![false; n];
    dist[start] = 0;

    for _ in 0..n {
        let mut u = None;
        for v in 0..n {
            if !done[v] && (u.is_none() || dist[v] < dist[u.unwrap()]) {
                u = Some(v);
            }
        }
        let u = match u {
            Some(u) if dist[u] != INF => u,
            _ => break,
        };

        done[u] = true;
        for &(v, w) in &adj[u] {
            if !done[v] && dist[u] + w < ___1___ {
                dist[v] = dist[u] + w;
            }
        }
    }
    dist
}

fn main() {
    let adj: Vec<Vec<(usize, u32)>> = vec![vec![(1, 4), (2, 1)], vec![], vec![(1, 2)]];
    println!("{:?}", shortest_distances(&adj, 0));
}
```

@Answer(slot: 1) {
`dist[v]`
}
}

@Task(id: dijkstra-task, language: rust, starter: starters/algorithms-dijkstra.rs, tests: tests/algorithms-dijkstra.rs, solution: solutions/algorithms-dijkstra.rs) {
가중치가 있는 방향 그래프를 `&Vec<Vec<(usize, u32)>>` (각 원소가 (이웃 정점, 가중치) 쌍인 인접 리스트) 로 받고, 시작 정점 `start` 에서 각 정점까지의 최단 거리를 `Vec<u32>` 로 돌려주는 `dijkstra` 를 작성하세요. 도달할 수 없는 정점의 거리는 `u32::MAX` 로 둡니다. 우선순위 큐 없이, 매 라운드 미확정 정점을 훑어 최솟값을 고르는 방식으로 구현하세요. 모든 가중치는 0 이상이라고 가정해도 됩니다.

@Hint {
dist 를 u32::MAX(무한대 취급)로 채우고 dist[start] 만 0 으로 시작해라.
}

@Hint {
매 라운드 미확정(done 이 false 인) 정점 중 dist 가 가장 작은 정점을 처음부터 훑어서 찾아라.
}

@Hint {
고른 정점을 확정(done = true)한 다음, 그 인접 리스트를 돌며 dist[u] + w < dist[v] 일 때만 dist[v] 를 갱신해라.
}

@Hint {
더 이상 도달 가능한 미확정 정점이 없으면(최솟값이 여전히 무한대면) 그쯤에서 멈춰도 된다.
}
}

@Quiz(id: dijkstra-quiz, answer: greedy-breaks) {
@Question {
간선 가중치에 음수가 하나라도 있으면 다익스트라가 틀린 답을 낼 수 있다. 그 이유로 가장 알맞은 것은?
}

@Choice(id: greedy-breaks) {
거리가 가장 짧다고 확정한 정점이, 나중에 음수 간선을 거쳐 오면 오히려 더 짧아질 수 있기 때문이다
}

@Choice(id: overflow) {
음수를 u32 에 저장할 수 없어서 프로그램이 죽기 때문이다
}

@Choice(id: no-path) {
음수 가중치 간선이 있으면 그 정점에 아예 도달할 수 없기 때문이다
}

@Explanation {
다익스트라는 '미확정 정점 중 가장 짧은 거리는 더 줄어들 수 없다'는 전제로 확정한다. 가중치가 모두 0 이상이면 다른 경로를 더 가봐야 거리만 늘어나므로 이 전제가 성립한다. 음수 간선이 있으면 나중에 그 간선을 타고 거리가 오히려 줄어들 수 있어 이 전제가 깨진다.
}
}

@Reflection(id: dijkstra-reflection) {
@Prompt(id: vs-bfs) {
모든 간선의 가중치가 1이라면 다익스트라와 BFS는 같은 결과를 낸다. 이 둘이 정점을 고르는 방식이 왜 결국 같아지는지 설명해 보세요.
}

@Prompt(id: on_squared) {
정점이 10만 개라면 O(V²) 방식은 감당하기 어렵다. 우선순위 큐를 쓰면 무엇이 더 빨라질지, 어느 연산이 바뀌는지 짐작해 적어 보세요.
}
}
