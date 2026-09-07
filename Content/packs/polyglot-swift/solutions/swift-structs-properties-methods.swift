struct Rectangle {
    var width: Int
    var height: Int

    func area() -> Int {
        width * height
    }

    func scaled(by factor: Int) -> Rectangle {
        Rectangle(width: width * factor, height: height * factor)
    }
}
