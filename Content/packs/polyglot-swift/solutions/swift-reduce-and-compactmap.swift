func totalScore(_ scores: [Int]) -> Int {
    return scores.reduce(0) { $0 + $1 }
}

func parseScores(_ raws: [String?]) -> [Int] {
    return raws.compactMap { raw -> Int? in
        guard let raw = raw, let n = Int(raw) else { return nil }
        return n
    }
}

func topScores(_ scores: [Int], count: Int) -> [Int] {
    let descending = scores.sorted(by: { $0 > $1 })
    return Array(descending.prefix(count))
}
