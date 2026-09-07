func factorial(_ n: Int) -> Int {
    if n <= 1 {
        return 1
    }
    return n * factorial(n - 1)
}

func power(_ base: Int, _ exp: Int) -> Int {
    if exp == 0 {
        return 1
    }
    return base * power(base, exp - 1)
}
