def total_price(order, prices):
    total = 0
    for item in order:
        total += prices.get(item, 0)
    return total
