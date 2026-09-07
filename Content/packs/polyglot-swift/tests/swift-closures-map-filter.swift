import Testing
@testable import Solution

@Test func mixedNumbers() {
    #expect(doubledEvens([1, 2, 3, 4, 5, 6]) == [4, 8, 12])
}

@Test func emptyInput() {
    #expect(doubledEvens([]) == [])
}

@Test func negativesAndZero() {
    #expect(doubledEvens([-3, -4, 0, 7]) == [-8, 0])
}

@Test func oddsOnly() {
    #expect(doubledEvens([1, 3, 5]) == [])
}
