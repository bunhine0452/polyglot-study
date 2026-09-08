pub struct Rectangle {
    pub width: i32,
    pub height: i32,
}

impl Rectangle {
    pub fn new(width: i32, height: i32) -> Rectangle {
        Rectangle { width, height }
    }

    pub fn area(&self) -> i32 {
        // width 와 height 를 곱한 값을 돌려준다.
        unimplemented!("여기를 구현해라")
    }

    pub fn is_square(&self) -> bool {
        // width 와 height 가 같으면 true.
        unimplemented!("여기를 구현해라")
    }
}
