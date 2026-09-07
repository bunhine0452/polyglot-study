import Testing
@testable import Solution

@Test func 일반적인합() {
    #expect(addIntAndDouble(3, 0.5) == 3.5)
    #expect(addIntAndDouble(10, 2.25) == 12.25)
}

@Test func 영과음수경계() {
    #expect(addIntAndDouble(0, 0.0) == 0.0)
    #expect(addIntAndDouble(-5, 1.5) == -3.5)
    #expect(addIntAndDouble(4, -0.5) == 3.5)
}

@Test func 큰수합() {
    #expect(addIntAndDouble(1_000_000, 0.125) == 1_000_000.125)
}
