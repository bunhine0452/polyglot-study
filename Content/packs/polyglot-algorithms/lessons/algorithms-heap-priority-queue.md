@Concept(id: heap-priority-queue-concept) {
완전 이진 트리는 마지막 줄을 제외한 모든 줄이 꽉 차 있고, 마지막 줄도 왼쪽부터 빈틈없이 채워진 트리다. 이 모양이 힙의 핵심이다 — 노드 사이의 연결이 항상 정해져 있어서, 포인터 없이 **배열 하나**로 트리 전체를 표현할 수 있다. 인덱스 `i` 의 부모는 `(i - 1) / 2`, 왼쪽 자식은 `2 * i + 1`, 오른쪽 자식은 `2 * i + 2` 다.

힙 속성은 "부모가 자식보다 작다(최소 힙)" 또는 "크다(최대 힙)" 는 규칙 하나뿐이다. 형제 사이의 순서는 정해지지 않는다 — 그래서 힙은 정렬된 배열이 아니다. 오직 **루트가 항상 최솟값(또는 최댓값)** 이라는 것만 보장한다.

삽입은 배열 맨 끝에 값을 놓는 것으로 시작한다 — 완전 이진 트리 모양이 저절로 유지된다. 하지만 힙 속성은 깨질 수 있으니 부모와 비교해 더 작으면 자리를 바꾸고, 그 자리에서 다시 부모와 비교하기를 반복한다. 이것이 **sift-up** 이다.

추출은 루트(최솟값)를 꺼내는 것이다. 루트를 빼면 트리 모양이 무너지므로, 배열의 마지막 값을 루트 자리로 옮겨 모양을 다시 완전 이진 트리로 만든다. 그 값은 대개 힙 속성에 맞지 않으니 두 자식 중 더 작은 쪽과 비교해 자리를 바꾸며 아래로 내려간다. 이것이 **sift-down** 이다.

25편에서 이진 탐색 트리는 값을 넣는 순서에 따라 한쪽으로 늘어져 높이가 O(n)까지 나빠질 수 있다는 것을 봤다. 힙은 그런 일이 없다 — 삽입이 항상 다음 빈 자리(배열 맨 끝)에서 시작하므로 트리 모양이 완전 이진 트리라는 것 자체가 절대 깨지지 않는다. 원소가 n개면 높이는 항상 `⌊log2 n⌋` 이고, sift-up과 sift-down은 그 높이만큼만 움직이므로 삽입과 추출 모두 O(log n) 이다.
}

@Example(id: heap-priority-queue-example, language: rust, expected: expected/algorithms-heap-priority-queue.txt) {
삽입할 때 sift-up이 값을 어디까지 밀어 올리는지, 추출할 때 sift-down이 어디까지 내리는지 배열이 바뀌는 모습으로 확인한다.

```rust
fn parent(i: usize) -> usize { (i - 1) / 2 }
fn left(i: usize) -> usize { 2 * i + 1 }
fn right(i: usize) -> usize { 2 * i + 2 }

fn sift_up(heap: &mut Vec<i32>, mut i: usize) {
    while i > 0 {
        let p = parent(i);
        if heap[p] <= heap[i] {
            break;
        }
        heap.swap(p, i);
        i = p;
    }
}

fn sift_down(heap: &mut Vec<i32>, mut i: usize) {
    let n = heap.len();
    loop {
        let l = left(i);
        let r = right(i);
        let mut smallest = i;
        if l < n && heap[l] < heap[smallest] { smallest = l; }
        if r < n && heap[r] < heap[smallest] { smallest = r; }
        if smallest == i { break; }
        heap.swap(i, smallest);
        i = smallest;
    }
}

fn push(heap: &mut Vec<i32>, value: i32) {
    heap.push(value);
    sift_up(heap, heap.len() - 1);
}

fn pop(heap: &mut Vec<i32>) -> Option<i32> {
    if heap.is_empty() {
        return None;
    }
    let n = heap.len();
    heap.swap(0, n - 1);
    let top = heap.pop();
    if !heap.is_empty() {
        sift_down(heap, 0);
    }
    top
}

fn main() {
    let mut heap: Vec<i32> = Vec::new();
    for v in [5, 3, 8, 1, 9, 2] {
        push(&mut heap, v);
        println!("{} 넣음 -> {:?}", v, heap);
    }

    for _ in 0..3 {
        let top = pop(&mut heap).unwrap();
        println!("{} 뺌 -> {:?}", top, heap);
    }
}
```
}

@Blank(id: heap-priority-queue-blank, language: rust) {
swap 이후에 계속 위로 올라가려면, 다음 비교는 방금 값이 이동한 자리에서 시작해야 한다. 그 자리는 어디일까?

```rust
fn sift_up(heap: &mut Vec<i32>, mut i: usize) {
    while i > 0 {
        let p = (i - 1) / 2;
        if heap[p] <= heap[i] {
            break;
        }
        heap.swap(p, i);
        i = ___1___;
    }
}

fn main() {
    let mut heap = vec![5, 3, 8, 1];
    sift_up(&mut heap, 3);
    println!("{:?}", heap);
}
```

@Answer(slot: 1) {
`p`
}
}

@Task(id: heap-priority-queue-task, language: rust, starter: starters/algorithms-heap-priority-queue.rs, tests: tests/algorithms-heap-priority-queue.rs, solution: solutions/algorithms-heap-priority-queue.rs) {
최소 힙을 배열(`Vec<i32>`)로 구현하세요. `heap_push` 는 새 값을 넣고 sift-up으로 힙 속성을 지키고, `heap_pop` 은 최솟값을 꺼내면서 sift-down으로 힙 속성을 지켜야 합니다. 힙이 비어 있으면 `heap_pop` 은 `None` 을 반환합니다.

@Hint {
부모 인덱스는 항상 `(i - 1) / 2` 다 (정수 나눗셈이라 두 자식이 같은 부모를 가리킨다).
}

@Hint {
sift-up은 새로 넣은 자리에서 시작해서, 부모가 더 크면 자리를 바꾸고 부모 자리로 이동하는 것을 반복한다. 부모가 더 작거나 같으면 멈춘다.
}

@Hint {
sift-down은 두 자식 중 더 작은 쪽과 비교해야 한다 — 큰 쪽과 바꾸면 힙 속성이 오히려 깨진다. 자식이 하나뿐이거나 아예 없는 경우도 챙겨라.
}
}

@Quiz(id: heap-priority-queue-quiz, answer: complete-tree) {
@Question {
힙이 삽입과 추출을 항상 O(log n)에 해내는 이유는?
}

@Choice(id: complete-tree) {
힙이 항상 완전 이진 트리라서 높이가 원소 수의 로그에 고정되기 때문이다
}

@Choice(id: sorted) {
힙 내부가 항상 정렬돼 있어서 이진 탐색을 쓸 수 있기 때문이다
}

@Choice(id: array-access) {
배열이라 인덱스로 바로 접근할 수 있어서 애초에 트리를 따라갈 필요가 없기 때문이다
}

@Explanation {
힙은 삽입이 항상 배열의 다음 빈 자리에서 시작하기 때문에 트리 모양이 완전 이진 트리에서 벗어나지 않는다. 그래서 원소가 n개면 높이가 항상 ⌊log2 n⌋이고, sift-up·sift-down은 그 높이만큼만 움직인다. 반면 힙 내부는 정렬돼 있지 않다 — 루트가 최솟값이라는 것만 보장할 뿐, 형제 사이의 순서는 정해지지 않는다.
}
}

@Reflection(id: heap-priority-queue-reflection) {
@Prompt(id: search) {
힙에서 특정 값이 들어 있는지 찾으려면 어떻게 해야 할지, 그리고 그 방법이 이진 탐색 트리의 탐색보다 왜 느릴 수밖에 없는지 적어 보세요.
}

@Prompt(id: bst-vs-heap) {
이진 탐색 트리와 힙은 둘 다 트리 모양이지만 유지하는 규칙이 다릅니다. 값을 정렬된 순서로 훑어야 하는 상황과, 최솟값(또는 최댓값)만 반복해서 꺼내면 되는 상황 중 각각 어느 자료구조가 나을지 정리해 보세요.
}
}
