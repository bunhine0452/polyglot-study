#[cfg(test)]
mod learnkit_tests {
    use super::*;

    fn leaf(val: i32) -> Option<Box<Node>> {
        Some(Box::new(Node { val, left: None, right: None }))
    }

    fn branch(val: i32, left: Option<Box<Node>>, right: Option<Box<Node>>) -> Option<Box<Node>> {
        Some(Box::new(Node { val, left, right }))
    }

    #[test]
    fn 빈_트리는_빈_벡터다() {
        let root: Option<Box<Node>> = None;
        assert_eq!(postorder(&root), Vec::<i32>::new());
    }

    #[test]
    fn 리프_하나면_자기_자신뿐이다() {
        let root = leaf(7);
        assert_eq!(postorder(&root), vec![7]);
    }

    #[test]
    fn 왼쪽_오른쪽_루트_순서다() {
        let root = branch(1, leaf(2), leaf(3));
        assert_eq!(postorder(&root), vec![2, 3, 1]);
    }

    #[test]
    fn 여러_층의_트리도_같은_규칙을_따른다() {
        //        1
        //      /   \
        //     2     3
        //    / \
        //   4   5
        let tree = branch(1, branch(2, leaf(4), leaf(5)), leaf(3));
        assert_eq!(postorder(&tree), vec![4, 5, 2, 3, 1]);
    }

    #[test]
    fn 한쪽으로만_뻗은_트리() {
        // 1 -> 왼쪽 2 -> 왼쪽 3
        let root = branch(1, branch(2, leaf(3), None), None);
        assert_eq!(postorder(&root), vec![3, 2, 1]);
    }
}
