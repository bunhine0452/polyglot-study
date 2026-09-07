func sumSkipMultiplesForIn(from: Int, to: Int, step: Int) -> Int {
    if from > to {
        return 0
    }
    var total = 0
    let skipMultiples = step > 0
    for n in from...to {
        if (n % step == 0) == skipMultiples {
            continue
        }
        total += n
    }
    return total
}

func sumSkipMultiplesWhile(from: Int, to: Int, step: Int) -> Int {
    if from > to {
        return 0
    }
    var total = 0
    var n = from
    let skipMultiples = step > 0
    while n <= to {
        if (n % step == 0) == skipMultiples {
            n += 1
            continue
        }
        total += n
        n += 1
    }
    return total
}
