func sumUpTo(_ n: Int) -> Int {
    var numbers: [Int] = []
    var i = 1
    while i <= n {
        numbers.append(i)
        i += 1
    }
    var total = 0
    for value in numbers {
        total += value
    }
    return total
}
