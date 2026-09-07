def countdown(n):
    current = n
    while current >= 1:
        yield current
        current -= 1
