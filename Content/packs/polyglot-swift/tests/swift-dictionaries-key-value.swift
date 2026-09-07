import Testing
@testable import Solution

@Test
func basicSelection() {
    let scores = ["kim": 90, "lee": 85, "park": 60]
    #expect(highScorers(scores, threshold: 85) == ["kim", "lee"])
}

@Test
func boundaryExactThreshold() {
    let scores = ["a": 70, "b": 71]
    #expect(highScorers(scores, threshold: 71) == ["b"])
}

@Test
func emptyDictionary() {
    #expect(highScorers([:], threshold: 10) == [])
}

@Test
func allBelowThreshold() {
    let scores = ["x": 10, "y": 20]
    #expect(highScorers(scores, threshold: 100) == [])
}
