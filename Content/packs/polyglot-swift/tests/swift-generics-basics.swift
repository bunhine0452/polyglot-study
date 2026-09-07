import Testing
@testable import Solution

@Test func findsFirstIndex() {
    #expect(findIndex(of: 5, in: [1, 3, 5, 7]) == 2)
}

@Test func returnsNilWhenNotFound() {
    #expect(findIndex(of: 9, in: [1, 3, 5]) == nil)
}

@Test func emptyArrayReturnsNil() {
    #expect(findIndex(of: 1, in: [Int]()) == nil)
}

@Test func worksWithStringAndDuplicate() {
    #expect(findIndex(of: "go", in: ["swift", "go", "go"]) == 1)
}

@Test func pairWithEqualParts() {
    #expect(Pair(first: 3, second: 3).hasEqualParts())
}

@Test func pairWithUnequalParts() {
    #expect(!Pair(first: 1, second: 2).hasEqualParts())
}
