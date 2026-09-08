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
