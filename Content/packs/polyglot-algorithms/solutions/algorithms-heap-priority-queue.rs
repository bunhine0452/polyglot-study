pub fn heap_push(heap: &mut Vec<i32>, value: i32) {
    heap.push(value);
    let mut i = heap.len() - 1;
    while i > 0 {
        let p = (i - 1) / 2;
        if heap[p] <= heap[i] {
            break;
        }
        heap.swap(p, i);
        i = p;
    }
}

pub fn heap_pop(heap: &mut Vec<i32>) -> Option<i32> {
    if heap.is_empty() {
        return None;
    }
    let n = heap.len();
    heap.swap(0, n - 1);
    let top = heap.pop();
    let mut i = 0;
    let n = heap.len();
    loop {
        let l = 2 * i + 1;
        let r = 2 * i + 2;
        let mut smallest = i;
        if l < n && heap[l] < heap[smallest] { smallest = l; }
        if r < n && heap[r] < heap[smallest] { smallest = r; }
        if smallest == i { break; }
        heap.swap(i, smallest);
        i = smallest;
    }
    top
}
