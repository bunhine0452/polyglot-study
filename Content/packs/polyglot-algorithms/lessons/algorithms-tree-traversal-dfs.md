@Concept(id: tree-traversal-dfs-concept) {
트리의 모든 값을 훑고 싶다. 그런데 트리는 배열과 달리 '다음 값'이 하나로 정해져 있지 않다 — 한 노드에 왼쪽 자식도 있고 오른쪽 자식도 있으니, 루트를 언제 볼지, 왼쪽과 오른쪽 중 뭘 먼저 볼지를 정해야 한다. 그 정하기 나름으로 세 가지 표준 순서가 생긴다.

**전위 순회(preorder)**: 루트 -> 왼쪽 -> 오른쪽. 노드를 만나자마자 값을 기록하고 자식으로 내려간다. 트리를 그대로 복사해서 다시 만들 때(부모를 자식보다 먼저 알아야 하니까) 유용하다.

**중위 순회(inorder)**: 왼쪽 -> 루트 -> 오른쪽. 왼쪽을 다 보고 나서야 자기 자신을 기록한다. 다음 레슨에서 만들 이진 탐색 트리 — 왼쪽 서브트리는 더 작은 값, 오른쪽은 더 큰 값 — 에 이 순서를 적용하면, 항상 작은 값부터 큰 값 순서로 나온다. 왼쪽(더 작은 값들)을 전부 본 다음 자신을, 그다음 오른쪽(더 큰 값들)을 보니까 오름차순이 될 수밖에 없다.

**후위 순회(postorder)**: 왼쪽 -> 오른쪽 -> 루트. 자식을 모두 본 다음에야 자기 자신을 기록한다. 노드를 삭제하거나 트리 크기를 셀 때, 자식의 결과가 필요한 계산에 유용하다 — 실제로 사이클 탐지·위상 정렬에서 본 '완료 순서'가 바로 후위 순회였다.

셋 다 코드 모양은 거의 같다. 재귀 호출 두 번(왼쪽, 오른쪽)과 '지금 노드를 기록한다'는 동작 하나를 어떤 순서로 배치하느냐만 다르다. 재귀 호출 자체는 항상 '왼쪽 먼저, 오른쪽 다음'이고, 기록하는 위치만 앞/중간/뒤로 옮겨 다닌다.
}

@Example(id: tree-traversal-dfs-example, language: rust, expected: expected/algorithms-tree-traversal-dfs.txt) {
같은 트리를 전위·중위·후위로 각각 훑어, 방문 순서가 어떻게 달라지는지 비교한다.

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

fn preorder(root: &Option<Box<Node>>, out: &mut Vec<i32>) {
    if let Some(node) = root {
        out.push(node.val); // 루트 먼저
        preorder(&node.left, out);
        preorder(&node.right, out);
    }
}

fn inorder(root: &Option<Box<Node>>, out: &mut Vec<i32>) {
    if let Some(node) = root {
        inorder(&node.left, out);
        out.push(node.val); // 왼쪽을 다 본 다음 루트
        inorder(&node.right, out);
    }
}

fn postorder(root: &Option<Box<Node>>, out: &mut Vec<i32>) {
    if let Some(node) = root {
        postorder(&node.left, out);
        postorder(&node.right, out);
        out.push(node.val); // 양쪽을 다 본 다음 루트
    }
}

fn main() {
    //        1
    //      /   \
    //     2     3
    //    / \
    //   4   5
    let tree = branch(1, branch(2, leaf(4), leaf(5)), leaf(3));

    let mut pre = Vec::new();
    preorder(&tree, &mut pre);
    println!("전위: {:?}", pre);

    let mut ino = Vec::new();
    inorder(&tree, &mut ino);
    println!("중위: {:?}", ino);

    let mut post = Vec::new();
    postorder(&tree, &mut post);
    println!("후위: {:?}", post);
}
```
}

@Blank(id: tree-traversal-dfs-blank, language: rust) {
중위 순회는 왼쪽을 다 본 다음, 오른쪽을 보기 전에 자기 자신을 기록한다. 무엇을 채워야 할까?

```rust
struct Node {
    val: i32,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn inorder(root: &Option<Box<Node>>, out: &mut Vec<i32>) {
    if let Some(node) = root {
        inorder(&node.left, out);
        ___1___;
        inorder(&node.right, out);
    }
}

fn main() {
    let tree = Some(Box::new(Node {
        val: 2,
        left: Some(Box::new(Node { val: 1, left: None, right: None })),
        right: Some(Box::new(Node { val: 3, left: None, right: None })),
    }));
    let mut out = Vec::new();
    inorder(&tree, &mut out);
    println!("{:?}", out);
}
```

@Answer(slot: 1) {
`out.push(node.val)`
}
}

@Task(id: tree-traversal-dfs-task, language: rust, starter: starters/algorithms-tree-traversal-dfs.rs, tests: tests/algorithms-tree-traversal-dfs.rs, solution: solutions/algorithms-tree-traversal-dfs.rs) {
`Node { val: i32, left: Option<Box<Node>>, right: Option<Box<Node>> }` 로 표현한 이진 트리를 후위 순회(왼쪽 -> 오른쪽 -> 루트)한 결과를 `Vec<i32>` 로 돌려주는 `postorder(root: &Option<Box<Node>>) -> Vec<i32>` 를 작성하세요.

@Hint {
빈 트리(None)면 아무것도 기록하지 않는다 — 이것이 재귀의 기저 조건이다.
}

@Hint {
왼쪽 서브트리를 재귀로 먼저 훑고, 그다음 오른쪽 서브트리를 재귀로 훑어라.
}

@Hint {
양쪽을 다 훑은 뒤에야 지금 노드의 값을 결과에 추가해라 — 순서가 이름 그대로 '후위'다.
}
}

@Quiz(id: tree-traversal-dfs-quiz, answer: left-root-right) {
@Question {
이진 탐색 트리(왼쪽 서브트리는 더 작은 값, 오른쪽은 더 큰 값)를 중위 순회하면 항상 오름차순이 나온다. 그 이유로 가장 알맞은 것은?
}

@Choice(id: left-root-right) {
왼쪽(더 작은 값들)을 전부 본 다음 자신을, 그다음 오른쪽(더 큰 값들)을 보는 순서이기 때문이다
}

@Choice(id: sorted-input) {
애초에 정렬된 배열로만 트리를 만들 수 있기 때문이다
}

@Choice(id: root-first) {
루트를 항상 먼저 기록해서 가장 작은 값이 맨 앞에 오기 때문이다
}

@Explanation {
중위 순회는 왼쪽 -> 루트 -> 오른쪽 순서다. 이진 탐색 트리에서 왼쪽 서브트리에는 지금 노드보다 작은 값만, 오른쪽 서브트리에는 큰 값만 있으므로 '작은 값들 -> 지금 값 -> 큰 값들' 순서가 되고, 이걸 재귀적으로 반복하면 전체가 오름차순이 된다.
}
}

@Reflection(id: tree-traversal-dfs-reflection) {
@Prompt(id: same-tree-different-order) {
예제의 트리에서 전위·중위·후위 결과가 서로 다른 순서로 나왔습니다. 세 순서 중 어느 것을 쓸지가 실제로 중요해지는 상황을 하나 떠올려 적어 보세요 — 순서가 달라지면 왜 문제가 되나요?
}

@Prompt(id: postorder-use-case) {
지난 사이클 탐지·위상 정렬 레슨에서 '정점을 완료 처리하는 순간'을 기록한 것이 사실 후위 순회였습니다. 후위 순회가 '자식의 결과가 먼저 필요한' 계산에 왜 자연스럽게 맞는지 설명해 보세요.
}
}
