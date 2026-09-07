import Testing
@testable import Solution

@Test func depositIncreasesBalance() {
    let account = Account(balance: 100)
    account.deposit(50)
    #expect(account.balance == 150)
}

@Test func withdrawInsufficientFundsKeepsBalance() {
    let account = Account(balance: 100)
    #expect(account.withdraw(200) == false)
    #expect(account.balance == 100)
}

@Test func withdrawExactBalanceHitsZero() {
    let account = Account(balance: 100)
    #expect(account.withdraw(100) == true)
    #expect(account.balance == 0)
}

@Test func referenceSharingThroughAlias() {
    let original = Account(balance: 0)
    let alias = original
    alias.deposit(10)
    #expect(original.balance == 10)
    #expect(sameAccount(original, alias))
}

@Test func distinctAccountsAreNotSameInstance() {
    let a = Account(balance: 0)
    let b = Account(balance: 0)
    #expect(!sameAccount(a, b))
    a.deposit(5)
    #expect(b.balance == 0)
}
