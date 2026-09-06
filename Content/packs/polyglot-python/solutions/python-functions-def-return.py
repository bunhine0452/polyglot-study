def ticket_price(age, base=12000):
    if age < 8:
        return base // 2
    elif age >= 65:
        return base - 2000
    else:
        return base
