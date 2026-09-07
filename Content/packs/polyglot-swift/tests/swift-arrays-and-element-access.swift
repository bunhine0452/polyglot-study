import Testing
@testable import Solution

@Test func sumsOneToFive() {
    #expect(sumUpTo(5) == 15)
}

@Test func boundaryZeroReturnsZero() {
    #expect(sumUpTo(0) == 0)
}

@Test func negativeReturnsZero() {
    #expect(sumUpTo(-3) == 0)
}

@Test func singleElement() {
    #expect(sumUpTo(1) == 1)
}
