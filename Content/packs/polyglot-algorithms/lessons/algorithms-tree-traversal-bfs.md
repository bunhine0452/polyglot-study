@Concept(id: tree-traversal-bfs-concept) {
전위·중위·후위는 모두 재귀로 '한쪽 서브트리를 끝까지 파고든 다음' 다른 쪽으로 넘어갔다. 루트 -> 왼쪽 서브트리 전체 -> 오른쪽 서브트리 전체 같은 식으로, 깊이 방향으로 움직인다는 점에서 셋 다 DFS다.

레벨 순회(level order)는 다르다. 루트를 본 다음, 그 자식들을 모두 본 다음, 그다음 층을 모두 보는 식으로 **위에서 아래로, 같은 층끼리 먼저** 훑는다. 그래프의 BFS를 트리에 그대로 적용한 것이다.

BFS와 마찬가지로 큐를 쓴다. 루트를 큐에 넣고 시작해서, 큐에서 하나를 꺼내 값을 기록하고 그 자식들을 큐 끝에 넣는 것을 반복한다. 큐는 먼저 들어온 게 먼저 나가므로 (FIFO), 얕은 정점이 항상 깊은 정점보다 먼저 나온다.

결과를 층별로 묶고 싶다면 요령이 하나 필요하다. 한 층을 처리하기 **직전에** 큐의 길이를 재 두면, 그 개수만큼이 정확히 지금 층이다. 그 개수만큼만 꺼내고 (꺼내면서 생기는 자식들은 다음 층이니 큐에 남겨 두고) 나면 한 층이 끝난다.

재귀 기반 순회와 큐 기반 순회는 방문 순서 자체가 다르다. 전위 순회는 루트 -> 왼쪽 서브트리 전부 -> 오른쪽 서브트리 전부이니 같은 층이라도 서로 멀리 떨어져 나올 수 있다. 레벨 순회는 언제나 얕은 정점부터, 같은 깊이는 왼쪽에서 오른쪽 순서로 나온다.

@Visualize(id: tree-traversal-bfs, frames: visuals/tree-traversal-bfs.json) {
트리의 레벨 순회가 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: tree-traversal-bfs-example, language: rust, expected: expected/algorithms-tree-traversal-bfs.txt) {
큐 길이를 층 경계로 삼아, 트리를 한 층씩 방문하며 찍어 본다.

```rust
use std::collections::VecDeque;

struct Node {
    val: i32,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn leaf(val: i32) -> Option<Box<Node>> {
    Some(Box::new(Node { val, left: None, right: None }))
}

fn branch(val: i32, left: Option<Box<Node>>, right: Option<Box<Node>>) -> Option<Box<Node>> {
    Some(Box::new(Node { val, left, right }))
}

fn main() {
    //        1
    //      /   \
    //     2     3
    //    / \     \
    //   4   5     6
    let tree = branch(1, branch(2, leaf(4), leaf(5)), branch(3, None, leaf(6)));

    let mut queue: VecDeque<&Node> = VecDeque::new();
    if let Some(node) = &tree {
        queue.push_back(node);
    }

    let mut level = 0;
    while !queue.is_empty() {
        let count = queue.len(); // 지금 큐에 있는 것이 전부 이번 층이다
        let mut values = Vec::new();
        for _ in 0..count {
            let node = queue.pop_front().unwrap();
            values.push(node.val);
            if let Some(left) = &node.left {
                queue.push_back(left);
            }
            if let Some(right) = &node.right {
                queue.push_back(right);
            }
        }
        println!("{}층: {:?}", level, values);
        level += 1;
    }
}
```
}

@Blank(id: tree-traversal-bfs-blank, language: rust) {
큐는 넣은 순서대로 꺼내야 얕은 정점부터 방문된다(FIFO). 자식은 push_back 으로 뒤에 넣었다 — 꺼낼 때는 어느 쪽에서 꺼내야 할까?

```rust
use std::collections::VecDeque;

struct Node {
    val: i32,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn level_order(root: &Option<Box<Node>>) -> Vec<i32> {
    let mut out = Vec::new();
    let mut queue: VecDeque<&Node> = VecDeque::new();
    if let Some(node) = root {
        queue.push_back(node);
    }
    while let Some(node) = queue.___1___() {
        out.push(node.val);
        if let Some(left) = &node.left {
            queue.push_back(left);
        }
        if let Some(right) = &node.right {
            queue.push_back(right);
        }
    }
    out
}

fn main() {
    let tree = Some(Box::new(Node {
        val: 1,
        left: Some(Box::new(Node { val: 2, left: None, right: None })),
        right: Some(Box::new(Node { val: 3, left: None, right: None })),
    }));
    println!("{:?}", level_order(&tree));
}
```

@Answer(slot: 1) {
`pop_front`
}
}

@Task(id: tree-traversal-bfs-task, language: rust, starter: starters/algorithms-tree-traversal-bfs.rs, tests: tests/algorithms-tree-traversal-bfs.rs, solution: solutions/algorithms-tree-traversal-bfs.rs) {
`Node { val: i32, left: Option<Box<Node>>, right: Option<Box<Node>> }` 로 표현한 이진 트리를 레벨 순회하되, 층마다 값을 따로 묶어 `Vec<Vec<i32>>` 로 돌려주는 `level_order(root: &Option<Box<Node>>) -> Vec<Vec<i32>>` 를 작성하세요. 바깥 벡터의 각 원소가 한 층의 값들(왼쪽에서 오른쪽 순서)입니다.

@Hint {
빈 트리면 큐에 아무것도 넣지 않는다 — 결과는 자연히 빈 벡터가 된다.
}

@Hint {
while 큐가 비지 않은 동안: 지금 큐의 길이(count)를 먼저 재 두고, 그 수만큼만 꺼내라. 꺼내며 넣는 자식은 다음 층이라 이번 count 에 포함되면 안 된다.
}

@Hint {
한 층 처리가 끝나면 그동안 모은 값들을 바깥 결과 벡터에 통째로 추가해라.
}
}

@Quiz(id: tree-traversal-bfs-quiz, answer: different-order) {
@Question {
노드가 3개인 트리 — 루트 1, 왼쪽 자식 2, 오른쪽 자식 3 — 를 전위 순회한 결과와 레벨 순회한 결과를 비교하면?
}

@Choice(id: same) {
[1, 2, 3]으로 둘 다 같다
}

@Choice(id: different-order) {
전위는 [1, 2, 3], 레벨 순회도 [1, 2, 3]이지만 큐를 도는 방식 자체는 다르다
}

@Choice(id: always-differ) {
노드 배치와 상관없이 전위와 레벨 순회는 항상 서로 다른 순서가 나온다
}

@Explanation {
이 트리처럼 얕은 층만 있으면 전위 순회(루트, 왼쪽, 오른쪽)와 레벨 순회(층 단위) 결과가 우연히 같게 나올 수 있다. 하지만 둘은 서로 다른 방식(재귀로 깊이 파고들기 vs 큐로 층 단위로 훑기)으로 도달한 결과라, 층이 여러 개고 자식이 불균형하게 뻗은 트리에서는 순서가 갈린다.
}
}

@Reflection(id: tree-traversal-bfs-reflection) {
@Prompt(id: when-level-matters) {
트리의 각 층을 따로 알아야 하는 상황을 하나 떠올려 보세요 (예: 트리 모양을 화면에 층별로 그리기). 왜 전위·중위·후위 순회만으로는 그 정보를 바로 얻기 어려운가요?
}

@Prompt(id: queue-vs-recursion) {
레벨 순회는 큐를, 재귀 기반 순회는 함수 호출 스택을 쓴다는 점에서 DFS와 BFS가 그래프에서 그랬던 것과 닮았습니다. 이 둘의 방문 순서가 근본적으로 왜 다른지, 자료구조(큐 vs 스택)의 차이로 설명해 보세요.
}
}
