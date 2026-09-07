enum BankError: Error, Equatable {
    case invalidAmount
    case insufficientFunds(needed: Int)
}

func withdraw(balance: Int, amount: Int) throws -> Int {
    // 1. amount 가 0 이하이면 BankError.invalidAmount 를 던진다
    // 2. amount 가 balance 보다 크면 BankError.insufficientFunds(needed: amount - balance) 를 던진다
    // 3. 정상이면 balance 에서 amount 를 뺀 값을 반환한다
    fatalError("여기를 구현해라")
}
