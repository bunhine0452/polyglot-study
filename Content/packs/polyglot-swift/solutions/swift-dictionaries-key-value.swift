func highScorers(_ scores: [String: Int], threshold: Int) -> [String] {
    var result: [String] = []
    for (name, score) in scores {
        if score >= threshold {
            result.append(name)
        }
    }
    return result.sorted()
}
