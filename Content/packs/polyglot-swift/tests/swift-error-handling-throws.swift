import Testing
@testable import Solution

@Test func normalWithdrawReturnsRemainingBalance() throws {
    let remaining = try withdraw(balance: 10000, amount: 3000)
    #expect(remaining == 7000)
}

@Test func withdrawExactBalanceLeavesZero() throws {
    let remaining = try withdraw(balance: 5000, amount: 5000)
    #expect(remaining == 0)
}

@Test func zeroAmountThrowsInvalidAmount() {
    #expect(throws: BankError.invalidAmount) {
        try withdraw(balance: 3000, amount: 0)
    }
}

@Test func negativeAmountThrowsInvalidAmount() {
    #expect(throws: BankError.invalidAmount) {
        try withdraw(balance: 3000, amount: -100)
    }
}

@Test func overdrawThrowsInsufficientFundsWithNeeded() {
    #expect(throws: BankError.insufficientFunds(needed: 2000)) {
        try withdraw(balance: 3000, amount: 5000)
    }
}
