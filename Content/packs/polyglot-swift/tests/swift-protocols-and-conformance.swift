import Testing
@testable import Solution

@Test
func emptyArrayReturnsZero() {
    #expect(totalArea(of: []) == 0.0)
}

@Test
func singleRectangle() {
    let shapes: [Shape] = [Rectangle(width: 3.0, height: 4.0)]
    #expect(totalArea(of: shapes) == 12.0)
}

@Test
func mixedShapes() {
    let shapes: [Shape] = [
        Rectangle(width: 2.0, height: 5.0),
        Circle(radius: 1.0),
        Rectangle(width: 1.0, height: 1.0)
    ]
    let expected = 10.0 + 3.141592653589793 + 1.0
    #expect(totalArea(of: shapes) == expected)
}

@Test
func circleOnly() {
    let shapes: [Shape] = [Circle(radius: 2.0), Circle(radius: 1.0)]
    let expected = 4.0 * 3.141592653589793 + 3.141592653589793
    #expect(totalArea(of: shapes) == expected)
}
