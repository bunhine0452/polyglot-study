class Account {
    var balance: Int

    init(balance: Int) {
        self.balance = balance
    }

    func deposit(_ amount: Int) {
        balance += amount
    }

    func withdraw(_ amount: Int) -> Bool {
        if amount > balance {
            return false
        }
        balance -= amount
        return true
    }
}

func sameAccount(_ a: Account, _ b: Account) -> Bool {
    return a === b
}
