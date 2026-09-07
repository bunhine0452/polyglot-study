import Testing
@testable import Solution

@Test func areaMultipliesWidthAndHeight() {
    let rect = Rectangle(width: 3, height: 4)
    #expect(rect.area() == 12)
}

@Test func zeroWidthGivesZeroArea() {
    let rect = Rectangle(width: 0, height: 5)
    #expect(rect.area() == 0)
}

@Test func scaledReturnsNewInstance() {
    let original = Rectangle(width: 2, height: 3)
    let scaled = original.scaled(by: 2)
    #expect(scaled.width == 4)
    #expect(scaled.height == 6)
}

@Test func scaledLeavesOriginalUnchanged() {
    let original = Rectangle(width: 2, height: 3)
    _ = original.scaled(by: 5)
    #expect(original.width == 2)
    #expect(original.height == 3)
}

@Test func negativeDimensionsMultiply() {
    let rect = Rectangle(width: -2, height: 3)
    #expect(rect.area() == -6)
}
