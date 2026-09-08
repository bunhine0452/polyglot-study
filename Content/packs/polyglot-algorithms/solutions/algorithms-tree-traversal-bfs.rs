use std::collections::VecDeque;

pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn level_order(root: &Option<Box<Node>>) -> Vec<Vec<i32>> {
    let mut levels = Vec::new();
    let mut queue: VecDeque<&Node> = VecDeque::new();
    if let Some(node) = root {
        queue.push_back(node);
    }

    while !queue.is_empty() {
        let count = queue.len();
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
        levels.push(values);
    }

    levels
}
