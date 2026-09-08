use std::collections::VecDeque;

pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn level_order(root: &Option<Box<Node>>) -> Vec<Vec<i32>> {
    // 큐에 루트를 넣고 시작해라.
    // 한 층을 처리하기 직전 큐의 길이를 재 두면, 그 개수만큼이 정확히 이번 층이다.
    unimplemented!("여기를 구현해라")
}
