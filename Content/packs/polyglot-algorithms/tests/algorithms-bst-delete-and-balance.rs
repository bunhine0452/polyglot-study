#[cfg(test)]
mod learnkit_tests {
    use super::*;

    fn inorder(root: &Option<Box<Node>>, out: &mut Vec<i32>) {
        if let Some(node) = root {
            inorder(&node.left, out);
            out.push(node.val);
            inorder(&node.right, out);
        }
    }

    fn build(values: &[i32]) -> Option<Box<Node>> {
        let mut root = None;
        for &v in values {
            root = insert(root, v);
        }
        root
    }

    fn to_vec(root: &Option<Box<Node>>) -> Vec<i32> {
        let mut out = Vec::new();
        inorder(root, &mut out);
        out
    }

    #[test]
    fn 자식이_없는_노드를_삭제한다() {
        // 5 - 3 - 8, 1은 리프
        let tree = build(&[5, 3, 8, 1]);
        let tree = delete(tree, 1);
        assert_eq!(to_vec(&tree), vec![3, 5, 8]);
    }

    #[test]
    fn 자식이_하나인_노드를_삭제한다() {
        // 3의 자식은 4(오른쪽) 하나뿐이다
        let tree = build(&[5, 3, 8, 4]);
        let tree = delete(tree, 3);
        assert_eq!(to_vec(&tree), vec![4, 5, 8]);
    }

    #[test]
    fn 자식이_둘인_노드를_삭제하면_중위_후속자로_대체된다() {
        let tree = build(&[5, 3, 8, 1, 4, 7, 9]);
        let tree = delete(tree, 5);
        // 루트는 오른쪽 서브트리의 최솟값인 7로 대체된다
        assert_eq!(tree.as_ref().unwrap().val, 7);
        assert_eq!(to_vec(&tree), vec![1, 3, 4, 7, 8, 9]);
    }

    #[test]
    fn 없는_값을_삭제하면_트리가_그대로다() {
        let tree = build(&[5, 3, 8]);
        let tree = delete(tree, 100);
        assert_eq!(to_vec(&tree), vec![3, 5, 8]);
    }

    #[test]
    fn 여러_번_삭제해도_정렬된_상태가_유지된다() {
        let mut tree = build(&[5, 3, 8, 1, 4, 7, 9]);
        for v in [1, 9, 5] {
            tree = delete(tree, v);
        }
        assert_eq!(to_vec(&tree), vec![3, 4, 7, 8]);
    }

    #[test]
    fn 루트_하나짜리_트리에서_그_값을_삭제하면_빈_트리다() {
        let tree = build(&[42]);
        let tree = delete(tree, 42);
        assert!(tree.is_none());
    }
}
