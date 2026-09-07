func findIndex<T: Equatable>(of value: T, in items: [T]) -> Int? {
    for (index, item) in items.enumerated() {
        if item == value {
            return index
        }
    }
    return nil
}

struct Pair<T: Equatable> {
    let first: T
    let second: T

    func hasEqualParts() -> Bool {
        return first == second
    }
}
