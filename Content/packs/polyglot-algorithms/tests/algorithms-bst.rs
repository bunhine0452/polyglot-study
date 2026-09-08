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

    fn count_nodes(root: &Option<Box<Node>>) -> usize {
        match root {
            None => 0,
            Some(node) => 1 + count_nodes(&node.left) + count_nodes(&node.right),
        }
    }

    fn build(values: &[i32]) -> Option<Box<Node>> {
        let mut root = None;
        for &v in values {
            root = insert(root, v);
        }
        root
    }

    #[test]
    fn 빈_트리에_삽입하면_루트가_된다() {
        let tree = insert(None, 5);
        let node = tree.unwrap();
        assert_eq!(node.val, 5);
        assert!(node.left.is_none());
        assert!(node.right.is_none());
    }

    #[test]
    fn 작은_값은_왼쪽에_큰_값은_오른쪽에_들어간다() {
        let tree = build(&[5, 3, 8]);
        let root = tree.unwrap();
        assert_eq!(root.val, 5);
        assert_eq!(root.left.as_ref().unwrap().val, 3);
        assert_eq!(root.right.as_ref().unwrap().val, 8);
    }

    #[test]
    fn 삽입_결과가_정렬된_중위_순회를_만든다() {
        let tree = build(&[5, 3, 8, 1, 4, 7, 9]);
        let mut out = Vec::new();
        inorder(&tree, &mut out);
        assert_eq!(out, vec![1, 3, 4, 5, 7, 8, 9]);
    }

    #[test]
    fn 중복_값은_트리_크기를_늘리지_않는다() {
        let tree = build(&[5, 3, 5, 3, 5]);
        assert_eq!(count_nodes(&tree), 2);
    }

    #[test]
    fn 삽입_순서가_달라도_같은_집합이면_중위_순회_결과가_같다() {
        let a = build(&[5, 3, 8, 1, 4]);
        let b = build(&[1, 3, 4, 5, 8]);
        let mut out_a = Vec::new();
        let mut out_b = Vec::new();
        inorder(&a, &mut out_a);
        inorder(&b, &mut out_b);
        assert_eq!(out_a, out_b);
    }
}
