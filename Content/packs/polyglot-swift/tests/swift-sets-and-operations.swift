import Testing
@testable import Solution

@Test func removesDuplicatesAndSorts() {
    #expect(uniqueSorted(["바나나", "사과", "바나나", "딸기"]) == ["딸기", "바나나", "사과"])
    #expect(uniqueSorted(["go", "go", "go"]) == ["go"])
}

@Test func emptyInputsGiveEmptyResults() {
    #expect(uniqueSorted([]) == [])
    #expect(unionTags([], []).isEmpty)
    #expect(commonTags([], ["swift"]).isEmpty)
    #expect(!hasTag([], "swift"))
}

@Test func unionAndIntersectionWork() {
    let a: Set<String> = ["swift", "go", "rust"]
    let b: Set<String> = ["go", "python"]
    #expect(unionTags(a, b) == ["swift", "go", "rust", "python"])
    #expect(commonTags(a, b) == ["go"])
    #expect(commonTags(a, ["java"]).isEmpty)
}

@Test func containsChecksMembership() {
    let tags: Set<String> = ["ios", "swift"]
    #expect(hasTag(tags, "swift"))
    #expect(!hasTag(tags, "android"))
}
