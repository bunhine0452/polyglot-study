pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn postorder(root: &Option<Box<Node>>) -> Vec<i32> {
    let mut out = Vec::new();

    fn go(root: &Option<Box<Node>>, out: &mut Vec<i32>) {
        if let Some(node) = root {
            go(&node.left, out);
            go(&node.right, out);
            out.push(node.val);
        }
    }

    go(root, &mut out);
    out
}
