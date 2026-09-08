pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn height(root: &Option<Box<Node>>) -> i32 {
    match root {
        None => -1,
        Some(node) => 1 + height(&node.left).max(height(&node.right)),
    }
}
