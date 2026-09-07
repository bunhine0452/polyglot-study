import Testing
@testable import Solution

@Test func mondayIsFirst() {
    #expect(weekdayName(1) == "월")
}

@Test func sundayIsBoundary() {
    #expect(weekdayName(7) == "일")
}

@Test func zeroIsNotAWeekday() {
    #expect(weekdayName(0) == "없는 요일")
}

@Test func eightIsOutOfRange() {
    #expect(weekdayName(8) == "없는 요일")
}
