def sum_until_negative(numbers):
    """음수를 만나면 반복을 멈추고, 0은 건너뛴 채 합계를 구한다."""
    total = 0
    i = 0
    while i < len(numbers):
        num = numbers[i]
        # 여기에 break와 continue 로직을 구현하세요
        total += num
        i += 1
    return total
