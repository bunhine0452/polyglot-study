import Testing
@testable import Solution

@Test func factorialBasic() {
    #expect(factorial(5) == 120)
}

@Test func factorialBoundaryZero() {
    #expect(factorial(0) == 1)
}

@Test func factorialOne() {
    #expect(factorial(1) == 1)
}

@Test func powerBasic() {
    #expect(power(2, 10) == 1024)
}

@Test func powerBoundaryZeroExponent() {
    #expect(power(7, 0) == 1)
}

@Test func powerNegativeBase() {
    #expect(power(-3, 3) == -27)
}
