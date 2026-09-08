pub trait Shape {
    fn area(&self) -> f64;

    fn describe(&self) -> String {
        format!("넓이는 {:.2}입니다", self.area())
    }
}

pub struct Rectangle {
    pub width: f64,
    pub height: f64,
}

pub struct Square {
    pub side: f64,
}

impl Shape for Rectangle {
    fn area(&self) -> f64 {
        // width 와 height 를 곱한 값을 돌려준다.
        unimplemented!("여기를 구현해라")
    }
}

impl Shape for Square {
    fn area(&self) -> f64 {
        // side 를 자기 자신과 곱한 값을 돌려준다.
        unimplemented!("여기를 구현해라")
    }
}
