import Testing

@Test("몫을 돌려준다")
func dividesEvenly() {
    #expect(safeDivide(10, by: 2) == 5)
}

@Test("나머지는 버린다")
func truncates() {
    #expect(safeDivide(7, by: 2) == 3)
}

@Test("0 으로 나누면 nil")
func rejectsZero() {
    #expect(safeDivide(1, by: 0) == nil)
}
