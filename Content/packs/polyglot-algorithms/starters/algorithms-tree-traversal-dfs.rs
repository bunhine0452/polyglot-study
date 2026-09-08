pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn postorder(root: &Option<Box<Node>>) -> Vec<i32> {
    // 왼쪽 서브트리를 먼저 훑고, 오른쪽 서브트리를 훑고, 마지막에 자기 자신을 기록해라.
    unimplemented!("여기를 구현해라")
}
