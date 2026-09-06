def filter_banned(words, banned):
    result = []
    for word in words:
        if word not in banned:
            result.append(word)
    return result
