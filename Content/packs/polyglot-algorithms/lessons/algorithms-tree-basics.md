@Concept(id: tree-basics-concept) {
그래프 중에서도 사이클이 없고, 모든 정점이 연결된 것을 트리라고 부른다. 정점이 N개면 간선은 정확히 N-1개다 — 하나라도 더 있으면 어딘가 사이클이 생기고, 하나라도 적으면 어딘가 끊어진다.

트리는 보통 한 정점을 특별하게 취급해서 그린다. 그 정점이 루트(root)다. 루트에서 출발해 간선을 하나 건너면 자식(child)이고, 그 반대 방향에서 보면 부모(parent)다. 자식이 하나도 없는 정점이 리프(leaf)다. 루트에서 어떤 정점까지 몇 번 간선을 건너야 하는지가 그 정점의 깊이이고, 트리 전체에서 가장 깊은 리프까지의 간선 수가 트리의 높이(height)다. 리프 하나만 있는 트리(정점 하나)의 높이는 0, 정점이 하나도 없는 빈 트리는 편의상 -1로 둔다 — 그래야 '리프 하나짜리 트리 = 자식 트리 두 개가 모두 빈 트리인 트리'라는 재귀 공식이 자연스럽게 맞아떨어진다.

각 정점이 자식을 최대 둘까지만 가지고, 그 둘을 왼쪽/오른쪽으로 구분하는 트리를 이진 트리(binary tree)라고 한다. 자식 수를 둘로 제한하면 구현이 훨씬 단순해지고, 다음 레슨들에서 볼 순회·탐색이 전부 '왼쪽을 볼까, 오른쪽을 볼까'라는 하나의 질문으로 정리된다.

Rust에서 이진 트리는 노드 구조체와 `Option<Box<Node>>` 로 표현한다. `Box` 는 힙에 노드를 두고 그 자리를 가리키는 포인터를 저장한다 — 이게 없으면 `Node` 안에 `Node` 를 담는 셈이라 컴파일러가 타입의 크기를 정할 수 없다. `Option` 은 자식이 없을 수 있다는 것, 즉 `None` 이 바로 '거기서 트리가 끝난다'는 뜻이 된다.

@Visualize(id: tree-basics, frames: visuals/tree-basics.json) {
트리 표현이 어떻게 도는지 한 단계씩 봅니다.
}
}

@Example(id: tree-basics-example, language: rust, expected: expected/algorithms-tree-basics.txt) {
작은 이진 트리를 노드와 포인터로 만들고, 루트 값·높이·리프 개수를 확인한다.

```rust
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

fn height(root: &Option<Box<Node>>) -> i32 {
    match root {
        None => -1,
        Some(node) => 1 + height(&node.left).max(height(&node.right)),
    }
}

fn count_leaves(root: &Option<Box<Node>>) -> i32 {
    match root {
        None => 0,
        Some(node) if node.left.is_none() && node.right.is_none() => 1,
        Some(node) => count_leaves(&node.left) + count_leaves(&node.right),
    }
}

fn main() {
    //        1
    //      /   \
    //     2     3
    //    / \
    //   4   5
    let tree = branch(1, branch(2, leaf(4), leaf(5)), leaf(3));

    if let Some(root) = &tree {
        println!("루트 값: {}", root.val);
    }
    println!("높이: {}", height(&tree));
    println!("리프 개수: {}", count_leaves(&tree));
}
```
}

@Blank(id: tree-basics-blank, language: rust) {
리프는 왼쪽 자식도, 오른쪽 자식도 없는 노드다. 왼쪽이 없다는 건 이미 확인했다 — 오른쪽이 없다는 건 어떻게 확인할까?

```rust
struct Node {
    val: i32,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn count_leaves(root: &Option<Box<Node>>) -> i32 {
    match root {
        None => 0,
        Some(node) if node.left.is_none() && node.right.___1___() => 1,
        Some(node) => count_leaves(&node.left) + count_leaves(&node.right),
    }
}

fn main() {
    let tree = Some(Box::new(Node {
        val: 1,
        left: Some(Box::new(Node { val: 2, left: None, right: None })),
        right: Some(Box::new(Node { val: 3, left: None, right: None })),
    }));
    println!("{}", count_leaves(&tree));
}
```

@Answer(slot: 1) {
`is_none`
}
}

@Task(id: tree-basics-task, language: rust, starter: starters/algorithms-tree-basics.rs, tests: tests/algorithms-tree-basics.rs, solution: solutions/algorithms-tree-basics.rs) {
`Node { val: i32, left: Option<Box<Node>>, right: Option<Box<Node>> }` 로 표현한 이진 트리의 높이를 구하는 `height(root: &Option<Box<Node>>) -> i32` 를 작성하세요. 빈 트리(`None`)의 높이는 -1, 리프 하나만 있는 트리의 높이는 0으로 둡니다.

@Hint {
root 가 None 이면 -1을 돌려줘라 — 이것이 재귀의 기저 조건이다.
}

@Hint {
root 가 Some(node) 면, 왼쪽 서브트리의 높이와 오른쪽 서브트리의 높이를 각각 재귀로 구해라.
}

@Hint {
두 서브트리 높이 중 더 큰 값에 1을 더한 것이 이 노드의 높이다 — i32 에는 max 메서드가 있다.
}
}

@Quiz(id: tree-basics-quiz, answer: six) {
@Question {
정점이 7개인 트리가 있다면 간선은 몇 개일까?
}

@Choice(id: six) {
6개
}

@Choice(id: seven) {
7개
}

@Choice(id: depends) {
트리 모양에 따라 다르다
}

@Explanation {
트리는 사이클 없이 모든 정점이 연결된 그래프라서, 정점이 N개면 간선은 항상 정확히 N-1개다. 트리가 옆으로 퍼졌든 한 줄로 늘어졌든 모양과 무관하게 성립한다.
}
}

@Reflection(id: tree-basics-reflection) {
@Prompt(id: why-acyclic) {
그래프에 사이클이 하나 있다면 그건 트리가 아니다. 사이클이 있는 그래프에서 '부모'라는 개념이 왜 명확하게 정의되지 않는지 예를 들어 설명해 보세요.
}

@Prompt(id: why-option-box) {
`left: Option<Box<Node>>` 대신 `left: Node` 라고 필드를 선언하면 컴파일이 안 됩니다. `Option` 과 `Box` 가 각각 어떤 문제를 해결하는지 자기 말로 정리해 보세요.
}
}
