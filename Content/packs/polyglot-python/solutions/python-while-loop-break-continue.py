def sum_until_negative(numbers):
    total = 0
    i = 0
    while i < len(numbers):
        num = numbers[i]
        if num < 0:
            break
        if num == 0:
            i += 1
            continue
        total += num
        i += 1
    return total
