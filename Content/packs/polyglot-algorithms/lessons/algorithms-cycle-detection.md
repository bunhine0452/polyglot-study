@Concept(id: cycle-detection-concept) {
그래프에 사이클이 있는지 어떻게 알 수 있을까? DFS로 정점을 방문하면서, "이미 본 정점을 다시 만났다"는 것만으로는 부족하다.

0 -> 1, 0 -> 2, 1 -> 3, 2 -> 3 처럼 생긴 그래프를 생각해 보자. 3은 1을 거쳐서도, 2를 거쳐서도 도달한다. 사이클은 없지만 3은 두 번 방문된다. 방문 여부만 보고 "두 번째 방문 = 사이클"이라 판단하면 이 그래프도 사이클이 있다고 오판한다.

진짜 문제는 **지금 파고들고 있는 경로 위에** 그 정점이 있느냐다. 3은 1의 자식으로 방문을 마치고 완료된 뒤에 2를 거쳐 다시 나타난다 — 완료된 정점이니 문제없다. 반면 0 -> 1 -> 2 -> 0 처럼 아직 방문이 끝나지 않은, 즉 지금 경로 위에 있는 0으로 되돌아가는 간선을 만나면 그게 사이클이다.

그래서 상태를 셋으로 나눈다. **미방문**(아직 안 봄), **방문 중**(지금 이 정점에서 시작한 DFS가 아직 안 끝남 — 현재 경로 위에 있음), **방문 완료**(이 정점 아래는 다 탐색이 끝남). 이웃이 방문 중 상태면 역방향 간선(back edge)이고, 이것이 사이클의 증거다. 이웃이 방문 완료 상태면 그냥 다른 경로에서 이미 처리된 것뿐이니 지나쳐도 된다.

무방향 그래프에서는 이 규칙을 그대로 쓰면 안 된다. 정점 u에서 v로 갔다가, v에서 다시 u를 보는 간선은 방금 타고 온 그 간선을 반대로 보는 것뿐이다. u는 아직 방문 중이니 매번 사이클로 잡힌다. 그래서 무방향 그래프에서는 방금 온 부모 정점만은 예외로 두고 검사해야 한다.

@Visualize(id: cycle-detection, frames: visuals/cycle-detection.json) {
사이클 탐지가 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: cycle-detection-example, language: rust, expected: expected/algorithms-cycle-detection.txt) {
정점을 진입/완료할 때마다 찍어서, 역방향 간선이 어디서 발견되는지 본다.

```rust
fn main() {
    let adj: Vec<Vec<usize>> = vec![
        vec![1],
        vec![2],
        vec![0, 3],
        vec![],
    ];
    let n = adj.len();
    let mut state = vec![0u8; n]; // 0: 미방문, 1: 방문 중, 2: 방문 완료
    let mut has_cycle = false;

    for start in 0..n {
        if state[start] == 0 {
            visit(start, &adj, &mut state, &mut has_cycle);
        }
    }

    println!("사이클 있음: {}", has_cycle);
}

fn visit(u: usize, adj: &Vec<Vec<usize>>, state: &mut Vec<u8>, has_cycle: &mut bool) {
    state[u] = 1;
    println!("진입 {}", u);
    for &v in &adj[u] {
        if state[v] == 1 {
            println!("역방향 간선 발견: {} -> {}", u, v);
            *has_cycle = true;
        } else if state[v] == 0 {
            visit(v, adj, state, has_cycle);
        }
    }
    state[u] = 2;
    println!("완료 {}", u);
}
```
}

@Blank(id: cycle-detection-blank, language: rust) {
이웃 정점 v의 state가 어떤 값일 때 역방향 간선 — 즉 사이클 — 이라고 판단해야 할까?

```rust
fn has_cycle(adj: &Vec<Vec<usize>>) -> bool {
    let n = adj.len();
    let mut state = vec![0u8; n];

    fn visit(u: usize, adj: &Vec<Vec<usize>>, state: &mut Vec<u8>) -> bool {
        state[u] = 1;
        for &v in &adj[u] {
            if state[v] == ___1___ {
                return true;
            }
            if state[v] == 0 && visit(v, adj, state) {
                return true;
            }
        }
        state[u] = 2;
        false
    }

    for start in 0..n {
        if state[start] == 0 && visit(start, adj, &mut state) {
            return true;
        }
    }
    false
}

fn main() {
    let adj: Vec<Vec<usize>> = vec![vec![1], vec![2], vec![0]];
    println!("{}", has_cycle(&adj));
}
```

@Answer(slot: 1) {
`1`
}
}

@Task(id: cycle-detection-task, language: rust, starter: starters/algorithms-cycle-detection.rs, tests: tests/algorithms-cycle-detection.rs, solution: solutions/algorithms-cycle-detection.rs) {
방향 그래프를 인접 리스트 `&Vec<Vec<usize>>` 로 받아, 사이클이 있으면 `true`, 없으면 `false` 를 돌려주는 `has_cycle` 을 작성하세요. 그래프는 여러 컴포넌트로 나뉘어 있을 수 있으니 모든 정점을 시작점으로 시도해야 합니다.

@Hint {
state 배열로 미방문/방문 중/방문 완료를 구분해라. 방문 중인 정점을 다시 가리키는 간선이 역방향 간선이다.
}

@Hint {
정점 하나의 방문을 마치면 state 를 방문 완료로 바꿔야, 다른 경로에서 다시 만나도 사이클로 오인하지 않는다.
}

@Hint {
그래프가 여러 컴포넌트로 나뉠 수 있다 — 모든 정점을 순회하며 아직 미방문인 정점에서 새로 DFS 를 시작해라.
}
}

@Quiz(id: cycle-detection-quiz, answer: finished) {
@Question {
0 -> 1, 0 -> 2, 1 -> 3, 2 -> 3 로 이루어진 방향 그래프를 DFS로 훑는다. 3을 두 번째로 만났을 때, 왜 사이클이 아니라고 판단할 수 있을까?
}

@Choice(id: finished) {
3은 이미 방문 완료 상태이지, 지금 경로 위(방문 중)에 있는 게 아니기 때문이다
}

@Choice(id: index) {
3의 번호가 0, 1, 2보다 크기 때문이다
}

@Choice(id: twice) {
정점을 두 번 방문하는 것 자체가 원래 불가능하기 때문이다
}

@Explanation {
사이클 판정의 기준은 '이미 봤는가'가 아니라 '지금 파고드는 경로 위에 있는가'다. 3은 1을 거친 첫 방문에서 이미 방문 완료로 표시됐으므로, 2를 거쳐 다시 만나도 그건 다른 경로에서 끝난 정점을 지나치는 것뿐이다.
}
}

@Reflection(id: cycle-detection-reflection) {
@Prompt(id: undirected) {
무방향 그래프에 이 알고리즘을 그대로 적용하면 간선 하나짜리 그래프(정점 두 개, 간선 하나)마저 사이클이 있다고 나온다. 왜 그런지, 그리고 무엇을 바꿔야 고쳐지는지 적어 보세요.
}

@Prompt(id: two-state) {
상태를 미방문/방문 중/방문 완료 셋이 아니라 미방문/방문 두 가지로만 나눴다면 어떤 그래프에서 잘못된 답을 낼지, 구체적인 예를 들어 설명해 보세요.
}
}
