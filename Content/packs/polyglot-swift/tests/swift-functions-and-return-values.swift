import Testing
@testable import Solution

@Test func doubleReturnsTwiceTheInput() {
    #expect(double(3) == 6)
    #expect(double(0) == 0)
    #expect(double(-4) == -8)
}

@Test func gradeRespectsBoundaries() {
    #expect(grade(for: 90) == "A")
    #expect(grade(for: 89) == "B")
    #expect(grade(for: 80) == "B")
    #expect(grade(for: 79) == "C")
    #expect(grade(for: 0) == "C")
}

@Test func sumUpToHandlesBoundary() {
    #expect(sumUpTo(0) == 0)
    #expect(sumUpTo(-5) == 0)
    #expect(sumUpTo(1) == 1)
    #expect(sumUpTo(5) == 15)
}
