def min_max(numbers):
    if not numbers:
        return (None, None)
    smallest = numbers[0]
    largest = numbers[0]
    for i, value in enumerate(numbers):
        if value < smallest:
            smallest = value
        if value > largest:
            largest = value
    return (smallest, largest)
