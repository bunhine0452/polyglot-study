pub struct Node {
    pub val: i32,
    pub left: Option<Box<Node>>,
    pub right: Option<Box<Node>>,
}

pub fn height(root: &Option<Box<Node>>) -> i32 {
    // 빈 트리(None)의 높이는 -1, 리프 하나짜리 트리의 높이는 0이다.
    // 자식이 있으면 1 + (왼쪽 서브트리 높이와 오른쪽 서브트리 높이 중 더 큰 값)이다.
    unimplemented!("여기를 구현해라")
}
