def count_char(word, target):
    count = 0
    for ch in word:
        if ch.lower() == target.lower():
            count = count + 1
    return count
