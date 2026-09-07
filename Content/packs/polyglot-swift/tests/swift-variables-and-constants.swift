import Testing
@testable import Solution

@Test func basicBonus() {
    #expect(scoreAfterBonus(base: 10, bonus: 5) == 15)
}

@Test func zeroBonusBoundary() {
    #expect(scoreAfterBonus(base: 7, bonus: 0) == 7)
}

@Test func negativeBaseBoundary() {
    #expect(scoreAfterBonus(base: -3, bonus: 10) == 7)
}

@Test func bothNegative() {
    #expect(scoreAfterBonus(base: -5, bonus: -5) == -10)
}
