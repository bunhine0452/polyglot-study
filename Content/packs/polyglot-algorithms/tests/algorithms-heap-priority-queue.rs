#[cfg(test)]
mod learnkit_tests {
    use super::*;

    fn is_min_heap(heap: &[i32]) -> bool {
        for i in 0..heap.len() {
            let l = 2 * i + 1;
            let r = 2 * i + 2;
            if l < heap.len() && heap[i] > heap[l] { return false; }
            if r < heap.len() && heap[i] > heap[r] { return false; }
        }
        true
    }

    #[test]
    fn 삽입_후_힙_속성이_유지된다() {
        let mut heap = Vec::new();
        for v in [5, 3, 8, 1, 9, 2, 7] {
            heap_push(&mut heap, v);
            assert!(is_min_heap(&heap), "힙 속성이 깨졌다: {:?}", heap);
        }
    }

    #[test]
    fn 추출하면_오름차순으로_나온다() {
        let mut heap = Vec::new();
        for v in [5, 3, 8, 1, 9, 2, 7] {
            heap_push(&mut heap, v);
        }
        let mut out = Vec::new();
        while let Some(v) = heap_pop(&mut heap) {
            out.push(v);
        }
        assert_eq!(out, vec![1, 2, 3, 5, 7, 8, 9]);
    }

    #[test]
    fn 빈_힙에서_pop은_none이다() {
        let mut heap: Vec<i32> = Vec::new();
        assert_eq!(heap_pop(&mut heap), None);
    }

    #[test]
    fn 추출_후에도_힙_속성이_유지된다() {
        let mut heap = Vec::new();
        for v in [10, 4, 15, 20, 0, 8] {
            heap_push(&mut heap, v);
        }
        heap_pop(&mut heap);
        assert!(is_min_heap(&heap));
        heap_pop(&mut heap);
        assert!(is_min_heap(&heap));
    }
}
