import Testing
@testable import Solution

@Test func totalScoreSumsElements() {
    #expect(totalScore([10, 20, 30]) == 60)
}

@Test func totalScoreEmptyArrayIsZero() {
    #expect(totalScore([]) == 0)
}

@Test func totalScoreWithNegativeAndDuplicate() {
    #expect(totalScore([-5, 5, 5]) == 5)
}

@Test func parseScoresDropsNilAndInvalid() {
    #expect(parseScores(["90", nil, "abc", "70"]) == [90, 70])
}

@Test func parseScoresAllNilIsEmpty() {
    #expect(parseScores([nil, nil]) == [])
}

@Test func parseScoresZeroAndNegative() {
    #expect(parseScores(["0", "-3", "x"]) == [0, -3])
}

@Test func topScoresReturnsDescendingSlice() {
    #expect(topScores([45, 95, 12, 88], count: 2) == [95, 88])
}

@Test func topScoresEmptyInput() {
    #expect(topScores([], count: 3) == [])
}

@Test func topScoresCountLargerThanArray() {
    #expect(topScores([1, 2], count: 5) == [2, 1])
}
