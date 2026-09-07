import Testing
@testable import Solution

@Test func basicSumSkipsMultiples() {
    #expect(sumSkipMultiplesForIn(from: 1, to: 10, step: 3) == 37)
    #expect(sumSkipMultiplesWhile(from: 1, to: 10, step: 3) == 37)
}

@Test func emptyRangeReturnsZero() {
    #expect(sumSkipMultiplesForIn(from: 5, to: 1, step: 2) == 0)
    #expect(sumSkipMultiplesWhile(from: 5, to: 1, step: 2) == 0)
}

@Test func stepLargerThanRangeSumsAll() {
    #expect(sumSkipMultiplesForIn(from: 1, to: 5, step: 10) == 15)
    #expect(sumSkipMultiplesWhile(from: 1, to: 5, step: 10) == 15)
}

@Test func negativeStepSkipsNegatedMultiples() {
    #expect(sumSkipMultiplesForIn(from: 1, to: 6, step: -2) == 12)
    #expect(sumSkipMultiplesWhile(from: 1, to: 6, step: -2) == 12)
}

@Test func singleElementRange() {
    #expect(sumSkipMultiplesForIn(from: 4, to: 4, step: 4) == 0)
    #expect(sumSkipMultiplesWhile(from: 4, to: 4, step: 4) == 0)
    #expect(sumSkipMultiplesForIn(from: 4, to: 4, step: 3) == 4)
    #expect(sumSkipMultiplesWhile(from: 4, to: 4, step: 3) == 4)
}
