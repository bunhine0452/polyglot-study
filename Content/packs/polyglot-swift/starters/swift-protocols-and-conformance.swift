protocol Shape {
    var area: Double { get }
}

struct Rectangle: Shape {
    let width: Double
    let height: Double
    var area: Double {
        return width * height
    }
}

struct Circle: Shape {
    let radius: Double
    var area: Double {
        return radius * radius * 3.141592653589793
    }
}

func totalArea(of shapes: [Shape]) -> Double {
    fatalError("여기를 구현해라")
}
