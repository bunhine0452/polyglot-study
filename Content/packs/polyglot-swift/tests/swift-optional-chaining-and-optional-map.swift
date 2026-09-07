import Testing
@testable import Solution

@Test func bestFriendNameReturnsFriendsName() {
    let person = Person(name: "지수", friend: Person(name: "민수", friend: nil))
    #expect(bestFriendName(of: person) == "민수")
}

@Test func bestFriendNameHandlesNilPerson() {
    #expect(bestFriendName(of: nil) == "친구 없음")
}

@Test func bestFriendNameHandlesMissingFriend() {
    let person = Person(name: "지수", friend: nil)
    #expect(bestFriendName(of: person) == "친구 없음")
}

@Test func doubledScoreDoublesValue() {
    #expect(doubledScore(21) == 42)
}

@Test func doubledScoreHandlesNil() {
    #expect(doubledScore(nil) == 0)
}

@Test func doubledScoreHandlesZero() {
    #expect(doubledScore(0) == 0)
}

@Test func parseCountParsesNumber() {
    #expect(parseCount("42") == 42)
}

@Test func parseCountRejectsNonNumber() {
    #expect(parseCount("hello") == nil)
}

@Test func parseCountHandlesNil() {
    #expect(parseCount(nil) == nil)
}
