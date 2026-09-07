import Testing
@testable import Solution

@Test func nilScoreReturnsPlaceholder() {
    #expect(gradeLabel(nil) == "점수 없음")
}

@Test func nonNilScoreIsInterpolatedWithoutOptional() {
    #expect(gradeLabel(90) == "점수: 90")
}

@Test func zeroScoreBoundary() {
    #expect(gradeLabel(0) == "점수: 0")
    #expect(normalize(nil) == 0)
}

@Test func normalizePassesValueThrough() {
    #expect(normalize(42) == 42)
    #expect(normalize(-5) == -5)
}
