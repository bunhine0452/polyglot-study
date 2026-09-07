import Testing
@testable import Solution

@Test func 단어를세고정렬한다() throws {
    let analyzer = BasicAnalyzer()
    let result = try analyzer.analyze("apple banana Apple cherry", top: 2)
    #expect(result == [WordFrequency(word: "apple", count: 2), WordFrequency(word: "banana", count: 1)])
}

@Test func 빈입력은오류를던진다() {
    let analyzer = BasicAnalyzer()
    #expect(throws: AnalyzerError.emptyInput) {
        try analyzer.analyze("   ", top: 3)
    }
}

@Test func limit이0이면오류를던진다() {
    let analyzer = BasicAnalyzer()
    #expect(throws: AnalyzerError.invalidLimit) {
        try analyzer.analyze("hello world", top: 0)
    }
}

@Test func 동률은단어오름차순으로깬다() throws {
    let analyzer = BasicAnalyzer()
    let result = try analyzer.analyze("b a b a c", top: 3)
    #expect(result == [WordFrequency(word: "a", count: 2), WordFrequency(word: "b", count: 2), WordFrequency(word: "c", count: 1)])
}

@Test func limit만큼잘라낸다() throws {
    let analyzer = BasicAnalyzer()
    let result = try analyzer.analyze("x y z x", top: 1)
    #expect(result == [WordFrequency(word: "x", count: 2)])
}
