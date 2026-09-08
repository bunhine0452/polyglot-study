@Concept(id: bst-concept) {
이진 탐색을 배열이 아니라 트리로 옮기면 어떻게 될까? 규칙은 하나다 — 모든 노드에서, **왼쪽 서브트리에는 그 노드보다 작은 값만, 오른쪽 서브트리에는 큰 값만** 있다. 이 규칙 하나가 트리 전체에 재귀적으로 적용되는 것이 이진 탐색 트리(BST)다.

**탐색**은 이 규칙을 그대로 따라간다. 찾는 값이 지금 노드보다 작으면 왼쪽으로, 크면 오른쪽으로 내려간다. 같으면 찾은 것이다. 자식이 없는 곳까지 내려갔는데도 못 찾았으면 그 값은 트리에 없다. 이진 탐색에서 배열의 절반을 버렸듯, 여기서는 서브트리 하나를 통째로 버린다.

**삽입**도 같은 규칙으로 자리를 찾는다. 탐색하듯 내려가다가 자식이 없는 자리(None)를 만나면, 거기가 새 값이 들어갈 자리다. Rust에서는 트리를 값으로 소유해 재귀 호출마다 '왼쪽 서브트리를 삽입한 새 트리로 바꿔치기'하는 방식이 자연스럽다 — `node.left = insert(node.left, val)` 처럼, 자식 자리를 삽입 결과로 다시 채워 넣는다.

탐색이든 삽입이든, 한 번 비교할 때마다 한 층 내려간다. 그러니 시간복잡도는 정점 수가 아니라 **트리의 높이**에 달려 있다 — O(높이). 값을 고르게 섞어 넣으면 높이가 log n 근처로 유지돼 이진 탐색만큼 빠르다. 하지만 값을 정렬된 순서로 그대로 넣으면 트리가 한쪽으로만 뻗어 높이가 n이 되고, 결국 배열을 순서대로 훑는 것과 다를 게 없어진다. 이 문제는 다음 레슨에서 직접 확인한다.
}

@Example(id: bst-example, language: rust, expected: expected/algorithms-bst.txt) {
값을 하나씩 삽입해 BST를 만들고, 중위 순회로 정렬 여부를, contains 로 탐색 결과를 확인한다.

```rust
struct Node {
    val: i32,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn insert(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>> {
    match root {
        None => Some(Box::new(Node { val, left: None, right: None })),
        Some(mut node) => {
            if val < node.val {
                node.left = insert(node.left, val);
            } else if val > node.val {
                node.right = insert(node.right, val);
            }
            // 같은 값이면 그대로 둔다 (중복 무시)
            Some(node)
        }
    }
}

fn contains(root: &Option<Box<Node>>, val: i32) -> bool {
    match root {
        None => false,
        Some(node) => {
            if val == node.val {
                true
            } else if val < node.val {
                contains(&node.left, val)
            } else {
                contains(&node.right, val)
            }
        }
    }
}

fn inorder(root: &Option<Box<Node>>, out: &mut Vec<i32>) {
    if let Some(node) = root {
        inorder(&node.left, out);
        out.push(node.val);
        inorder(&node.right, out);
    }
}

fn main() {
    let mut tree = None;
    for v in [5, 3, 8, 1, 4, 7, 9] {
        tree = insert(tree, v);
    }

    let mut sorted = Vec::new();
    inorder(&tree, &mut sorted);
    println!("중위 순회(오름차순): {:?}", sorted);

    for target in [4, 6] {
        println!("{} 있음: {}", target, contains(&tree, target));
    }
}
```
}

@Blank(id: bst-blank, language: rust) {
찾는 값이 지금 노드보다 크면 어느 쪽 서브트리로 내려가야 할까?

```rust
struct Node {
    val: i32,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn contains(root: &Option<Box<Node>>, val: i32) -> bool {
    match root {
        None => false,
        Some(node) => {
            if val == node.val {
                true
            } else if val < node.val {
                contains(&node.left, val)
            } else {
                contains(&___1___, val)
            }
        }
    }
}

fn main() {
    let tree = Some(Box::new(Node {
        val: 5,
        left: Some(Box::new(Node { val: 3, left: None, right: None })),
        right: Some(Box::new(Node { val: 8, left: None, right: None })),
    }));
    println!("{}", contains(&tree, 8));
}
```

@Answer(slot: 1) {
`node.right`
}
}

@Task(id: bst-task, language: rust, starter: starters/algorithms-bst.rs, tests: tests/algorithms-bst.rs, solution: solutions/algorithms-bst.rs) {
`Node { val: i32, left: Option<Box<Node>>, right: Option<Box<Node>> }` 로 표현한 이진 탐색 트리에 값을 삽입하는 `insert(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>>` 를 작성하세요. 트리를 값으로 받아 새 트리를 돌려주는 방식입니다 (`tree = insert(tree, v)` 처럼 씁니다). 이미 있는 값을 다시 삽입하면 트리는 바뀌지 않아야 합니다.

@Hint {
root 가 None 이면 val 하나짜리 새 리프를 Some 으로 감싸 돌려줘라.
}

@Hint {
root 가 Some(node) 면 val 과 node.val 을 비교해 왼쪽 또는 오른쪽으로 재귀 호출하고, 그 결과를 node.left 나 node.right 에 다시 대입해라.
}

@Hint {
val 이 node.val 과 같으면 아무것도 바꾸지 않고 node 를 그대로 돌려줘라 — 중복은 무시한다.
}
}

@Quiz(id: bst-quiz, answer: height) {
@Question {
값 10개를 이진 탐색 트리에 넣었다. 탐색 한 번의 비교 횟수는 무엇에 달려 있을까?
}

@Choice(id: height) {
트리의 높이 — 값이 골고루 퍼져 있으면 적고, 한쪽으로 치우치면 많다
}

@Choice(id: count) {
정점 개수(10) 그 자체 — 항상 최대 10번 비교한다
}

@Choice(id: constant) {
트리 모양과 무관하게 항상 log 10번쯤 비교한다
}

@Explanation {
탐색은 비교할 때마다 한 층 내려가므로, 최악의 비교 횟수는 정점 개수가 아니라 트리의 높이로 결정된다. 값이 고르게 섞여 들어가면 높이가 log n 근처이지만, 한쪽으로 치우쳐 삽입되면 높이가 n에 가까워질 수 있다.
}
}

@Reflection(id: bst-reflection) {
@Prompt(id: own-tree-vs-inplace) {
`insert` 는 트리를 값으로 받아 새 트리를 돌려주는 방식(`node.left = insert(node.left, val)`)을 씁니다. 만약 `&mut Option<Box<Node>>` 처럼 가변 참조로 제자리에서 바꾸는 방식이었다면 코드가 어떻게 달라질지 짐작해 보세요.
}

@Prompt(id: search-vs-insert) {
탐색(contains)과 삽입(insert)의 코드는 '왼쪽으로 갈까 오른쪽으로 갈까'를 정하는 부분이 거의 똑같습니다. 그런데도 둘을 하나로 합치지 않고 따로 두는 이유가 뭘지 생각해 보세요.
}
}
