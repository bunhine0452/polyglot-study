@Concept(id: bst-delete-and-balance-concept) {
삽입은 항상 빈 자리(None)를 찾아 끝냈다. 삭제는 그렇게 간단하지 않다 — 지울 노드가 트리 한가운데 있으면, 그 자리를 누가 대신할지 정해야 한다. 지울 노드의 자식 수에 따라 세 가지 경우로 나뉜다.

**자식이 0개(리프)**: 그냥 그 자리를 None 으로 바꾸면 된다. 아무도 대신할 필요가 없다.

**자식이 1개**: 그 자식이 지울 노드의 자리를 그대로 물려받는다. 지울 노드를 자식으로 치환해도 왼쪽은 여전히 작은 값, 오른쪽은 여전히 큰 값이라는 규칙이 깨지지 않는다.

**자식이 2개**: 왼쪽도 오른쪽도 있으니 둘 중 하나를 그냥 끌어올릴 수 없다 — 그러면 다른 쪽 서브트리가 갈 곳을 잃는다. 대신 **중위 후속자**(inorder successor) — 지울 노드보다 큰 값 중 가장 작은 값 — 로 그 자리를 대신 채운다. 중위 순회에서 지울 노드 바로 다음에 오는 값이기 때문이다. 이 값은 항상 오른쪽 서브트리의 **가장 왼쪽 노드**에 있다 — 오른쪽으로 한 번 간 다음(그러면 지울 노드보다 큰 값들의 영역으로 들어간다), 왼쪽으로 갈 수 있는 데까지 가면 그중 가장 작은 값이 나온다. 후속자 값을 빼 와서 지울 노드의 자리를 채우고, 그다음 오른쪽 서브트리에서 그 후속자를 다시 지운다 — 후속자는 왼쪽 자식이 없다는 게 보장되므로 이 재귀는 항상 자식 0개 또는 1개인 경우로 끝난다.

삽입과 삭제를 반복하다 보면 트리 모양이 입력 순서에 따라 크게 달라진다는 걸 알 수 있다. 값을 무작위로 섞어 넣으면 트리가 옆으로 퍼져 높이가 log n 근처를 유지한다. 반면 값을 **오름차순으로만** 넣으면 모든 값이 직전 값의 오른쪽 자식으로만 들어가 트리가 한 줄로 늘어진다 — 편향 트리(skewed tree)다. 이러면 높이가 n-1이 되고, 탐색·삽입·삭제 모두 O(높이) 였던 것이 O(n)으로 떨어진다. 트리의 모양이 곧 성능인 이유다. 이 문제를 스스로 고치는 트리(레드-블랙 트리, AVL 트리 등 균형 트리)는 이 트랙 뒤에서 다룬다.
}

@Example(id: bst-delete-and-balance-example, language: rust, expected: expected/algorithms-bst-delete-and-balance.txt) {
자식이 0개·1개·2개인 노드를 차례로 지워 보고, 오름차순 삽입이 트리를 어떻게 늘어뜨리는지 높이로 확인한다.

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
            Some(node)
        }
    }
}

fn min_val(node: &Node) -> i32 {
    match &node.left {
        Some(left) => min_val(left),
        None => node.val,
    }
}

fn delete(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>> {
    match root {
        None => None,
        Some(mut node) => {
            if val < node.val {
                node.left = delete(node.left, val);
                Some(node)
            } else if val > node.val {
                node.right = delete(node.right, val);
                Some(node)
            } else {
                match (node.left.take(), node.right.take()) {
                    (None, None) => None,
                    (Some(l), None) => Some(l),
                    (None, Some(r)) => Some(r),
                    (Some(l), Some(r)) => {
                        let successor = min_val(&r);
                        let new_right = delete(Some(r), successor);
                        Some(Box::new(Node { val: successor, left: Some(l), right: new_right }))
                    }
                }
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

fn height(root: &Option<Box<Node>>) -> i32 {
    match root {
        None => -1,
        Some(node) => 1 + height(&node.left).max(height(&node.right)),
    }
}

fn main() {
    let mut tree = None;
    for v in [5, 3, 8, 1, 4, 7, 9] {
        tree = insert(tree, v);
    }
    let mut before = Vec::new();
    inorder(&tree, &mut before);
    println!("삭제 전: {:?}", before);

    // 자식이 0개인 노드(리프) 삭제
    tree = delete(tree, 1);
    let mut after1 = Vec::new();
    inorder(&tree, &mut after1);
    println!("1 삭제 후: {:?}", after1);

    // 자식이 1개인 노드 삭제 (3은 이제 오른쪽 자식 4 하나뿐이다)
    tree = delete(tree, 3);
    let mut after2 = Vec::new();
    inorder(&tree, &mut after2);
    println!("3 삭제 후: {:?}", after2);

    // 자식이 2개인 노드 삭제 (루트 5) — 오른쪽 서브트리의 최솟값(중위 후속자)으로 대체
    tree = delete(tree, 5);
    let mut after3 = Vec::new();
    inorder(&tree, &mut after3);
    println!("5 삭제 후: {:?}", after3);

    // 오름차순으로만 삽입하면 트리가 한 줄로 늘어진다
    let mut skewed = None;
    for v in 1..=7 {
        skewed = insert(skewed, v);
    }
    println!("오름차순 삽입 높이: {}", height(&skewed));

    // 같은 값 7개를 고르게 섞어 넣으면 높이가 훨씬 낮다
    let mut balanced = None;
    for v in [4, 2, 6, 1, 3, 5, 7] {
        balanced = insert(balanced, v);
    }
    println!("고르게 섞어 삽입한 높이: {}", height(&balanced));
}
```
}

@Blank(id: bst-delete-and-balance-blank, language: rust) {
왼쪽 자식은 없고 오른쪽 자식 r만 있는 노드를 지울 때, 그 자리에는 무엇이 남아야 할까?

```rust
struct Node {
    val: i32,
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn delete(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>> {
    match root {
        None => None,
        Some(mut node) => {
            if val < node.val {
                node.left = delete(node.left, val);
                Some(node)
            } else if val > node.val {
                node.right = delete(node.right, val);
                Some(node)
            } else {
                match (node.left.take(), node.right.take()) {
                    (None, None) => None,
                    (Some(l), None) => Some(l),
                    (None, Some(r)) => ___1___,
                    (Some(l), Some(r)) => {
                        fn min_val(node: &Node) -> i32 {
                            match &node.left {
                                Some(left) => min_val(left),
                                None => node.val,
                            }
                        }
                        let successor = min_val(&r);
                        let new_right = delete(Some(r), successor);
                        Some(Box::new(Node { val: successor, left: Some(l), right: new_right }))
                    }
                }
            }
        }
    }
}

fn main() {
    let tree = Some(Box::new(Node {
        val: 5,
        left: None,
        right: Some(Box::new(Node { val: 8, left: None, right: None })),
    }));
    let tree = delete(tree, 5);
    println!("{}", tree.unwrap().val);
}
```

@Answer(slot: 1) {
`Some(r)`
}
}

@Task(id: bst-delete-and-balance-task, language: rust, starter: starters/algorithms-bst-delete-and-balance.rs, tests: tests/algorithms-bst-delete-and-balance.rs, solution: solutions/algorithms-bst-delete-and-balance.rs) {
이진 탐색 트리에서 값을 지우는 `delete(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>>` 를 작성하세요. `insert` 는 이미 주어져 있습니다. 지울 노드의 자식이 0개·1개·2개인 경우를 각각 다르게 처리해야 하고, 자식이 둘이면 오른쪽 서브트리의 최솟값(중위 후속자)으로 대체한 뒤 그 후속자를 오른쪽 서브트리에서 다시 지워야 합니다. 존재하지 않는 값을 지우려 하면 트리는 그대로 두세요.

@Hint {
먼저 지울 노드를 찾아야 한다 — val 이 node.val 보다 작으면 왼쪽, 크면 오른쪽으로 재귀하고, 그 결과를 다시 node.left/node.right 에 대입해라.
}

@Hint {
val 이 node.val 과 같으면 지울 자리를 찾은 것이다. node.left.take() 와 node.right.take() 로 두 자식을 꺼내 (None, None), (Some, None), (None, Some), (Some, Some) 네 가지로 나눠 처리해라.
}

@Hint {
자식이 둘이면, 오른쪽 서브트리에서 왼쪽으로 갈 수 있는 데까지 간 값이 중위 후속자다. 그 값을 지울 노드의 val 자리에 넣고, delete 를 오른쪽 서브트리에 재귀 호출해 후속자를 지워라.
}
}

@Quiz(id: bst-delete-and-balance-quiz, answer: keeps-order) {
@Question {
자식이 둘인 노드를 지울 때 왜 '중위 후속자(오른쪽 서브트리의 최솟값)'로 대체해야 할까?
}

@Choice(id: keeps-order) {
그 값이 지운 노드보다는 크면서 오른쪽 서브트리의 다른 모든 값보다는 작아서, 왼쪽 < 루트 < 오른쪽 규칙이 그대로 유지되기 때문이다
}

@Choice(id: any-value) {
어떤 값으로 대체하든 상관없고, 계산이 간단해서 그렇게 정했을 뿐이다
}

@Choice(id: root-only) {
루트를 지울 때만 이 방법을 쓰고, 다른 노드는 자식 중 하나를 그냥 끌어올리면 되기 때문이다
}

@Explanation {
중위 후속자는 지운 노드보다 큰 값 중 가장 작은 값이다. 왼쪽 서브트리의 모든 값보다는 크고, 오른쪽 서브트리에 남은 모든 값보다는 작으므로, 그 자리에 넣어도 BST의 왼쪽 < 루트 < 오른쪽 규칙이 그대로 유지된다.
}
}

@Reflection(id: bst-delete-and-balance-reflection) {
@Prompt(id: predecessor-alternative) {
자식이 둘인 노드를 지울 때, 중위 후속자(오른쪽 서브트리의 최솟값) 대신 중위 선행자(왼쪽 서브트리의 최댓값)로 대체해도 될까요? 왜 그런지 설명해 보세요.
}

@Prompt(id: skewed-tree-fix) {
오름차순으로만 값을 넣어 트리가 한 줄로 늘어졌습니다. 트리를 처음부터 다시 만들지 않고, 이미 늘어진 트리를 다시 균형 잡히게 만들려면 무엇이 필요할지 짐작해 적어 보세요 (힌트: 지금까지 배운 회전 없는 삽입·삭제만으로는 부족하다).
}
}
