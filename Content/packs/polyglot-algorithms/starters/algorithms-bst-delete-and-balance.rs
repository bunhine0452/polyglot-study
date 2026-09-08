pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn insert(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>> {
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

pub fn delete(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>> {
    // 자식이 0개: 그 자리를 None 으로.
    // 자식이 1개: 그 자식이 대신 그 자리를 차지한다.
    // 자식이 2개: 오른쪽 서브트리에서 가장 작은 값(중위 후속자)을 찾아 val 자리에
    // 넣고, 오른쪽 서브트리에서는 그 후속자를 다시 지운다.
    unimplemented!("여기를 구현해라")
}
