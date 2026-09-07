enum BankError: Error, Equatable {
    case invalidAmount
    case insufficientFunds(needed: Int)
}

func withdraw(balance: Int, amount: Int) throws -> Int {
    guard amount > 0 else {
        throw BankError.invalidAmount
    }
    guard amount <= balance else {
        throw BankError.insufficientFunds(needed: amount - balance)
    }
    return balance - amount
}
