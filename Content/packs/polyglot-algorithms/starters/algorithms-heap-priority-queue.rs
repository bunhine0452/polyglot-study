pub fn heap_push(heap: &mut Vec<i32>, value: i32) {
    // 새 값을 맨 끝에 넣고, 부모보다 작으면 자리를 바꿔가며 위로 올려라(sift-up).
    // 부모 인덱스는 (i - 1) / 2 다.
    unimplemented!("여기를 구현해라")
}

pub fn heap_pop(heap: &mut Vec<i32>) -> Option<i32> {
    // 루트와 마지막 원소를 바꾼 뒤 마지막 원소를 꺼내 반환값으로 삼아라.
    // 그다음 루트에서부터 더 작은 자식과 자리를 바꿔가며 아래로 내려라(sift-down).
    unimplemented!("여기를 구현해라")
}
