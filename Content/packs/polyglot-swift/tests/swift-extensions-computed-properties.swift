import Testing
@testable import Solution

@Test func isEvenBasics() {
    let even = 4
    let odd = 7
    #expect(even.isEven)
    #expect(!odd.isEven)
}

@Test func isEvenBoundary() {
    let zero = 0
    let negativeEven = -6
    let negativeOdd = -7
    #expect(zero.isEven)
    #expect(negativeEven.isEven)
    #expect(!negativeOdd.isEven)
}

@Test func squaredValues() {
    let five = 5
    let zero = 0
    let negative = -4
    #expect(five.squared == 25)
    #expect(zero.squared == 0)
    #expect(negative.squared == 16)
}

@Test func wordCountBasics() {
    let sentence = "안녕하세요 Swift 환영합니다"
    let one = "단어"
    #expect(sentence.wordCount == 3)
    #expect(one.wordCount == 1)
}

@Test func wordCountBoundary() {
    let empty = ""
    let spaced = "  여러   공백   사이 "
    #expect(empty.wordCount == 0)
    #expect(spaced.wordCount == 2)
}
