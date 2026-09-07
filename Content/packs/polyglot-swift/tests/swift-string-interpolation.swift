import Testing
@testable import Solution

@Test
func greetBasic() {
    #expect(greet(name: "지훈", age: 20) == "안녕하세요, 지훈님! 나이는 20살이에요.")
}

@Test
func greetZeroAge() {
    #expect(greet(name: "아기", age: 0) == "안녕하세요, 아기님! 나이는 0살이에요.")
}

@Test
func shoutBasic() {
    #expect(shout("hello") == "HELLO! 글자 수는 5자예요.")
}

@Test
func shoutEmpty() {
    #expect(shout("") == "! 글자 수는 0자예요.")
}
