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
        self.width * self.height
    }
}

impl Shape for Square {
    fn area(&self) -> f64 {
        self.side * self.side
    }
}
