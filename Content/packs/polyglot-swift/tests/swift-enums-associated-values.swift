import Testing
@testable import Solution

@Test func circleArea() {
    let value = area(.circle(radius: 2.0))
    #expect(abs(value - Double.pi * 4.0) < 0.000001)
}

@Test func squareArea() {
    let value = area(.square(side: 3.0))
    #expect(abs(value - 9.0) < 0.000001)
}

@Test func zeroWidthRectangle() {
    let value = area(.rectangle(width: 0.0, height: 5.0))
    #expect(value == 0.0)
}

@Test func rectangleArea() {
    let value = area(.rectangle(width: 2.5, height: 4.0))
    #expect(abs(value - 10.0) < 0.000001)
}
