enum Shape {
    case circle(radius: Double)
    case square(side: Double)
    case rectangle(width: Double, height: Double)
}

func area(_ shape: Shape) -> Double {
    fatalError("여기를 구현해라")
}
