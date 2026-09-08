pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn insert(root: Option<Box<Node>>, val: i32) -> Option<Box<Node>> {
    // root 가 None 이면 val 하나짜리 새 노드가 곧 결과다.
    // root 가 Some 이면 val 을 node.val 과 비교해 왼쪽/오른쪽 중 알맞은 자리에
    // 재귀로 삽입하고, 그 결과로 node.left 또는 node.right 를 다시 채워라.
    unimplemented!("여기를 구현해라")
}
