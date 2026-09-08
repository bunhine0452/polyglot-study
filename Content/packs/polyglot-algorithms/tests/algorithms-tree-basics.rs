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
    fn 빈_트리의_높이는_마이너스1이다() {
        let root: Option<Box<Node>> = None;
        assert_eq!(height(&root), -1);
    }

    #[test]
    fn 리프_하나의_높이는_0이다() {
        let root = leaf(1);
        assert_eq!(height(&root), 0);
    }

    #[test]
    fn 한쪽으로만_뻗은_트리는_노드_수_빼기_1이다() {
        // 1 - 2 - 3 순서로 왼쪽으로만 뻗으면 높이는 2다.
        let root = branch(1, branch(2, leaf(3), None), None);
        assert_eq!(height(&root), 2);
    }

    #[test]
    fn 양쪽_서브트리_중_더_높은_쪽을_따른다() {
        let left = branch(2, leaf(4), None); // 높이 1
        let right = leaf(3); // 높이 0
        let root = branch(1, left, right);
        assert_eq!(height(&root), 2);
    }

    #[test]
    fn 균형잡힌_트리의_높이() {
        let root = branch(1, leaf(2), leaf(3));
        assert_eq!(height(&root), 1);
    }
}
