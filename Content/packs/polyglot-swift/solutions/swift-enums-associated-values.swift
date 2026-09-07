enum Shape {
    case circle(radius: Double)
    case square(side: Double)
    case rectangle(width: Double, height: Double)
}

func area(_ shape: Shape) -> Double {
    switch shape {
    case .circle(let radius):
        return Double.pi * radius * radius
    case .square(let side):
        return side * side
    case .rectangle(let width, let height):
        return width * height
    }
}
