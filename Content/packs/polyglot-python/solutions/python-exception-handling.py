def parse_amount(text):
    try:
        return int(text)
    except ValueError:
        return 0


def withdraw(balance, amount):
    if amount <= 0:
        raise ValueError("출금액은 0보다 커야 합니다")
    if amount > balance:
        raise ValueError("잔액 부족")
    return balance - amount
