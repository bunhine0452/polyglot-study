/// 0 으로 나누면 nil 을, 아니면 정수 몫을 돌려준다.
func safeDivide(_ numerator: Int, by denominator: Int) -> Int? {
    guard denominator != 0 else { return nil }
    return numerator / denominator
}
