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
    fn min_val(node: &Node) -> i32 {
        match &node.left {
            Some(left) => min_val(left),
            None => node.val,
        }
    }

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
