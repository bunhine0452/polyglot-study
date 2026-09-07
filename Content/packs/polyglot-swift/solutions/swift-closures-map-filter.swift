func doubledEvens(_ nums: [Int]) -> [Int] {
    return nums.filter { $0 % 2 == 0 }.map { $0 * 2 }
}
