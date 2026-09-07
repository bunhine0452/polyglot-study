import Testing
@testable import Solution

@Test func foundValue() {
    #expect(lookupAge(["kim": 20], name: "kim") == "kim: 20살")
}

@Test func missingKey() {
    #expect(lookupAge(["kim": 20], name: "park") == "park: 나이를 모릅니다")
}

@Test func emptyDictionary() {
    #expect(lookupAge([:], name: "kim") == "kim: 나이를 모릅니다")
}

@Test func zeroAge() {
    #expect(lookupAge(["lee": 0], name: "lee") == "lee: 0살")
}
