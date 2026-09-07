func double(_ n: Int) -> Int {
    return n * 2
}

func grade(for score: Int) -> String {
    if score >= 90 {
        return "A"
    } else if score >= 80 {
        return "B"
    } else {
        return "C"
    }
}

func sumUpTo(_ n: Int) -> Int {
    if n <= 0 {
        return 0
    }
    var total = 0
    for i in 1...n {
        total += i
    }
    return total
}
