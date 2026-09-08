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
    fn 빈_트리는_빈_결과다() {
        let root: Option<Box<Node>> = None;
        assert_eq!(level_order(&root), Vec::<Vec<i32>>::new());
    }

    #[test]
    fn 리프_하나면_한_층뿐이다() {
        let root = leaf(9);
        assert_eq!(level_order(&root), vec![vec![9]]);
    }

    #[test]
    fn 층별로_묶인다() {
        //        1
        //      /   \
        //     2     3
        //    / \     \
        //   4   5     6
        let tree = branch(1, branch(2, leaf(4), leaf(5)), branch(3, None, leaf(6)));
        assert_eq!(level_order(&tree), vec![vec![1], vec![2, 3], vec![4, 5, 6]]);
    }

    #[test]
    fn 같은_층에서는_왼쪽이_먼저다() {
        let tree = branch(1, leaf(2), leaf(3));
        assert_eq!(level_order(&tree), vec![vec![1], vec![2, 3]]);
    }

    #[test]
    fn 한쪽으로만_뻗은_트리도_층마다_원소_하나다() {
        let root = branch(1, branch(2, leaf(3), None), None);
        assert_eq!(level_order(&root), vec![vec![1], vec![2], vec![3]]);
    }
}
